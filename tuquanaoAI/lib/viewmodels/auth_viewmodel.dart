import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../service/Session_service.dart';
import '../api/api_client.dart';

enum AuthScreen { login, register }

class AuthViewModel extends ChangeNotifier {
  SessionService _session;

  AuthScreen _screen = AuthScreen.login;
  bool _loading = false;
  String _error = '';

  AuthViewModel({required SessionService session}) : _session = session;

  void updateSession(SessionService session) {
    _session = session;
  }

  AuthScreen get screen => _screen;
  bool get loading => _loading;
  String get error => _error;
  bool get isAuthenticated => _session.isLoggedIn;

  void goToRegister() {
    _screen = AuthScreen.register;
    _error = '';
    notifyListeners();
  }

  void goToLogin() {
    _screen = AuthScreen.login;
    _error = '';
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _loading = true;
    _error = '';
    notifyListeners();

    try {
      print('[AuthVM] Đang đăng nhập với email: $email');
      final res = await ApiClient.post(
        '/Users/login',
        {'email': email.trim(), 'password': password},
        auth: false,
      );

      print('[AuthVM] Kết quả Login: StatusCode = ${res.statusCode}');

      if (res.statusCode == 200) {
        final json = ApiClient.parseJson(res);
        final token = json['token']?.toString() ?? '';
        final userId = json['userId']?.toString() ?? '';

        print('[AuthVM] Token: $token');
        print('[AuthVM] UserId: $userId');
        print('[AuthVM] Token isEmpty: ${token.isEmpty}');
        print('[AuthVM] UserId isEmpty: ${userId.isEmpty}');


        if (token.isNotEmpty) await ApiClient.saveToken(token);

        print('[AuthVM] Đang lấy thông tin User Profile cho ID: $userId');
        final userRes = await ApiClient.get('/Users/$userId');
        print('[AuthVM] Profile status: ${userRes.statusCode}');
        print('[AuthVM] Profile body: ${userRes.body}');

        if (userRes.statusCode == 200) {
          final userJson = ApiClient.parseJson(userRes);
          final user = UserModel.fromJson(userJson);
          await _session.startSession(userId, user);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_email', email.trim());

          print('[AuthVM] Đăng nhập & Lưu session thành công');
        } else {
          _error = 'Không tải được thông tin người dùng';
          print('[AuthVM] Lỗi lấy Profile: Status ${userRes.statusCode}');
        }
      } else if (res.statusCode == 401) {
        _error = 'Email hoặc mật khẩu không đúng';
        print('[AuthVM] Sai thông tin đăng nhập (401)');
      } else {
        _error = 'Đăng nhập thất bại (${res.statusCode})';
        print('[AuthVM] Lỗi hệ thống: ${res.body}');
      }
    } catch (e) {
      _error = 'Lỗi kết nối mạng';
      print('[AuthVM] Catch Exception Login: $e');
    }

    _loading = false;
    notifyListeners();
  }

  // BUG FIX TC01-02: Kiểm tra email trùng trước khi sang bước 2
  // Gọi API /Users/check-email để xác nhận phía server
  Future<bool> checkEmailExists(String email) async {
    try {
      final res = await ApiClient.post(
        '/Users/check-email',
        {'email': email},
        auth: false,
      );
      if (res.statusCode == 200) {
        final json = ApiClient.parseJson(res);
        return json['exists'] == true;
      }
    } catch (e) {
      print('[AuthVM] Lỗi check-email: $e');
    }
    return false;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String dob,
    required List<String> hobbies,
  }) async {
    _loading = true;
    _error = '';
    notifyListeners();

    print('[AuthVM] Đang đăng ký cho email: $email');
    bool success = false;
    try {
      final res = await ApiClient.post(
        '/Users/register',
        {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'dateOfBirth': dob,
          'hobbies': hobbies,
        },
        auth: false,
      );

      print('[AuthVM] Kết quả Register: StatusCode = ${res.statusCode}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        try {
          final json = ApiClient.parseJson(res);
          final userId =
              json['userId']?.toString() ?? json['id']?.toString() ?? '';

          if (userId.isNotEmpty && hobbies.isNotEmpty) {
            print(
                '[AuthVM] Đang gửi sở thích lên UserPreferences cho UserId: $userId');
            final prefRes = await ApiClient.post('/UserPreferences', {
              'userId': userId,
              'hobbies': jsonEncode(hobbies),
              'stylePreference': null,
              'defaultLocation': null,
            }, auth: false);
            print(
                '[AuthVM] Kết quả gửi sở thích: ${prefRes.statusCode}');
          }
        } catch (e) {
          print(
              '[AuthVM] Lỗi khi xử lý lưu sở thích (không chặn đăng ký): $e');
        }

        success = true;
      } else if (res.statusCode == 400) {
        _error = 'Email đã được sử dụng hoặc dữ liệu không hợp lệ';
        print('[AuthVM] Lỗi 400 (Bad Request): ${res.body}');
      } else {
        _error = 'Đăng ký thất bại (${res.statusCode})';
        print('[AuthVM] Lỗi đăng ký khác: ${res.body}');
      }
    } catch (e) {
      _error = 'Lỗi kết nối mạng';
      print('[AuthVM] Catch Exception Register: $e');
    }

    _loading = false;
    notifyListeners();
    return success;
  }

  Future<void> logout() async {
    print('[AuthVM] Đang đăng xuất...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _session.clearSession();
    _screen = AuthScreen.login;
    _error = '';
    notifyListeners();
  }
}