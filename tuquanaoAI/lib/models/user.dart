class UserModel {
  final String id;
  final String name;
  final String email;
  final int? age;
  final int birthYear;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.age,
    this.birthYear = 0,
    this.avatarUrl,
  });

  static const empty = UserModel(id: '', name: '', email: '');

  bool get isEmpty => id.isEmpty;

  String get initial =>
      name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id: j['id']?.toString() ?? '',
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    age: j['age'],
    birthYear: j['birthYear'] ?? 0,
    avatarUrl: j['avatarUrl'],
  );

  Map<String, dynamic> toUpdateJson() => {
    'name': name,
    'email': email,
    'age': age,
    'birthYear': birthYear,
  };

  UserModel copyWith({
    String? name,
    String? email,
    int? age,
    int? birthYear,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        age: age ?? this.age,
        birthYear: birthYear ?? this.birthYear,
        avatarUrl: avatarUrl,
      );
}