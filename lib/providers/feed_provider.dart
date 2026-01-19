import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../models/post_comment.dart';
import '../services/feed_service.dart';

enum FeedFilter { all, trending }

class FeedProvider extends ChangeNotifier {
  List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  FeedFilter _filter = FeedFilter.all;

  // Comments for current post detail view
  List<PostComment> _comments = [];
  bool _isLoadingComments = false;

  // Getters
  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  FeedFilter get filter => _filter;
  List<PostComment> get comments => _comments;
  bool get isLoadingComments => _isLoadingComments;

  static const int _pageSize = 20;

  /// Fetch initial posts
  Future<void> fetchPosts({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    if (refresh) {
      _posts = [];
      _hasMore = true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newPosts = await FeedService.fetchPosts(
        limit: _pageSize,
        offset: 0,
      );

      _posts = newPosts;
      _hasMore = newPosts.length >= _pageSize;
    } catch (e) {
      _error = 'Failed to load feed';
      debugPrint('Error fetching posts: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load more posts (pagination)
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final newPosts = await FeedService.fetchPosts(
        limit: _pageSize,
        offset: _posts.length,
      );

      _posts.addAll(newPosts);
      _hasMore = newPosts.length >= _pageSize;
    } catch (e) {
      debugPrint('Error loading more posts: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Set feed filter
  void setFilter(FeedFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    fetchPosts(refresh: true);
  }

  /// Create a new post
  Future<bool> createPost({
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
      final post = await FeedService.createPost(
        userId: userId,
        content: content,
        mediaUrls: mediaUrls,
        mediaTypes: mediaTypes,
        gameId: gameId,
        gameSportKey: gameSportKey,
        gameHomeTeam: gameHomeTeam,
        gameAwayTeam: gameAwayTeam,
        playerName: playerName,
        playerTeam: playerTeam,
      );

      if (post != null) {
        // Add to beginning of list
        _posts.insert(0, post);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error creating post: $e');
      return false;
    }
  }

  /// Delete a post
  Future<bool> deletePost(String postId) async {
    try {
      final success = await FeedService.deletePost(postId);
      if (success) {
        _posts.removeWhere((p) => p.id == postId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting post: $e');
      return false;
    }
  }

  /// Like a post (optimistic update)
  Future<void> likePost(String postId, String userId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    // Optimistic update
    final post = _posts[index];
    _posts[index] = post.copyWith(
      likesCount: post.likesCount + 1,
      isLikedByMe: true,
    );
    notifyListeners();

    // Make API call
    final success = await FeedService.likePost(postId, userId);
    if (!success) {
      // Revert on failure
      _posts[index] = post;
      notifyListeners();
    }
  }

  /// Unlike a post (optimistic update)
  Future<void> unlikePost(String postId, String userId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    // Optimistic update
    final post = _posts[index];
    _posts[index] = post.copyWith(
      likesCount: post.likesCount - 1,
      isLikedByMe: false,
    );
    notifyListeners();

    // Make API call
    final success = await FeedService.unlikePost(postId, userId);
    if (!success) {
      // Revert on failure
      _posts[index] = post;
      notifyListeners();
    }
  }

  /// Toggle like on a post
  Future<void> toggleLike(String postId, String userId) async {
    final post = _posts.firstWhere((p) => p.id == postId, orElse: () => throw Exception('Post not found'));
    if (post.isLikedByMe) {
      await unlikePost(postId, userId);
    } else {
      await likePost(postId, userId);
    }
  }

  // ============ COMMENTS ============

  /// Fetch comments for a post
  Future<void> fetchComments(String postId) async {
    _isLoadingComments = true;
    _comments = [];
    notifyListeners();

    try {
      _comments = await FeedService.fetchComments(postId);
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    }

    _isLoadingComments = false;
    notifyListeners();
  }

  /// Add a comment to a post
  Future<bool> addComment({
    required String postId,
    required String userId,
    required String content,
  }) async {
    try {
      final comment = await FeedService.addComment(
        postId: postId,
        userId: userId,
        content: content,
      );

      if (comment != null) {
        _comments.add(comment);

        // Update comments count on the post
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          final post = _posts[index];
          _posts[index] = post.copyWith(commentsCount: post.commentsCount + 1);
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding comment: $e');
      return false;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(String commentId, String postId) async {
    try {
      final success = await FeedService.deleteComment(commentId, postId);
      if (success) {
        _comments.removeWhere((c) => c.id == commentId);

        // Update comments count on the post
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          final post = _posts[index];
          _posts[index] = post.copyWith(commentsCount: post.commentsCount - 1);
        }

        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      return false;
    }
  }

  /// Clear comments when leaving post detail
  void clearComments() {
    _comments = [];
    notifyListeners();
  }

  // ============ MEDIA UPLOAD ============

  /// Upload media and return URL
  Future<String?> uploadMedia({
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
  }) async {
    return FeedService.uploadMedia(
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }
}
