class Member {
  const Member({
    required this.id,
    required this.email,
    required this.givenName,
    this.surname,
    required this.role,
    required this.active,
  });

  final String id;
  final String email;
  final String givenName;
  final String? surname;
  final int role;
  final bool active;

  bool get isAdmin => role == 1;

  factory Member.fromMap(Map<String, Object?> map) => Member(
    id: map['id'] as String,
    email: map['email'] as String,
    givenName: map['givenName'] as String,
    surname: map['surname'] as String?,
    role: map['role'] as int,
    active: map['active'] == 1,
  );
}
