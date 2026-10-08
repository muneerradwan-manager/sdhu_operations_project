/// An account this device can return to without being asked for a password.
///
/// The credential is [refreshToken] — a Supabase refresh token, which is a way
/// into the account and nothing less. It lives in the platform keystore and
/// never in shared preferences, and it is the reason this class carries a
/// `toString` that says nothing: an object like this ends up in a log line
/// sooner or later, and a log is not a private place.
class SavedAccount {
  const SavedAccount({
    required this.userId,
    required this.email,
    required this.refreshToken,
    required this.lastUsedAt,
    this.name,
    this.photoUrl,
  });

  final String userId;
  final String email;
  final String refreshToken;

  /// When this account was last the signed-in one. Drives the order of the
  /// picker and the pruning of accounts nobody has come back to.
  final DateTime lastUsedAt;

  /// The display name and photo as of the last time this account was open.
  /// Both are conveniences for the picker: a card showing a face and a name is
  /// recognised at a glance, where a row of similar addresses is read.
  final String? name;
  final String? photoUrl;

  /// What to put on the card. The name if there is one, the address otherwise —
  /// an account saved before its profile was filled in has only the address,
  /// and an empty card is worse than a plain one.
  String get label {
    final trimmed = name?.trim();
    return (trimmed == null || trimmed.isEmpty) ? email : trimmed;
  }

  SavedAccount copyWith({
    String? email,
    String? refreshToken,
    DateTime? lastUsedAt,
    String? name,
    String? photoUrl,
  }) {
    return SavedAccount(
      userId: userId,
      email: email ?? this.email,
      refreshToken: refreshToken ?? this.refreshToken,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'email': email,
    'refresh_token': refreshToken,
    'last_used_at': lastUsedAt.toIso8601String(),
    if (name != null) 'name': name,
    if (photoUrl != null) 'photo_url': photoUrl,
  };

  /// Null for a row that cannot be used. The stored list is read at startup and
  /// one unreadable entry — written by an older version, or truncated — must
  /// not cost the person the accounts that are still good.
  static SavedAccount? fromJson(Map<String, dynamic> map) {
    final id = map['user_id'];
    final token = map['refresh_token'];
    if (id is! String || id.isEmpty) return null;
    if (token is! String || token.isEmpty) return null;

    return SavedAccount(
      userId: id,
      email: map['email'] as String? ?? '',
      refreshToken: token,
      lastUsedAt:
          DateTime.tryParse(map['last_used_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      name: map['name'] as String?,
      photoUrl: map['photo_url'] as String?,
    );
  }

  @override
  String toString() => 'SavedAccount($userId)';
}
