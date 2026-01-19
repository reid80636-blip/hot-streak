import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart';
import '../models/post_comment.dart';

/// Service for Feed-related Supabase operations
class FeedService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ============ POSTS ============

  /// Fetch posts with pagination
  /// Returns posts with user info joined
  static Future<List<Post>> fetchPosts({
    int limit = 20,
    int offset = 0,
    String? gameId,
    String? userId,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;

      // Build query with filters before order/range
      var query = _client.from('posts').select();

      // Apply filters
      if (gameId != null) {
        query = query.eq('game_id', gameId);
      }

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      // Apply ordering and pagination
      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response.isEmpty) {
        return [];
      }

      // Get unique user IDs to fetch profiles
      final userIds = response.map((p) => p['user_id'] as String).toSet().toList();

      // Fetch profiles for all users
      Map<String, Map<String, dynamic>> profilesMap = {};
      try {
        final profiles = await _client
            .from('profiles')
            .select('id, username, avatar_url')
            .inFilter('id', userIds);
        for (final p in profiles) {
          profilesMap[p['id']] = p;
        }
      } catch (e) {
        debugPrint('Could not fetch profiles: $e');
      }

      // Get likes for current user if logged in
      Set<String> likedPostIds = {};
      if (currentUserId != null) {
        try {
          final postIds = response.map((p) => p['id'] as String).toList();
          final likesResponse = await _client
              .from('post_likes')
              .select('post_id')
              .eq('user_id', currentUserId)
              .inFilter('post_id', postIds);

          likedPostIds = Set<String>.from(
            likesResponse.map((l) => l['post_id'] as String),
          );
        } catch (e) {
          debugPrint('Could not fetch likes: $e');
        }
      }

      return response.map((json) {
        final oderId = json['user_id'] as String;
        final profile = profilesMap[oderId];
        final flatJson = {
          ...json,
          'username': profile?['username'] ?? 'Anonymous',
          'user_avatar_url': profile?['avatar_url'],
        };
        return Post.fromSupabase(
          flatJson,
          isLikedByMe: likedPostIds.contains(json['id']),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      return [];
    }
  }

  /// Create a new post
  static Future<Post?> createPost({
    required String userId,
    required String content,
    List<String> mediaUrls = const [],
    List<String> mediaTypes = const [],
    String? gameId,
    String? gameSportKey,
    String? gameHomeTeam,
    String? gameAwayTeam,
    String? playerName,
    String? playerTeam,
  }) async {
    try {
      debugPrint('Creating post for user: $userId');
      debugPrint('Content: $content');
      debugPrint('Game ID: $gameId, Player: $playerName');

      // Insert without join first
      final response = await _client.from('posts').insert({
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
      }).select().single();

      debugPrint('Post created successfully: ${response['id']}');

      // Try to get username from profiles
      String username = 'Anonymous';
      String? avatarUrl;
      try {
        final profile = await _client
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', userId)
            .maybeSingle();
        if (profile != null) {
          username = profile['username'] ?? 'Anonymous';
          avatarUrl = profile['avatar_url'];
        }
      } catch (e) {
        debugPrint('Could not fetch profile: $e');
      }

      final flatJson = {
        ...response,
        'username': username,
        'user_avatar_url': avatarUrl,
      };

      return Post.fromSupabase(flatJson);
    } catch (e, stack) {
      debugPrint('Error creating post: $e');
      debugPrint('Stack trace: $stack');
      return null;
    }
  }

  /// Delete a post (only owner can delete)
  static Future<bool> deletePost(String postId) async {
    try {
      await _client.from('posts').delete().eq('id', postId);
      return true;
    } catch (e) {
      debugPrint('Error deleting post: $e');
      return false;
    }
  }

  // ============ LIKES ============

  /// Like a post
  static Future<bool> likePost(String postId, String userId) async {
    try {
      await _client.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });

      // Increment likes count
      try {
        await _client.rpc('increment_likes_count', params: {'post_id_param': postId});
      } catch (e) {
        // Fallback: update directly
        try {
          final count = await _client
              .from('post_likes')
              .select()
              .eq('post_id', postId)
              .count(CountOption.exact)
              .then((r) => r.count);
          await _client.from('posts').update({'likes_count': count}).eq('id', postId);
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('Error liking post: $e');
      return false;
    }
  }

  /// Unlike a post
  static Future<bool> unlikePost(String postId, String userId) async {
    try {
      await _client
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);

      // Decrement likes count
      try {
        await _client.rpc('decrement_likes_count', params: {'post_id_param': postId});
      } catch (e) {
        // Fallback: update directly
        try {
          final count = await _client
              .from('post_likes')
              .select()
              .eq('post_id', postId)
              .count(CountOption.exact)
              .then((r) => r.count);
          await _client.from('posts').update({'likes_count': count}).eq('id', postId);
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('Error unliking post: $e');
      return false;
    }
  }

  // ============ COMMENTS ============

  /// Fetch comments for a post
  static Future<List<PostComment>> fetchComments(String postId, {int limit = 50}) async {
    try {
      final response = await _client
          .from('post_comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true)
          .limit(limit);

      if (response.isEmpty) {
        return [];
      }

      // Get unique user IDs to fetch profiles
      final userIds = response.map((c) => c['user_id'] as String).toSet().toList();

      // Fetch profiles for all users
      Map<String, Map<String, dynamic>> profilesMap = {};
      try {
        final profiles = await _client
            .from('profiles')
            .select('id, username, avatar_url')
            .inFilter('id', userIds);
        for (final p in profiles) {
          profilesMap[p['id']] = p;
        }
      } catch (e) {
        debugPrint('Could not fetch profiles for comments: $e');
      }

      return response.map((json) {
        final oderId = json['user_id'] as String;
        final profile = profilesMap[oderId];
        final flatJson = {
          ...json,
          'username': profile?['username'] ?? 'Anonymous',
          'user_avatar_url': profile?['avatar_url'],
        };
        return PostComment.fromSupabase(flatJson);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      return [];
    }
  }

  /// Add a comment to a post
  static Future<PostComment?> addComment({
    required String postId,
    required String userId,
    required String content,
  }) async {
    try {
      final response = await _client.from('post_comments').insert({
        'post_id': postId,
        'user_id': userId,
        'content': content,
      }).select().single();

      // Try to increment comments count (may fail if RPC doesn't exist)
      try {
        await _client.rpc('increment_comments_count', params: {'post_id_param': postId});
      } catch (e) {
        // Fallback: update directly
        try {
          await _client.from('posts').update({
            'comments_count': await _client
                .from('post_comments')
                .select()
                .eq('post_id', postId)
                .count(CountOption.exact)
                .then((r) => r.count),
          }).eq('id', postId);
        } catch (_) {}
      }

      // Get username
      String username = 'Anonymous';
      String? avatarUrl;
      try {
        final profile = await _client
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', userId)
            .maybeSingle();
        if (profile != null) {
          username = profile['username'] ?? 'Anonymous';
          avatarUrl = profile['avatar_url'];
        }
      } catch (e) {
        debugPrint('Could not fetch profile: $e');
      }

      final flatJson = {
        ...response,
        'username': username,
        'user_avatar_url': avatarUrl,
      };

      return PostComment.fromSupabase(flatJson);
    } catch (e) {
      debugPrint('Error adding comment: $e');
      return null;
    }
  }

  /// Delete a comment (only owner can delete)
  static Future<bool> deleteComment(String commentId, String postId) async {
    try {
      await _client.from('post_comments').delete().eq('id', commentId);

      // Decrement comments count
      await _client.rpc('decrement_comments_count', params: {'post_id_param': postId});

      return true;
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      return false;
    }
  }

  // ============ MEDIA UPLOAD ============

  /// Upload media file to Supabase Storage
  /// Returns the public URL of the uploaded file
  static Future<String?> uploadMedia({
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$userId/$timestamp-$fileName';

      await _client.storage.from('feed-media').uploadBinary(
        path,
        fileBytes,
        fileOptions: FileOptions(contentType: mimeType),
      );

      final publicUrl = _client.storage.from('feed-media').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading media: $e');
      return null;
    }
  }

  /// Delete media file from storage
  static Future<bool> deleteMedia(String fileUrl) async {
    try {
      // Extract path from URL
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('feed-media');
      if (bucketIndex == -1) return false;

      final path = pathSegments.sublist(bucketIndex + 1).join('/');

      await _client.storage.from('feed-media').remove([path]);
      return true;
    } catch (e) {
      debugPrint('Error deleting media: $e');
      return false;
    }
  }
}
