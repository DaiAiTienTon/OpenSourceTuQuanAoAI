class Outfit {
  final String id;
  final String userId;
  final String name;
  final String? occasion; // maps to "note" in UI
  final DateTime? createdAt;

  const Outfit({
    required this.id,
    required this.userId,
    required this.name,
    this.occasion,
    this.createdAt,
  });

  String? get note => occasion;

  factory Outfit.fromJson(Map<String, dynamic> j) => Outfit(
    id: j['id']?.toString() ?? '',
    userId: j['userId']?.toString() ?? '',
    name: j['name'] ?? '',
    occasion: j['occasion'],
    createdAt: j['createdAt'] != null
        ? DateTime.tryParse(j['createdAt'].toString())
        : null,
  );
}

class OutfitItem {
  final String id;
  final String outfitId;
  final String clothingItemId;
  final String? role;

  const OutfitItem({
    required this.id,
    required this.outfitId,
    required this.clothingItemId,
    this.role,
  });

  factory OutfitItem.fromJson(Map<String, dynamic> j) => OutfitItem(
    id: j['id']?.toString() ?? '',
    outfitId: j['outfitId']?.toString() ?? '',
    clothingItemId: j['clothingItemId']?.toString() ?? '',
    role: j['role'],
  );
}