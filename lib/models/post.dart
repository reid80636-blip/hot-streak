/// Post model for the Feed feature
class Post {
  final String id;
  final String userId;
  final String username;
  final String? userAvatarUrl;
  final String content;
  final List<String> mediaUrls;
  final List<String> mediaTypes; // 'image' or 'video'

  // Required link - one of these must be set
  final String? gameId;
  final String? gameSportKey;
  final String? gameHomeTeam;
  final String? gameAwayTeam;
  final String? playerName;
  final String? playerTeam;

  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;

  final DateTime createdAt;
  final DateTime expiresAt;

  const Post({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    required this.content,
    this.mediaUrls = const [],
    this.mediaTypes = const [],
    this.gameId,
    this.gameSportKey,
    this.gameHomeTeam,
    this.gameAwayTeam,
    this.playerName,
    this.playerTeam,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByMe = false,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isGamePost => gameId != null;
  bool get isPlayerPost => playerName != null;

  String get linkedDisplay => isGamePost
      ? '$gameAwayTeam @ $gameHomeTeam'
      : '$playerName ($playerTeam)';

  String get linkedType => isGamePost ? 'game' : 'player';

  bool get hasMedia => mediaUrls.isNotEmpty;

  /// Create from Supabase response (snake_case)
  factory Post.fromSupabase(Map<String, dynamic> json, {bool isLikedByMe = false}) {
    return Post(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String? ?? 'Anonymous',
      userAvatarUrl: json['user_avatar_url'] as String?,
      content: json['content'] as String,
      mediaUrls: List<String>.from(json['media_urls'] ?? []),
      mediaTypes: List<String>.from(json['media_types'] ?? []),
      gameId: json['game_id'] as String?,
      gameSportKey: json['game_sport_key'] as String?,
      gameHomeTeam: json['game_home_team'] as String?,
      gameAwayTeam: json['game_away_team'] as String?,
      playerName: json['player_name'] as String?,
      playerTeam: json['player_team'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      isLikedByMe: isLikedByMe,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  /// Convert to Supabase format (snake_case) for insertion
  Map<String, dynamic> toSupabase() {
    return {
      'user_id': userId,
      'content': content,
      'media_urls': mediaUrls,
      'media_types': mediaTypes,
      'game_id': gameId,
      'game_sport_key': gameSportKey,
      'game_home_team': gameHomeTeam,
      'game_away_team': gameAwayTeam,
      'player_name': playerName,
      'player_team': playerTeam,
    };
  }

  /// Create a copy with updated fields
  Post copyWith({
    String? id,
    String? userId,
    String? username,
    String? userAvatarUrl,
    String? content,
    List<String>? mediaUrls,
    List<String>? mediaTypes,
    String? gameId,
    String? gameSportKey,
    String? gameHomeTeam,
    String? gameAwayTeam,
    String? playerName,
    String? playerTeam,
    int? likesCount,
    int? commentsCount,
    bool? isLikedByMe,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      gameId: gameId ?? this.gameId,
      gameSportKey: gameSportKey ?? this.gameSportKey,
      gameHomeTeam: gameHomeTeam ?? this.gameHomeTeam,
      gameAwayTeam: gameAwayTeam ?? this.gameAwayTeam,
      playerName: playerName ?? this.playerName,
      playerTeam: playerTeam ?? this.playerTeam,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  String toString() {
    return 'Post(id: $id, content: ${content.substring(0, content.length > 20 ? 20 : content.length)}..., likes: $likesCount)';
  }
}
