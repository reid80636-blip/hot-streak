/// Comment model for posts in the Feed
class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String? userAvatarUrl;
  final String content;
  final DateTime createdAt;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    required this.content,
    required this.createdAt,
  });

  /// Create from Supabase response (snake_case)
  factory PostComment.fromSupabase(Map<String, dynamic> json) {
    return PostComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String? ?? 'Anonymous',
      userAvatarUrl: json['user_avatar_url'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to Supabase format (snake_case) for insertion
  Map<String, dynamic> toSupabase() {
    return {
      'post_id': postId,
      'user_id': userId,
      'content': content,
    };
  }

  /// Create a copy with updated fields
  PostComment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? username,
    String? userAvatarUrl,
    String? content,
    DateTime? createdAt,
  }) {
    return PostComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'PostComment(id: $id, content: ${content.substring(0, content.length > 20 ? 20 : content.length)}...)';
  }
}
