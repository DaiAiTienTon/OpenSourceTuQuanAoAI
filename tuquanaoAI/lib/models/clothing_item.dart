class ClothingItem {
  final String id;
  final String userId;
  final String name;
  final String desc;        // maps to "description"
  final String category;   // "tops" | "bottoms"
  final String? color;
  final String? season;
  final bool isActive;

  const ClothingItem({
    required this.id,
    required this.userId,
    required this.name,
    this.desc = '',
    required this.category,
    this.color,
    this.season,
    this.isActive = true,
  });

  factory ClothingItem.fromJson(Map<String, dynamic> j) => ClothingItem(
    id: j['id']?.toString() ?? '',
    userId: j['userId']?.toString() ?? '',
    name: j['name'] ?? '',
    desc: j['description'] ?? '',
    category: j['category'] ?? 'tops',
    color: j['color'],
    season: j['season'],
    isActive: j['isActive'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'description': desc,
    'category': category,
    'color': color,
    'season': season,
    'isActive': isActive,
  };

  ClothingItem copyWith({String? name, String? desc}) => ClothingItem(
    id: id,
    userId: userId,
    name: name ?? this.name,
    desc: desc ?? this.desc,
    category: category,
    color: color,
    season: season,
    isActive: isActive,
  );
}

class Wardrobe {
  final List<ClothingItem> tops;
  final List<ClothingItem> bottoms;

  const Wardrobe({this.tops = const [], this.bottoms = const []});

  int get totalItems => tops.length + bottoms.length;
  List<ClothingItem> get all => [...tops, ...bottoms];
}