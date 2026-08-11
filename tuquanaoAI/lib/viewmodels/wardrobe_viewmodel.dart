import 'package:flutter/foundation.dart';
import '../models/clothing_item.dart';
import '../service/Session_service.dart';
import '../api/api_client.dart';

class WardrobeViewModel extends ChangeNotifier {
  SessionService _session;

  String _activeCloset  = 'tops';
  String _searchQuery   = '';
  bool   _isAdding      = false;
  bool   _isSaving      = false;
  String? _errorMessage;
  String? _successMessage;
  ClothingItem? _editingItem;

  WardrobeViewModel({required SessionService session}) : _session = session;

  void updateSession(SessionService session) {
    _session      = session;
    _isAdding     = false;
    _editingItem  = null;
    _isSaving     = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  String        get activeCloset  => _activeCloset;
  String        get searchQuery   => _searchQuery;
  bool          get isAdding      => _isAdding;
  bool          get isSaving      => _isSaving;
  String?       get errorMessage  => _errorMessage;
  String?       get successMessage => _successMessage;
  ClothingItem? get editingItem   => _editingItem;

  Wardrobe get wardrobe {
    final items = _session.clothingItems;
    return Wardrobe(
      tops:    items.where((c) => c.category == 'tops').toList(),
      bottoms: items.where((c) => c.category == 'bottoms').toList(),
    );
  }

  List<ClothingItem> get filteredItems {
    final list = _activeCloset == 'tops' ? wardrobe.tops : wardrobe.bottoms;
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  int get topsCount    => wardrobe.tops.length;
  int get bottomsCount => wardrobe.bottoms.length;

  void clearMessages() {
    _errorMessage   = null;
    _successMessage = null;
  }

  void setActiveCloset(String key) {
    _activeCloset   = key;
    _isAdding       = false;
    _editingItem    = null;
    _errorMessage   = null;
    _successMessage = null;
    notifyListeners();
  }

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void startAdding() {
    if (_isSaving) return;
    _isAdding       = true;
    _editingItem    = null;
    _errorMessage   = null;
    _successMessage = null;
    notifyListeners();
  }

  void cancelAdding() {
    _isAdding     = false;
    _errorMessage = null;
    notifyListeners();
  }

  void startEditing(ClothingItem item) {
    if (_isSaving) return;
    _editingItem    = item;
    _isAdding       = false;
    _errorMessage   = null;
    _successMessage = null;
    notifyListeners();
  }

  void cancelEditing() {
    _editingItem  = null;
    _errorMessage = null;
    notifyListeners();
  }

  // ── ADD ───────────────────────────────────────────────────────────────────
  Future<void> addItem(String name, String desc) async {
    // ── Validation ────────────────────────────────────────────────────────
    if (name.trim().isEmpty) {
      _errorMessage = 'Vui lòng nhập tên trang phục';
      notifyListeners();
      return;
    }
    if (_isSaving) return;

    final userId = _session.userId ?? '';
    if (userId.isEmpty) return;

    _isSaving     = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/ClothingItems', {
        'userId':      userId,
        'name':        name.trim(),
        'description': desc.trim(),
        'category':    _activeCloset,
        'isActive':    true,
      });

      if (res.statusCode == 201 || res.statusCode == 200) {
        final json = ApiClient.parseJson(res);
        final item = ClothingItem.fromJson(json);
        _session.addClothingItem(item);
        _isAdding       = false;
        _successMessage = 'Thêm thành công';
      } else {
        _errorMessage = 'Thêm thất bại, vui lòng thử lại';
      }
    } catch (_) {
      _errorMessage = 'Lỗi kết nối, vui lòng thử lại';
    }

    _isSaving = false;
    notifyListeners();
  }

  // ── SAVE EDIT ─────────────────────────────────────────────────────────────
  Future<void> saveEdit(ClothingItem updated) async {
    // ── Validation ────────────────────────────────────────────────────────
    if (updated.name.trim().isEmpty) {
      _errorMessage = 'Vui lòng nhập tên trang phục';
      notifyListeners();
      return;
    }
    if (_isSaving) return;

    _isSaving     = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.put('/ClothingItems/${updated.id}', {
        'id':          updated.id,
        'userId':      updated.userId,
        'name':        updated.name.trim(),
        'description': updated.desc.trim(),
        'category':    updated.category,
        'color':       updated.color,
        'season':      updated.season,
        'isActive':    updated.isActive,
      });

      if (res.statusCode == 204) {
        _session.updateClothingItem(updated);
        _editingItem    = null;
        _successMessage = 'Cập nhật thành công';
      } else if (res.statusCode == 404) {
        _errorMessage = 'Trang phục không tồn tại trên server';
      } else {
        _errorMessage = 'Lưu thất bại, vui lòng thử lại';
      }
    } catch (_) {
      _errorMessage = 'Lỗi kết nối, vui lòng thử lại';
    }

    _isSaving = false;
    notifyListeners();
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  Future<void> deleteItem(String id) async {
    if (_isSaving) return;

    _isSaving     = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.delete('/ClothingItems/$id');

      if (res.statusCode == 204) {
        _session.removeClothingItem(id);
        _editingItem    = null;
        _successMessage = 'Đã xóa trang phục';
      } else if (res.statusCode == 404) {
        _errorMessage = 'Trang phục không tồn tại';
      } else {
        _errorMessage = 'Xóa thất bại, vui lòng thử lại';
      }
    } catch (_) {
      _errorMessage = 'Lỗi kết nối, vui lòng thử lại';
    }

    _isSaving = false;
    notifyListeners();
  }
}