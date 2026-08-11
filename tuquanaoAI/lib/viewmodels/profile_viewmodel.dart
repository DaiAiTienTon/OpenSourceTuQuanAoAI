import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/user_preference.dart';
import '../service/Session_service.dart';
import '../api/api_client.dart';

class ProfileViewModel extends ChangeNotifier {
  SessionService _session;

  bool _isEditing = false;
  bool _isAddingHobby = false;
  bool _saving = false;
  String? _errorMessage;
  String? _successMessage;

  ProfileViewModel({required SessionService session}) : _session = session;

  void updateSession(SessionService session) {
    _session = session;
    _isEditing = false;
    _isAddingHobby = false;
    _saving = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  UserModel get user => _session.currentUser ?? UserModel.empty;
  bool get isEditing => _isEditing;
  bool get isAddingHobby => _isAddingHobby;
  bool get saving => _saving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void startEditing() {
    _isEditing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void cancelEditing() {
    _isEditing = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  void setAddingHobby(bool v) {
    _isAddingHobby = v;
    notifyListeners();
  }

  Future<void> saveProfile({
    required String name,
    required String email,
    required int birthYear,
  }) async {
    // ── Validation ────────────────────────────────────────────────────────
    if (name.trim().isEmpty) {
      _errorMessage = 'Họ tên không được để trống';
      notifyListeners();
      return;
    }
    if (email.trim().isEmpty) {
      _errorMessage = 'Email không được để trống';
      notifyListeners();
      return;
    }
    if (birthYear > 0 && birthYear > DateTime.now().year) {
      _errorMessage = 'Năm sinh không hợp lệ';
      notifyListeners();
      return;
    }

    if (_saving) return;
    _saving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final id  = user.id;
    final age = birthYear > 0 ? DateTime.now().year - birthYear : user.age;

    try {
      final res = await ApiClient.put('/Users/$id', {
        'name': name.trim(),
        'email': email.trim(),
        'age': age,
        'birthYear': birthYear,
      });

      if (res.statusCode == 204) {
        _session.updateUser(user.copyWith(
          name: name.trim(),
          email: email.trim(),
          age: age,
          birthYear: birthYear,
        ));
        _isEditing = false;
        _successMessage = 'Cập nhật thành công';
      } else {
        _errorMessage = 'Lưu thất bại, vui lòng thử lại';
      }
    } catch (_) {
      _errorMessage = 'Lỗi kết nối, vui lòng thử lại';
    }

    _saving = false;
    notifyListeners();
  }

  Future<void> addHobby(String hobby) async {
    if (hobby.trim().isEmpty) return;
    final pref    = _session.userPreference;
    final updated = <String>[...(pref?.hobbies ?? [])];
    if (!updated.contains(hobby.trim())) updated.add(hobby.trim());
    await _saveHobbies(updated, pref);
    setAddingHobby(false);
  }

  Future<void> removeHobby(String hobby) async {
    final pref    = _session.userPreference;
    final updated = <String>[
      ...(pref?.hobbies ?? []).where((h) => h != hobby),
    ];
    await _saveHobbies(updated, pref);
  }

  Future<void> editHobby(String oldHobby, String newHobby) async {
    if (newHobby.trim().isEmpty || oldHobby == newHobby.trim()) return;
    final pref    = _session.userPreference;
    final updated = <String>[
      ...(pref?.hobbies ?? []).map((h) => h == oldHobby ? newHobby.trim() : h),
    ];
    await _saveHobbies(updated, pref);
  }

  Future<void> _saveHobbies(
      List<String> hobbies, UserPreference? existing) async {
    final userId = _session.userId ?? '';
    if (userId.isEmpty) return;

    try {
      if (existing == null) {
        final res = await ApiClient.post('/UserPreferences', {
          'userId': userId,
          'hobbies': jsonEncode(hobbies),
          'stylePreference': null,
          'defaultLocation': null,
        });
        if (res.statusCode == 201 || res.statusCode == 200) {
          final json = ApiClient.parseJson(res);
          _session.updateUserPreference(UserPreference.fromJson(json));
        }
      } else {
        final res = await ApiClient.put('/UserPreferences/${existing.id}', {
          'id': existing.id,
          'userId': userId,
          'hobbies': jsonEncode(hobbies),
          'stylePreference': existing.stylePreference,
          'defaultLocation': existing.defaultLocation,
        });
        if (res.statusCode == 204) {
          _session.updateUserPreference(existing.copyWith(hobbies: hobbies));
        }
      }
    } catch (_) {}

    notifyListeners();
  }
}