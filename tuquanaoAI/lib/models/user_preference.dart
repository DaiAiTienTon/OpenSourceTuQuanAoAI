import 'dart:convert';

class UserPreference {
  final String id;
  final String userId;
  final List<String> hobbies;
  final String? stylePreference;
  final String? defaultLocation;

  const UserPreference({
    required this.id,
    required this.userId,
    this.hobbies = const [],
    this.stylePreference,
    this.defaultLocation,
  });

  factory UserPreference.fromJson(Map<String, dynamic> j) {
    List<String> hobbies = [];
    final raw = j['hobbies'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          hobbies = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        hobbies = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    } else if (raw is List) {
      hobbies = raw.map((e) => e.toString()).toList();
    }
    return UserPreference(
      id: j['id']?.toString() ?? '',
      userId: j['userId']?.toString() ?? '',
      hobbies: hobbies,
      stylePreference: j['stylePreference'],
      defaultLocation: j['defaultLocation'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'hobbies': jsonEncode(hobbies),
    'stylePreference': stylePreference,
    'defaultLocation': defaultLocation,
  };

  UserPreference copyWith({List<String>? hobbies}) => UserPreference(
    id: id,
    userId: userId,
    hobbies: hobbies ?? this.hobbies,
    stylePreference: stylePreference,
    defaultLocation: defaultLocation,
  );
}