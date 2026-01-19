import 'dart:convert';

enum CollectibleRarity {
  common,
  rare,
  epic,
  legendary,
}

enum CollectibleType {
  player,
  team,
  achievement,
  event,
}

class Collectible {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final CollectibleType type;
  final CollectibleRarity rarity;
  final String sportKey;
  final DateTime earnedAt;
  final double? xpBonus; // Percentage bonus for related predictions

  const Collectible({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.type,
    required this.rarity,
    required this.sportKey,
    required this.earnedAt,
    this.xpBonus,
  });

  String get rarityDisplay {
    switch (rarity) {
      case CollectibleRarity.common:
        return 'Common';
      case CollectibleRarity.rare:
        return 'Rare';
      case CollectibleRarity.epic:
        return 'Epic';
      case CollectibleRarity.legendary:
        return 'Legendary';
    }
  }

  int get rarityColor {
    switch (rarity) {
      case CollectibleRarity.common:
        return 0xFF8B949E; // Gray
      case CollectibleRarity.rare:
        return 0xFF4D65FF; // Blue
      case CollectibleRarity.epic:
        return 0xFF9B59B6; // Purple
      case CollectibleRarity.legendary:
        return 0xFFFFD700; // Gold
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'type': type.name,
      'rarity': rarity.name,
      'sportKey': sportKey,
      'earnedAt': earnedAt.toIso8601String(),
      'xpBonus': xpBonus,
    };
  }

  factory Collectible.fromJson(Map<String, dynamic> json) {
    return Collectible(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      type: CollectibleType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => CollectibleType.achievement,
      ),
      rarity: CollectibleRarity.values.firstWhere(
        (r) => r.name == json['rarity'],
        orElse: () => CollectibleRarity.common,
      ),
      sportKey: json['sportKey'] as String,
      earnedAt: DateTime.parse(json['earnedAt'] as String),
      xpBonus: (json['xpBonus'] as num?)?.toDouble(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Collectible.fromJsonString(String source) =>
      Collectible.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

// Sample collectibles for demo
class SampleCollectibles {
  static List<Collectible> get all => [
    Collectible(
      id: 'col_1',
      name: 'Premier League Expert',
      description: 'Won 10 EPL predictions in a row',
      imageUrl: 'https://example.com/epl_badge.png',
      type: CollectibleType.achievement,
      rarity: CollectibleRarity.rare,
      sportKey: 'soccer_epl',
      earnedAt: DateTime.now().subtract(const Duration(days: 5)),
      xpBonus: 0.10,
    ),
    Collectible(
      id: 'col_2',
      name: 'Hot Streak Master',
      description: 'Won 5 predictions in a single day',
      imageUrl: 'https://example.com/hotstreak_badge.png',
      type: CollectibleType.achievement,
      rarity: CollectibleRarity.epic,
      sportKey: 'all',
      earnedAt: DateTime.now().subtract(const Duration(days: 10)),
      xpBonus: 0.15,
    ),
    Collectible(
      id: 'col_3',
      name: 'NFL Sunday Champion',
      description: 'Finished in top 5% on NFL Sunday',
      imageUrl: 'https://example.com/nfl_badge.png',
      type: CollectibleType.event,
      rarity: CollectibleRarity.legendary,
      sportKey: 'americanfootball_nfl',
      earnedAt: DateTime.now().subtract(const Duration(days: 2)),
      xpBonus: 0.25,
    ),
  ];
}
