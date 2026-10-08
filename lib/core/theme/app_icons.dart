import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Single source of truth for iconography (Iconsax). Semantic names so screens
/// don't hard-code icon choices.
class AppIcons {
  const AppIcons._();

  /// Iconsax declares every glyph without `matchTextDirection`, so an arrow it
  /// draws pointing right keeps pointing right in Arabic — a "log out" arrow
  /// aims back into the layout, a "send" plane flies against the reading
  /// direction. Material's own arrows carry the flag and flip themselves; these
  /// are re-declared with it so [Icon] mirrors them under an RTL
  /// [Directionality] too.
  ///
  /// Re-declared rather than derived because the code points have to survive in
  /// a `const` expression — `Iconsax.logout.codePoint` is not one. The Iconsax
  /// name is named beside each, and `test/rtl_icons_test.dart` fails if the
  /// package ever renumbers them.
  static const _iconsaxFont = 'FlutterIconsax';
  static const _iconsaxPackage = 'iconsax_flutter';

  /// Iconsax.logout
  static const logout = IconData(
    0xed3b,
    fontFamily: _iconsaxFont,
    fontPackage: _iconsaxPackage,
    matchTextDirection: true,
  );

  /// Iconsax.login — the mirror of [logout], mirrored for the same reason.
  static const login = IconData(
    0xed37,
    fontFamily: _iconsaxFont,
    fontPackage: _iconsaxPackage,
    matchTextDirection: true,
  );

  /// Iconsax.send_2
  static const send = IconData(
    0xef3d,
    fontFamily: _iconsaxFont,
    fontPackage: _iconsaxPackage,
    matchTextDirection: true,
  );

  /// Iconsax.export_1
  static const upload = IconData(
    0xebbd,
    fontFamily: _iconsaxFont,
    fontPackage: _iconsaxPackage,
    matchTextDirection: true,
  );

  /// Work kept on the device because there was no network to send it over, and
  /// the second chance given to a piece of it that was refused.
  static const outbox = Iconsax.cloud_cross;
  static const retry = Iconsax.refresh;

  /// Reporting that you have arrived somewhere, and the code fixed at the place
  /// that proves it. A pin rather than a tick: what is being recorded is a
  /// PLACE, and a tick would read as "done".
  static const checkIn = Iconsax.location_tick;
  static const qrCode = Iconsax.scan_barcode;

  // Auth / account
  static const email = Iconsax.sms;
  static const password = Iconsax.lock;
  static const settings = Iconsax.setting_2;

  // Account switching. `removeAccount` is a person being taken off a list and
  // not a bin, because that is what it does: the account is dropped from this
  // device, and nothing at all happens to it on the server.
  static const accounts = Iconsax.profile_circle;
  static const switchAccount = Iconsax.arrow_swap_horizontal;
  static const removeAccount = Iconsax.user_minus;

  // A tick, for stating that something is done or present — a file has been
  // chosen, an inbox has been read. NOT for the selected half of a pair of
  // states: that is `SelectionIndicator`, which draws both halves so the empty
  // one is visibly empty. There is no `unselected` glyph here on purpose; it
  // used to be `Iconsax.record`, a filled disc, which is what SELECTED looks
  // like everywhere else in the world.
  static const selected = Iconsax.tick_circle;

  // Media
  static const camera = Iconsax.camera;
  static const gallery = Iconsax.gallery;
  static const addPhoto = Iconsax.gallery_add;
  static const image = Iconsax.gallery;
  static const view = Iconsax.eye;

  // Attachments. `attach` is the act; the rest name what was attached, so a
  // recipient can tell a voice note from a document without opening either.
  static const attach = Iconsax.paperclip_2;
  static const video = Iconsax.video_play;
  static const audio = Iconsax.musicnote;
  static const file = Iconsax.document_text;
  static const download = Iconsax.import_1;

  // Settings
  static const language = Iconsax.language_square;
  static const theme = Iconsax.moon;

  // ── The rail ────────────────────────────────────────────────────────────
  //
  // There was a second glyph here — a field of tiles — drawn beside the choice
  // in settings so the two arrangements were told apart by their SHAPE before
  // either word was read. The choice is gone and so is the tile field; this one
  // survives because two other screens spend it on «مكان في التطبيق».

  /// نمط الشريط الجانبي، وموضعٌ في التطبيق يُبلَّغ عنه.
  ///
  /// `row_vertical` — a plain vertical split — and deliberately not
  /// `sidebar_left`, which names a side. The rail stands on the START side, and
  /// that is the right in Arabic; an icon with "left" baked into its geometry
  /// would be pointing at the wrong edge for most of this app's readers, and
  /// Iconsax declares nothing with `matchTextDirection` to flip it back.
  static const layoutSidebar = Iconsax.row_vertical;

  /// The rail's own hamburger, on a window too narrow to stand one open.
  static const menu = Icons.menu;

  // Folding the rail down to its icons, and opening it again, is drawn with
  // [layoutSidebar] in both states and told apart by the wash behind it — see
  // `_RailFoldButton`. There were chevrons here once, pointing at the start
  // edge in each direction, and they were retired for standing an arrow sixty
  // pixels above the account block's [NavChevron]: two arrows in one narrow
  // column read as one offer repeated rather than as two different ones.

  // ── The operational map ─────────────────────────────────────────────────

  /// الخريطة التشغيلية — the page that stands where the tiles were.
  ///
  /// A branching hierarchy rather than [map]'s folded sheet: that one is the
  /// season's PLACES drawn on Makkah, and this is the season's ORDER — what is
  /// done first, and what cannot be done until it is. Two very different things
  /// both called a map in Arabic, and they must not share a glyph.
  static const roadmap = Iconsax.hierarchy_square_3;

  /// The end of a phase, on the spine of that map.
  static const milestone = Iconsax.flag_2;

  /// A step of the map that is somebody else's to take.
  ///
  /// Not a refusal and not an error — the map shows the whole season on
  /// purpose, and this says plainly which parts of it are in other hands.
  static const locked = Iconsax.lock_1;

  /// A line worth knowing that nothing else on a screen would have told you.
  static const tip = Iconsax.lamp_on;

  // Profile fields
  static const firstName = Iconsax.user;
  static const fatherName = Iconsax.profile_2user;
  static const surname = Iconsax.personalcard;
  static const jobTitle = Iconsax.briefcase;
  static const gender = Iconsax.man;
  static const mission = Iconsax.people;
  static const dateOfBirth = Iconsax.cake;
  static const phoneSy = Iconsax.call;
  static const phoneSa = Iconsax.mobile;

  /// Reaching the same number through WhatsApp rather than the dialler.
  ///
  /// A speech bubble, not a brand mark: Iconsax carries no WhatsApp glyph, and
  /// a hand-drawn imitation of one would be both a trademark and a worse icon.
  /// What the button does is send a MESSAGE instead of placing a call, and that
  /// is the distinction the icon has to carry beside [phoneSy].
  static const whatsApp = Iconsax.message_text;

  // Documents
  static const document = Iconsax.document_text;
  static const documentEmpty = Iconsax.document;
  static const brokenImage = Iconsax.gallery_slash;

  // Approvals / actions
  static const search = Iconsax.search_normal_1;
  static const permissions = Iconsax.security_user;
  static const approvals = Iconsax.user_tick;

  // Notifications
  static const notifications = Iconsax.notification;

  /// Something the reader has to do before a thing they switched on will work
  /// — a permission ungranted, a position unknown. Not an error: nothing has
  /// gone wrong, and the sentence beside this icon always says what fixes it.
  static const warning = Iconsax.danger;

  // ── Today, in both calendars ────────────────────────────────────────────
  //
  // Side by side on the greeting card, so the two badges have to be told apart
  // at a glance rather than read. A crescent is the Hijri calendar's own
  // instrument — it is how the month is declared — and a grid of days is the
  // other one's.

  /// التاريخ الهجري.
  static const hijriDate = Iconsax.moon;

  /// التاريخ الميلادي.
  static const gregorianDate = Iconsax.calendar;

  // Seasons
  static const seasons = Iconsax.calendar_1;
  static const participants = Iconsax.people;
  static const current = Iconsax.star_1;
  static const manageParticipants = Iconsax.user_edit;

  // Operational modules
  static const modules = Iconsax.folder_2;
  static const moduleType = Iconsax.category;
  static const tasks = Iconsax.task_square;
  static const roles = Iconsax.user_octagon;
  static const pdf = Iconsax.document_download;

  // The moves a task makes (0117). One glyph per transition, because the
  // buttons that carry them sit side by side and a row of identical circles
  // would be read by their labels alone — which is exactly what an icon is
  // there to spare.
  static const taskStart = Iconsax.play_circle;
  static const taskReturn = Iconsax.undo;
  static const taskReopen = Iconsax.refresh_left_square;
  static const taskCancel = Iconsax.close_circle;
  static const taskBoard = Iconsax.kanban;
  static const taskBatch = Iconsax.layer;
  static const taskSteps = Iconsax.task;

  /// التقارير — the published tables and notices, as distinct from the
  /// operational files. A clipboard rather than a document: a report is
  /// something posted for people to read, not a dossier somebody owns.
  static const reports = Iconsax.clipboard_text;

  /// A link to somewhere outside the app.
  static const link = Iconsax.link;
  static const referenceData = Iconsax.data;
  static const location = Iconsax.location;
  static const myLocation = Iconsax.gps;
  static const map = Iconsax.map_1;
  static const activate = Iconsax.flash_1;
  static const add = Iconsax.add;
  static const delete = Iconsax.trash;

  // Employees management
  static const employees = Iconsax.profile_2user;
  static const addUser = Iconsax.user_add;
  static const external = Iconsax.buildings_2;
  static const organization = Iconsax.buildings;
  static const suspend = Iconsax.slash;
  static const myProfile = Iconsax.user;
  static const shield = Iconsax.shield_tick;
  static const approve = Iconsax.tick_circle;
  static const reject = Iconsax.close_circle;
  static const edit = Iconsax.edit_2;

  /// The overflow affordance: Material's own, not Iconsax's.
  ///
  /// This one glyph is a convention before it is an icon — three dots stacked
  /// is what "there are more actions here" looks like on every Android screen a
  /// user has ever tapped. Drawing our own version of it would be style at the
  /// cost of recognition, and it is symmetrical, so it needs no RTL flipping.
  static const more = Icons.more_vert;
  static const emptyInbox = Iconsax.box;

  // Status
  static const pending = Iconsax.timer_1;
  static const rejected = Iconsax.close_circle;

  // Brand
  static const brand = Iconsax.moon;

  // ── The record of what happened ─────────────────────────────────────────
  static const auditLog = Iconsax.activity;

  // ── الشكاوى ──────────────────────────────────────────────────────────────
  //
  // A speech bubble with a question in it, not a warning triangle: a complaint
  // is something a person said, and most of them turn out to be a matter to
  // settle rather than an alarm to sound. The register is drawn with the same
  // glyph as one complaint — it is the same thing, counted.
  static const complaints = Iconsax.message_question;
  static const complaintLocked = Iconsax.lock_1;
  static const complaintUnlock = Iconsax.unlock;
  static const complaintDismissed = Iconsax.slash;

  // ── التقييم ──────────────────────────────────────────────────────────────
  //
  // A clipboard with a tick, and deliberately NOT [rating]'s star: the star is
  // the anonymous five-point verdict colleagues give each other inside a
  // finished file (migration 0059), and these are a different thing entirely —
  // a form the office wrote, filled by one named person, adding up to a mark
  // out of a total. Two features called تقييم in Arabic; one glyph between them
  // would be the app agreeing they are the same.
  static const evaluations = Iconsax.clipboard_tick;

  /// The paper itself, in الإدارة — what is being edited is the questions, not
  /// anybody's marks.
  static const evaluationForms = Iconsax.task_square;

  /// One مرحلة of a sheet, in the stepper along its top.
  static const evaluationStage = Iconsax.hierarchy_square_2;

  /// A question that is answered by choosing, and one that is answered by
  /// writing — the two kinds, told apart in the editor's menu.
  static const evaluationChoice = Iconsax.tick_square;
  static const evaluationWritten = Iconsax.edit;

  /// A mark, wherever a number out of a total is shown.
  static const evaluationScore = Iconsax.medal_star;

  // ── مواقيت الصلاة ────────────────────────────────────────────────────────
  //
  // Four glyphs for six marks, and the doubling is deliberate: only one of them
  // is ever on screen at a time — the card's hero shows the coming prayer and
  // nothing else — so الفجر and المغرب may share the low sun they both are, and
  // الظهر and العصر the high one. Six *different* suns in a row would be six
  // shapes a reader has to tell apart at twelve pixels, which is a puzzle, not
  // an icon set.
  static const prayerTimes = Iconsax.clock_1;
  static const prayerDawn = Iconsax.sun_fog;
  static const prayerSunrise = Iconsax.cloud_sunny;
  static const prayerNoon = Iconsax.sun_1;
  static const prayerNight = Iconsax.moon;

  // ── The season from above ───────────────────────────────────────────────
  static const dashboard = Iconsax.chart_2;
  static const trend = Iconsax.chart_success;
  static const rating = Iconsax.star_1;

  // ── السفر والتنقّل ───────────────────────────────────────────────────────
  //
  // One glyph per WAY OF MOVING, and that is the whole set: the feature draws a
  // movement by what carried it, so a new mode of transport costs exactly one
  // line here and one arm of `travelModeIcon`.
  //
  // [travelRoad] is the important one. It is what a man who drove himself from
  // مكة to المدينة gets, and it is a car — a real means of travel drawn as
  // plainly as the aeroplane beside it, never a gap, a question mark or a
  // warning. The whole design rests on that being unremarkable.
  static const travel = Iconsax.routing;
  static const travelAir = Iconsax.airplane;
  static const travelRail = Iconsax.bus;
  static const travelRoad = Iconsax.car;
  static const travelOther = Iconsax.driving;

  /// The way home. Drawn apart from [travelAir] because the return is the one
  /// movement the whole app counts down to.
  static const travelReturn = Iconsax.airplane_square;

  /// A booking — the ticket, the seat, the reference.
  static const travelTicket = Iconsax.ticket;

  /// A moment on the line: when a movement is due, and when it happened.
  static const travelWhen = Iconsax.calendar_1;
}

/// A trailing chevron that points toward the navigation direction, mirrored
/// correctly for RTL locales.
class NavChevron extends StatelessWidget {
  const NavChevron({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Material's chevron rather than an Iconsax arrow: the Iconsax variants are
    // solid triangles that read as "play", and their LTR/RTL pair have visibly
    // different weights.
    //
    // Always the RIGHT chevron, in both directions. Material declares this glyph
    // with `matchTextDirection: true`, so Flutter already flips it under an RTL
    // Directionality — picking the left chevron for Arabic mirrored it a second
    // time and pointed it back the way it came.
    return Icon(
      Icons.chevron_right_rounded,
      size: 24,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
