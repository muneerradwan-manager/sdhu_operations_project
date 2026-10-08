import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';

/// Which half of the inbox is on screen.
///
/// Two kinds of thing arrive in one list and they are not read for the same
/// reason: an announcement is read when there is a minute, and an urgent report
/// is read because somebody is standing somewhere waiting. Mixed together at
/// three in the morning, the second is found by scrolling past the first.
enum NotificationFilter {
  all,

  /// Everything that is not an alarm — announcements, assignments, reminders.
  messages,

  /// The alarms alone. The operations room's view of its own inbox.
  incidents,
}

class NotificationsState extends Equatable {
  const NotificationsState({
    this.items = const [],
    this.loading = true,
    this.filter = NotificationFilter.all,
  });

  /// Everything, whatever is being shown. The counts are read off this so a
  /// chip can say how many are waiting in the half you are NOT looking at.
  final List<AppNotification> items;
  final bool loading;
  final NotificationFilter filter;

  int get unread => items.where((n) => !n.isRead).length;

  /// What the list draws: [items] narrowed to [filter].
  List<AppNotification> get visible => switch (filter) {
    NotificationFilter.all => items,
    NotificationFilter.incidents => items.where((n) => n.isIncident).toList(),
    NotificationFilter.messages => items.where((n) => !n.isIncident).toList(),
  };

  /// Whether there is anything to filter. Offering the chips over an inbox with
  /// no alarm in it is a control whose second position is always empty.
  bool get hasIncidents => items.any((n) => n.isIncident);

  int get unreadIncidents =>
      items.where((n) => n.isIncident && !n.isRead).length;

  int get unreadMessages => unread - unreadIncidents;

  NotificationsState copyWith({
    List<AppNotification>? items,
    bool? loading,
    NotificationFilter? filter,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      filter: filter ?? this.filter,
    );
  }

  @override
  List<Object?> get props => [items, loading, filter];
}

class NotificationsCubit extends SafeCubit<NotificationsState> {
  NotificationsCubit(this._repo) : super(const NotificationsState()) {
    _sub = _repo.streamMine().listen(
      _onNotifications,
      onError: (_) => emit(state.copyWith(loading: false)),
    );
  }

  final NotificationsRepository _repo;
  late final StreamSubscription<List<AppNotification>> _sub;

  /// Attachments already fetched, by group. A broadcast's file does not change
  /// once sent, so there is no reason to ask for it again on every Realtime
  /// emission — only groups this cubit has not seen yet go over the wire.
  final _attachmentsByGroup = <String, List<NotificationAttachment>>{};

  /// The same, for the reports announced by "بلاغ عاجل" rows. Kept apart rather
  /// than folded into the map above because it is keyed by a different thing:
  /// an incident's alarm is one row per recipient, each with a group of its
  /// own, and all of them are about the one set of photographs.
  final _attachmentsByIncident = <String, List<NotificationAttachment>>{};

  /// Bumped by every emission and every optimistic write. An attachment fetch
  /// that comes back late checks it before emitting: without this, its
  /// captured snapshot overwrote whatever happened during the await — a tapped
  /// notification turned unread again, a just-arrived one vanished.
  int _generation = 0;

  /// The list lands first and the attachments follow, in one query for the
  /// whole inbox. Shown straight away rather than held back: the title and the
  /// body are the notification, and a photo arriving a moment later is a photo
  /// arriving a moment later.
  Future<void> _onNotifications(List<AppNotification> items) async {
    final generation = ++_generation;
    emit(state.copyWith(items: _withKnownAttachments(items), loading: false));
    if (items.isEmpty) return;

    // Two sets, because a notification's files are either its own or the urgent
    // report's — never both. An incident row's group holds nothing, and asking
    // after it would be a query guaranteed to come back empty.
    final missingGroups = <String>[];
    final missingIncidents = <String>[];
    for (final n in items) {
      final incidentId = n.incidentId;
      if (incidentId != null) {
        if (!_attachmentsByIncident.containsKey(incidentId)) {
          missingIncidents.add(incidentId);
        }
      } else if (!_attachmentsByGroup.containsKey(n.groupId)) {
        missingGroups.add(n.groupId);
      }
    }
    if (missingGroups.isEmpty && missingIncidents.isEmpty) return;

    try {
      // Together: the inbox is one screen, and the second read should not wait
      // on the first to find out that it has nothing to do.
      final (byGroup, byIncident) = await (
        _repo.fetchAttachments(missingGroups),
        _repo.fetchIncidentAttachments(missingIncidents),
      ).wait;
      for (final id in missingGroups) {
        _attachmentsByGroup[id] = byGroup[id] ?? const [];
      }
      for (final id in missingIncidents) {
        _attachmentsByIncident[id] = byIncident[id] ?? const [];
      }
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(items: _withKnownAttachments(state.items)));
    } catch (_) {
      // The inbox is already on screen; attachments simply do not appear.
    }
  }

  List<AppNotification> _withKnownAttachments(List<AppNotification> items) => [
    for (final n in items) _withAttachments(n),
  ];

  AppNotification _withAttachments(AppNotification n) {
    final incidentId = n.incidentId;
    final known = incidentId != null
        ? _attachmentsByIncident[incidentId]
        : _attachmentsByGroup[n.groupId];
    return known == null ? n : n.withAttachments(known);
  }

  /// Re-reads the inbox now. The stream covers the normal case; this covers
  /// the two it does not — a pull-to-refresh, and having just sent something to
  /// yourself, where waiting on a socket to tell you what you already know
  /// reads as the app being broken.
  Future<void> refresh() async {
    try {
      await _onNotifications(await _repo.fetchMine());
    } catch (_) {
      // The list on screen stays; it is not worse than it was.
    }
  }

  /// Which half of the inbox to draw. Purely local — the rows are all here
  /// already, and a round trip to narrow a list this size would be slower than
  /// the reader's thumb.
  void setFilter(NotificationFilter filter) =>
      emit(state.copyWith(filter: filter));

  /// Marks one as read, on screen first.
  ///
  /// The write took the better part of three seconds on a slow connection, and
  /// waiting for it — or for Realtime to report it back — left the tap looking
  /// like it had done nothing. So the state moves now and the server catches
  /// up; if the write fails, a re-read puts the truth back.
  Future<void> markRead(String id) async {
    _generation++;
    emit(
      state.copyWith(
        items: [
          for (final n in state.items)
            if (n.id == id) n.markedRead() else n,
        ],
      ),
    );
    try {
      await _repo.markRead(id);
    } catch (_) {
      await refresh();
    }
  }

  /// "الكل", meaning everything currently on screen.
  ///
  /// Whole inbox when nothing is filtered, and exactly the half being looked at
  /// when something is — a button pressed over the alarms must not quietly
  /// clear forty announcements the reader cannot see.
  Future<void> markAllRead() async {
    _generation++;
    final everything = state.filter == NotificationFilter.all;
    final ids = {for (final n in state.visible) n.id};
    emit(
      state.copyWith(
        items: [
          for (final n in state.items)
            if (everything || ids.contains(n.id)) n.markedRead() else n,
        ],
      ),
    );
    try {
      if (everything) {
        await _repo.markAllRead();
      } else {
        await _repo.markManyRead(ids.toList());
      }
    } catch (_) {
      await refresh();
    }
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
