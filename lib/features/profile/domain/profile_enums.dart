// Domain enums mirroring the Postgres enum types.

enum AccountStatus {
  incomplete,
  pending,
  approved,
  rejected;

  static AccountStatus fromDb(String? value) => switch (value) {
    'incomplete' => AccountStatus.incomplete,
    'pending' => AccountStatus.pending,
    'approved' => AccountStatus.approved,
    'rejected' => AccountStatus.rejected,
    _ => AccountStatus.incomplete,
  };

  String get db => name;
}

enum Gender {
  male,
  female;

  static Gender? fromDb(String? value) => switch (value) {
    'male' => Gender.male,
    'female' => Gender.female,
    _ => null,
  };

  String get db => name;
  String get arabicLabel => this == Gender.male ? 'ذكر' : 'أنثى';
}

// نوع البعثة was here, as an enum of three. It is master data now (0085): the
// office adds a mission the way it adds a hotel, and the app reads the name off
// the row instead of owning the wording. See [ReferenceChoice].
