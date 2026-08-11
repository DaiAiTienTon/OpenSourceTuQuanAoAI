import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clothing_item.dart';
import '../models/outfit.dart';
import '../models/user.dart';
import '../models/user_preference.dart';
import '../api/api_client.dart';

enum SessionStatus { idle, loading, ready, error }

class SessionService extends ChangeNotifier {
  String? _userId;
  UserModel? _currentUser;
  UserPreference? _userPreference;
  List<ClothingItem> _clothingItems = [];
  List<Outfit> _outfits = [];
  List<OutfitItem> _outfitItems = [];

  SessionStatus _status = SessionStatus.idle;

  String? get userId             => _userId;
  UserModel? get currentUser     => _currentUser;
  UserPreference? get userPreference => _userPreference;
  List<ClothingItem> get clothingItems => _clothingItems;
  List<Outfit> get outfits       => _outfits;
  List<OutfitItem> get outfitItems => _outfitItems;
  SessionStatus get status       => _status;
  bool get isLoggedIn            => _userId != null && _userId!.isNotEmpty;

  // ── Called after login ────────────────────────────────────────────────
  Future<void> startSession(String userId, UserModel user) async {
    print('\n[Session] startSession userId=$userId, name=${user.name}');
    _userId      = userId;
    _currentUser = user;
    final prefs  = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await _loadAll();
  }

  // ── Try restore session on app start ─────────────────────────────────
  Future<bool> tryRestoreSession() async {
    print('\n[Session] tryRestoreSession...');
    final prefs   = await SharedPreferences.getInstance();
    final savedId = prefs.getString('userId');
    if (savedId == null || savedId.isEmpty) {
      print('[Session] Không có userId đã lưu → không restore');
      return false;
    }
    print('[Session] Tìm thấy savedId=$savedId, gọi GET /Users/$savedId');
    try {
      final res = await ApiClient.get('/Users/$savedId');
      print('[Session] GET /Users/$savedId → ${res.statusCode}');
      if (res.statusCode == 200) {
        final json   = ApiClient.parseJson(res);
        _userId      = savedId;
        _currentUser = UserModel.fromJson(json);
        print('[Session] Restore thành công: name=${_currentUser?.name}');
        await _loadAll();
        return true;
      } else {
        print('[Session] ❌ Restore thất bại (status ${res.statusCode})');
      }
    } catch (e) {
      print('[Session] ❌ Exception khi restore: $e');
    }
    return false;
  }

  Future<void> _loadAll() async {
    print('\n[Session] _loadAll() bắt đầu...');
    _status = SessionStatus.loading;
    notifyListeners();
    try {
      await Future.wait([
        _loadClothingItems(),
        _loadOutfits(),
        _loadOutfitItems(),
        _loadUserPreference(),
      ]);
      _status = SessionStatus.ready;
      print('[Session] _loadAll() hoàn tất ✅');
      print('[Session]   clothingItems : ${_clothingItems.length} món');
      print('[Session]   outfits       : ${_outfits.length}');
    } catch (e) {
      _status = SessionStatus.error;
      print('[Session] ❌ _loadAll() lỗi: $e');
    }
    notifyListeners();
  }

  Future<void> _loadClothingItems() async {
    print('[Session] GET /ClothingItems...');
    final res = await ApiClient.get('/ClothingItems');
    print('[Session] GET /ClothingItems → ${res.statusCode}');
    if (res.statusCode == 200) {
      final list = ApiClient.parseJsonList(res);
      _clothingItems = list
          .map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
          .where((c) => c.userId == _userId && c.isActive)
          .toList();
      print('[Session]   → Lọc được ${_clothingItems.length} item cho userId=$_userId');
    } else {
      print('[Session]   ❌ Load clothing items thất bại (${res.statusCode})');
    }
  }

  Future<void> _loadOutfits() async {
    print('[Session] GET /Outfits...');
    final res = await ApiClient.get('/Outfits');
    print('[Session] GET /Outfits → ${res.statusCode}');
    if (res.statusCode == 200) {
      final list = ApiClient.parseJsonList(res);
      _outfits = list
          .map((e) => Outfit.fromJson(e as Map<String, dynamic>))
          .where((o) => o.userId == _userId)
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
      print('[Session]   → ${_outfits.length} outfits cho userId=$_userId');
    } else {
      print('[Session]   ❌ Load outfits thất bại (${res.statusCode})');
    }
  }

  Future<void> _loadOutfitItems() async {
    print('[Session] GET /OutfitItems...');
    final res = await ApiClient.get('/OutfitItems');
    print('[Session] GET /OutfitItems → ${res.statusCode}');
    if (res.statusCode == 200) {
      final list = ApiClient.parseJsonList(res);
      _outfitItems = list
          .map((e) => OutfitItem.fromJson(e as Map<String, dynamic>))
          .toList();
      print('[Session]   → ${_outfitItems.length} outfit items');
    } else {
      print('[Session]   ❌ Load outfitItems thất bại (${res.statusCode})');
    }
  }

  Future<void> _loadUserPreference() async {
    print('[Session] GET /UserPreferences...');
    final res = await ApiClient.get('/UserPreferences');
    print('[Session] GET /UserPreferences → ${res.statusCode}');
    if (res.statusCode == 200) {
      final list  = ApiClient.parseJsonList(res);
      final match = list
          .map((e) => UserPreference.fromJson(e as Map<String, dynamic>))
          .where((p) => p.userId == _userId)
          .toList();
      _userPreference = match.isNotEmpty ? match.first : null;
      print('[Session]   → userPreference: ${_userPreference != null ? "tìm thấy" : "không có"}');
    } else {
      print('[Session]   ❌ Load userPreference thất bại (${res.statusCode})');
    }
  }

  // ── Mutators called by ViewModels ─────────────────────────────────────

  void updateUser(UserModel user) {
    print('[Session] updateUser: ${user.name}');
    _currentUser = user;
    notifyListeners();
  }

  void updateUserPreference(UserPreference pref) {
    print('[Session] updateUserPreference');
    _userPreference = pref;
    notifyListeners();
  }

  void addClothingItem(ClothingItem item) {
    print('[Session] addClothingItem → id=${item.id}, name="${item.name}"');
    _clothingItems = [..._clothingItems, item];
    print('[Session]   clothingItems count sau add: ${_clothingItems.length}');
    notifyListeners();
  }

  void updateClothingItem(ClothingItem item) {
    print('[Session] updateClothingItem → id=${item.id}, name="${item.name}"');
    final before = _clothingItems.length;
    _clothingItems = _clothingItems.map((c) => c.id == item.id ? item : c).toList();
    final matched = _clothingItems.where((c) => c.id == item.id).length;
    print('[Session]   count trước/sau: $before/${_clothingItems.length}, matched=$matched');
    notifyListeners();
  }

  void removeClothingItem(String id) {
    print('[Session] removeClothingItem → id=$id');
    final before = _clothingItems.length;
    _clothingItems = _clothingItems.where((c) => c.id != id).toList();
    final after = _clothingItems.length;
    print('[Session]   count trước=$before, sau=$after, đã xoá=${before - after} item');
    if (before == after) {
      print('[Session]   ⚠️  Không tìm thấy item id=$id trong local list để xoá!');
    }
    notifyListeners();
  }

  void addOutfit(Outfit outfit, List<OutfitItem> items) {
    print('[Session] addOutfit → id=${outfit.id}');
    _outfits     = [outfit, ..._outfits];
    _outfitItems = [..._outfitItems, ...items];
    notifyListeners();
  }

  // ── Logout ────────────────────────────────────────────────────────────
  Future<void> clearSession() async {
    print('\n[Session] clearSession()');
    _userId         = null;
    _currentUser    = null;
    _userPreference = null;
    _clothingItems  = [];
    _outfits        = [];
    _outfitItems    = [];
    _status         = SessionStatus.idle;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await ApiClient.clearToken();
    print('[Session] clearSession() hoàn tất');
    notifyListeners();
  }
}