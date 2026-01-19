import 'dart:convert';

class User {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final int coins;
  final int xp;
  final int level;
  final int totalPredictions;
  final int wins;
  final int losses;
  final DateTime createdAt;
  final DateTime? lastDailyBonus;
  final List<String> badges;
  final List<String> collectibleIds;
  final List<String> favoriteTeams;
  final List<String> favoriteSports;
  final bool onboardingComplete;
  final bool notificationsEnabled;
  final int defaultStake;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.coins = 10000,
    this.xp = 0,
    this.level = 1,
    this.totalPredictions = 0,
    this.wins = 0,
    this.losses = 0,
    DateTime? createdAt,
    this.lastDailyBonus,
    this.badges = const [],
    this.collectibleIds = const [],
    this.favoriteTeams = const [],
    this.favoriteSports = const [],
    this.onboardingComplete = false,
    this.notificationsEnabled = true,
    this.defaultStake = 100,
  }) : createdAt = createdAt ?? DateTime.now();

  double get winRate {
    if (totalPredictions == 0) return 0;
    return (wins / totalPredictions) * 100;
  }

  int get xpForNextLevel => level * 1000;

  double get levelProgress => xp / xpForNextLevel;

  bool get canClaimDailyBonus {
    if (lastDailyBonus == null) return true;
    final now = DateTime.now();
    final lastBonus = lastDailyBonus!;
    return now.year != lastBonus.year ||
        now.month != lastBonus.month ||
        now.day != lastBonus.day;
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    int? coins,
    int? xp,
    int? level,
    int? totalPredictions,
    int? wins,
    int? losses,
    DateTime? createdAt,
    DateTime? lastDailyBonus,
    List<String>? badges,
    List<String>? collectibleIds,
    List<String>? favoriteTeams,
    List<String>? favoriteSports,
    bool? onboardingComplete,
    bool? notificationsEnabled,
    int? defaultStake,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coins: coins ?? this.coins,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      totalPredictions: totalPredictions ?? this.totalPredictions,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      createdAt: createdAt ?? this.createdAt,
      lastDailyBonus: lastDailyBonus ?? this.lastDailyBonus,
      badges: badges ?? this.badges,
      collectibleIds: collectibleIds ?? this.collectibleIds,
      favoriteTeams: favoriteTeams ?? this.favoriteTeams,
      favoriteSports: favoriteSports ?? this.favoriteSports,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      defaultStake: defaultStake ?? this.defaultStake,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatarUrl': avatarUrl,
      'coins': coins,
      'xp': xp,
      'level': level,
      'totalPredictions': totalPredictions,
      'wins': wins,
      'losses': losses,
      'createdAt': createdAt.toIso8601String(),
      'lastDailyBonus': lastDailyBonus?.toIso8601String(),
      'badges': badges,
      'collectibleIds': collectibleIds,
      'favoriteTeams': favoriteTeams,
      'favoriteSports': favoriteSports,
      'onboardingComplete': onboardingComplete,
      'notificationsEnabled': notificationsEnabled,
      'defaultStake': defaultStake,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      coins: json['coins'] as int? ?? 10000,
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      totalPredictions: json['totalPredictions'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastDailyBonus: json['lastDailyBonus'] != null
          ? DateTime.parse(json['lastDailyBonus'] as String)
          : null,
      badges: (json['badges'] as List<dynamic>?)?.cast<String>() ?? [],
      collectibleIds:
          (json['collectibleIds'] as List<dynamic>?)?.cast<String>() ?? [],
      favoriteTeams:
          (json['favoriteTeams'] as List<dynamic>?)?.cast<String>() ?? [],
      favoriteSports:
          (json['favoriteSports'] as List<dynamic>?)?.cast<String>() ?? [],
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      defaultStake: json['defaultStake'] as int? ?? 100,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory User.fromJsonString(String source) =>
      User.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
