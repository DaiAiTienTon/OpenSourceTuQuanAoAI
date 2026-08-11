import 'package:flutter/foundation.dart';
import '../service/Session_service.dart';
import '../api/api_client.dart';

class HealthData {
  final String heartRate;
  final String bloodPressure;
  final String weight;
  final String sleep;
  final String notes;

  const HealthData({
    this.heartRate = '',
    this.bloodPressure = '',
    this.weight = '',
    this.sleep = '',
    this.notes = '',
  });

  HealthData copyWith({
    String? heartRate,
    String? bloodPressure,
    String? weight,
    String? sleep,
    String? notes,
  }) =>
      HealthData(
        heartRate:     heartRate     ?? this.heartRate,
        bloodPressure: bloodPressure ?? this.bloodPressure,
        weight:        weight        ?? this.weight,
        sleep:         sleep         ?? this.sleep,
        notes:         notes         ?? this.notes,
      );
}

// ── Kết quả validation ────────────────────────────────────────────────────────
class ValidationResult {
  final Map<String, String> errors;    // lỗi cứng – không cho lưu
  final Map<String, String> warnings;  // cảnh báo mềm – hỏi xác nhận

  const ValidationResult({
    this.errors   = const {},
    this.warnings = const {},
  });

  bool get hasErrors   => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

// ── Hằng số ───────────────────────────────────────────────────────────────────
const int    kNotesMaxLength = 500;  // TC08-12
const double kHeartRateMax   = 200;  // TC08-10: > 200 bpm → cảnh báo
const double kSleepHoursMax  = 24;   // TC08-08: > 24 giờ  → cảnh báo

class HealthViewModel extends ChangeNotifier {
  SessionService _session;

  HealthData _data = const HealthData();
  bool _saved      = false;
  bool _saving     = false;
  bool _loading    = false;
  String? _existingId;

  Map<String, String> _fieldErrors     = {};
  Map<String, String> _pendingWarnings = {};

  HealthViewModel({required SessionService session}) : _session = session;

  void updateSession(SessionService session) => _session = session;

  HealthData get data                     => _data;
  bool get saved                          => _saved;
  bool get saving                         => _saving;
  bool get loading                        => _loading;
  Map<String, String> get fieldErrors     => Map.unmodifiable(_fieldErrors);
  Map<String, String> get pendingWarnings => Map.unmodifiable(_pendingWarnings);
  bool get hasPendingWarnings             => _pendingWarnings.isNotEmpty;

  String _todayDate() {
    final t = DateTime.now();
    return '${t.year}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  // ── Reset local state ─────────────────────────────────────────────────────
  void reset() {
    _data            = const HealthData();
    _existingId      = null;
    _saved           = false;
    _saving          = false;
    _loading         = false;
    _fieldErrors     = {};
    _pendingWarnings = {};
    notifyListeners();
  }

  // ── TC08-03: Load dữ liệu hôm nay từ server ──────────────────────────────
  Future<void> load() async {
    final userId = _session.userId ?? '';
    print('=== [Health] load() userId=$userId');
    if (userId.isEmpty) return;

    _existingId      = null;
    _data            = const HealthData();
    _fieldErrors     = {};
    _pendingWarnings = {};
    _loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.get(
          '/HealthLogs/user/$userId/date/${_todayDate()}');
      print('=== [Health] statusCode=${res.statusCode}');

      if (res.statusCode == 200) {
        final json = ApiClient.parseJson(res) as Map<String, dynamic>;
        if (json['userId']?.toString() == userId) {
          _existingId = json['id']?.toString();
          _data = HealthData(
            heartRate:     json['heartRate']?.toString()     ?? '',
            bloodPressure: json['bloodPressure']?.toString() ?? '',
            weight:        json['weight']?.toString()        ?? '',
            sleep:         json['sleepHours']?.toString()    ?? '',
            notes:         json['notes']?.toString()         ?? '',
          );
          print('=== [Health] ✅ Load OK - existingId=$_existingId');
        }
      }
    } catch (e) {
      print('=== [Health] ❌ load Exception: $e');
    }

    _loading = false;
    notifyListeners();
  }

  // ── Cập nhật từng trường, xoá lỗi tương ứng ─────────────────────────────
  void update({
    String? heartRate,
    String? bloodPressure,
    String? weight,
    String? sleep,
    String? notes,
  }) {
    if (heartRate     != null) _fieldErrors.remove('heartRate');
    if (bloodPressure != null) _fieldErrors.remove('bloodPressure');
    if (weight        != null) _fieldErrors.remove('weight');
    if (sleep         != null) _fieldErrors.remove('sleep');
    if (notes         != null) _fieldErrors.remove('notes');

    _data  = _data.copyWith(
      heartRate:     heartRate,
      bloodPressure: bloodPressure,
      weight:        weight,
      sleep:         sleep,
      notes:         notes,
    );
    _saved = false;
    notifyListeners();
  }

  // ── Validation ────────────────────────────────────────────────────────────
  //
  // Các trường số (nhịp tim, cân nặng, giờ ngủ) dùng FilteringTextInputFormatter
  // ở tầng UI → dấu âm và chữ cái bị chặn ngay khi gõ.
  // Do đó KHÔNG cần check giá trị âm trong validation logic
  // (TC08-05, TC08-06, TC08-07 đã xoá khỏi bảng test).
  //
  // Vẫn giữ check parse null để phòng trường hợp paste chữ (TC08-11).
  //
  ValidationResult _validate() {
    final errors   = <String, String>{};
    final warnings = <String, String>{};

    // ── Nhịp tim (TC08-10, TC08-11) ──────────────────────────────────────
    if (_data.heartRate.isNotEmpty) {
      final hr = double.tryParse(_data.heartRate.trim());
      if (hr == null) {
        // TC08-11: paste chữ bypass formatter
        errors['heartRate'] = 'Vui lòng nhập số hợp lệ';
      } else if (hr > kHeartRateMax) {
        // TC08-10: > 200 bpm → cảnh báo, không phải lỗi cứng
        warnings['heartRate'] =
        'Nhịp tim bất thường (${hr.toStringAsFixed(0)} bpm), '
            'bạn có chắc chắn muốn lưu?';
      }
    }

    // ── Huyết áp (TC08-09) ───────────────────────────────────────────────
    if (_data.bloodPressure.isNotEmpty) {
      final bpPattern = RegExp(r'^\d{1,3}/\d{1,3}$');
      if (!bpPattern.hasMatch(_data.bloodPressure.trim())) {
        errors['bloodPressure'] =
        'Huyết áp không đúng định dạng (vd: 120/80)';
      }
    }

    // ── Cân nặng (TC08-11) ───────────────────────────────────────────────
    if (_data.weight.isNotEmpty) {
      final w = double.tryParse(_data.weight.trim());
      if (w == null) {
        // TC08-11: paste chữ bypass formatter
        errors['weight'] = 'Vui lòng nhập số hợp lệ';
      }
    }

    // ── Giờ ngủ (TC08-08, TC08-11) ───────────────────────────────────────
    if (_data.sleep.isNotEmpty) {
      final s = double.tryParse(_data.sleep.trim());
      if (s == null) {
        // TC08-11: paste chữ bypass formatter
        errors['sleep'] = 'Vui lòng nhập số hợp lệ';
      } else if (s > kSleepHoursMax) {
        // TC08-08: > 24 giờ → cảnh báo, không phải lỗi cứng
        warnings['sleep'] =
        'Số giờ ngủ bất thường (${s.toStringAsFixed(0)} giờ), '
            'bạn có chắc chắn muốn lưu?';
      }
    }

    // ── Ghi chú (TC08-12) ────────────────────────────────────────────────
    if (_data.notes.length > kNotesMaxLength) {
      errors['notes'] =
      'Nội dung quá dài, tối đa $kNotesMaxLength ký tự '
          '(hiện tại: ${_data.notes.length})';
    }

    return ValidationResult(errors: errors, warnings: warnings);
  }

  // ── Save flow ─────────────────────────────────────────────────────────────

  /// Gọi từ UI khi nhấn "Lưu".
  /// - Có lỗi cứng  → set fieldErrors, return false (không mở dialog)
  /// - Có cảnh báo  → set pendingWarnings, return true (UI mở dialog xác nhận)
  /// - Hợp lệ hoàn toàn → lưu ngay, return false  (TC08-01, TC08-02)
  Future<bool> requestSave() async {
    final result = _validate();

    if (result.hasErrors) {
      _fieldErrors     = Map.of(result.errors);
      _pendingWarnings = {};
      notifyListeners();
      return false;
    }

    if (result.hasWarnings) {
      _fieldErrors     = {};
      _pendingWarnings = Map.of(result.warnings);
      notifyListeners();
      return true;
    }

    await _doSave();
    return false;
  }

  /// User bấm "Vẫn lưu" trong dialog cảnh báo (TC08-08, TC08-10)
  Future<void> confirmSaveWithWarnings() async {
    _pendingWarnings = {};
    notifyListeners();
    await _doSave();
  }

  /// User bấm "Huỷ" trong dialog cảnh báo (TC08-08, TC08-10)
  void cancelPendingWarnings() {
    _pendingWarnings = {};
    notifyListeners();
  }

  Future<void> _doSave() async {
    if (_saving) return;
    final userId = _session.userId ?? '';
    if (userId.isEmpty) return;

    _saving = true;
    notifyListeners();

    final body = <String, dynamic>{
      'userId':        userId,
      'logDate':       _todayDate(),
      'heartRate':     _data.heartRate.isEmpty     ? null : _data.heartRate,
      'bloodPressure': _data.bloodPressure.isEmpty ? null : _data.bloodPressure,
      'weight':        _data.weight.isEmpty        ? null : double.tryParse(_data.weight),
      'sleepHours':    _data.sleep.isEmpty         ? null : double.tryParse(_data.sleep),
      'notes':         _data.notes.isEmpty         ? null : _data.notes,
    };

    try {
      if (_existingId != null) {
        final res = await ApiClient.put(
            '/HealthLogs/$_existingId', {'id': _existingId, ...body});
        if (res.statusCode == 204) _saved = true;
      } else {
        final res = await ApiClient.post('/HealthLogs', body);
        if (res.statusCode == 201 || res.statusCode == 200) {
          final json = ApiClient.parseJson(res) as Map<String, dynamic>;
          _existingId = json['id']?.toString();
          _saved = true;
        }
      }
    } catch (e) {
      print('=== [Health] ❌ _doSave Exception: $e');
    }

    _saving = false;
    notifyListeners();

    if (_saved) {
      Future.delayed(const Duration(seconds: 3), () {
        _saved = false;
        notifyListeners();
      });
    }
  }

  // ── Đặt lại & xoá bản ghi trên server ────────────────────────────────────
  Future<bool> resetHealthData() async {
    final userId = _session.userId ?? '';
    if (userId.isEmpty) return false;

    try {
      if (_existingId != null) {
        final res = await ApiClient.delete('/HealthLogs/$_existingId');
        if (res.statusCode == 204) {
          reset();
          return true;
        }
        return false;
      } else {
        reset();
        return true;
      }
    } catch (e) {
      print('=== [Health] ❌ resetHealthData Exception: $e');
      return false;
    }
  }

  // Backward-compat
  Future<void> save() => _doSave();
}