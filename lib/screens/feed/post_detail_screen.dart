import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../models/post.dart';
import '../../models/post_comment.dart';
import '../../providers/feed_provider.dart';
import '../../providers/auth_provider.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().fetchComments(widget.post.id);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    context.read<FeedProvider>().clearComments();
    super.dispose();
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSubmitting) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await context.read<FeedProvider>().addComment(
            postId: widget.post.id,
            userId: auth.user!.id,
            content: content,
          );

      if (success && mounted) {
        _commentController.clear();
        _commentFocus.unfocus();
        HapticFeedback.lightImpact();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Post',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post header
                  _buildPostHeader(),

                  const SizedBox(height: AppSpacing.md),

                  // Linked badge
                  _buildLinkedBadge(),

                  const SizedBox(height: AppSpacing.lg),

                  // Post content
                  _buildPostContent(),

                  // Media
                  if (widget.post.hasMedia) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildMediaSection(),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Actions
                  _buildActions(),

                  const SizedBox(height: AppSpacing.xl),

                  // Divider
                  Container(
                    height: 1,
                    color: AppColors.borderSubtle,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Comments section
                  _buildCommentsSection(),
                ],
              ),
            ),
          ),

          // Comment input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return Row(
      children: [
        // Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accentCyan.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: widget.post.userAvatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: widget.post.userAvatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildAvatarPlaceholder(),
                    errorWidget: (_, __, ___) => _buildAvatarPlaceholder(),
                  )
                : _buildAvatarPlaceholder(),
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        // Username + Time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.post.username,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTimeAgo(widget.post.createdAt),
                style: TextStyle(
                  color: AppColors.textSecondaryOp,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      color: AppColors.glassBackground(0.6),
      child: Center(
        child: Text(
          widget.post.username.isNotEmpty
              ? widget.post.username[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: AppColors.accentCyan,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedBadge() {
    final isGame = widget.post.isGamePost;
    final icon = isGame ? Icons.sports : Icons.person;
    final label = widget.post.linkedDisplay;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppRadius.round),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.accentCyan,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.accentCyan,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Text(
      widget.post.content,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        height: 1.5,
      ),
    );
  }

  Widget _buildMediaSection() {
    // Simple media display for now
    return ClipRRect(
      borderRadius: BorderRadius.circular(DesignSystem.radiusLarge),
      child: Column(
        children: widget.post.mediaUrls.asMap().entries.map((entry) {
          final index = entry.key;
          final url = entry.value;
          final type = widget.post.mediaTypes[index];

          if (type == 'video') {
            return Container(
              margin: EdgeInsets.only(top: index > 0 ? AppSpacing.sm : 0),
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.glassBackground(0.6),
                borderRadius: BorderRadius.circular(DesignSystem.radiusLarge),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: AppColors.textPrimary,
                  size: 64,
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(top: index > 0 ? AppSpacing.sm : 0),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 200,
                color: AppColors.glassBackground(0.6),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 200,
                color: AppColors.glassBackground(0.6),
                child: Center(
                  child: Icon(Icons.broken_image, color: AppColors.textSubtle),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActions() {
    return Consumer<FeedProvider>(
      builder: (context, feedProvider, child) {
        // Get updated post from provider
        final post = feedProvider.posts.firstWhere(
          (p) => p.id == widget.post.id,
          orElse: () => widget.post,
        );
        final auth = context.read<AuthProvider>();

        return Row(
          children: [
            // Like button
            GestureDetector(
              onTap: () {
                if (!auth.isLoggedIn) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please log in to like posts')),
                  );
                  return;
                }
                HapticFeedback.lightImpact();
                feedProvider.toggleLike(post.id, auth.user!.id);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: post.isLikedByMe
                      ? AppColors.liveRed.withOpacity(0.2)
                      : AppColors.glassBackground(0.4),
                  borderRadius: BorderRadius.circular(AppRadius.round),
                  border: Border.all(
                    color: post.isLikedByMe
                        ? AppColors.liveRed.withOpacity(0.5)
                        : AppColors.borderSubtle,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: post.isLikedByMe
                          ? AppColors.liveRed
                          : AppColors.textSubtle,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${post.likesCount}',
                      style: TextStyle(
                        color: post.isLikedByMe
                            ? AppColors.liveRed
                            : AppColors.textSubtle,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // Comment count
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.glassBackground(0.4),
                borderRadius: BorderRadius.circular(AppRadius.round),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: AppColors.textSubtle,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${post.commentsCount}',
                    style: TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Share
            IconButton(
              icon: Icon(
                Icons.share_outlined,
                color: AppColors.textSubtle,
                size: 20,
              ),
              onPressed: () {
                // TODO: Share post
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentsSection() {
    return Consumer<FeedProvider>(
      builder: (context, feedProvider, child) {
        if (feedProvider.isLoadingComments) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(
                color: AppColors.accentCyan,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final comments = feedProvider.comments;

        if (comments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.textSubtle,
                    size: 32,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No comments yet',
                    style: TextStyle(
                      color: AppColors.textSecondaryOp,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Be the first to comment!',
                    style: TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comments (${comments.length})',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...comments.map((comment) => _CommentCard(
                  comment: comment,
                  onDelete: () async {
                    await feedProvider.deleteComment(
                      comment.id,
                      widget.post.id,
                    );
                  },
                  formatTimeAgo: _formatTimeAgo,
                )),
          ],
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassBackground(0.8),
        border: Border(
          top: BorderSide(color: AppColors.borderGlow),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: DesignSystem.glassDecoration(
                opacity: 0.4,
                borderOpacity: 0.2,
                radius: AppRadius.round,
              ),
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocus,
                maxLines: null,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: TextStyle(color: AppColors.textSubtle),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
                onSubmitted: (_) => _submitComment(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: _submitComment,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: _isSubmitting
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final PostComment comment;
  final VoidCallback onDelete;
  final String Function(DateTime) formatTimeAgo;

  const _CommentCard({
    required this.comment,
    required this.onDelete,
    required this.formatTimeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isOwnComment = auth.user?.id == comment.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: DesignSystem.glassDecoration(
        opacity: 0.3,
        borderOpacity: 0.15,
        radius: DesignSystem.radiusLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.glassBackground(0.6),
                  border: Border.all(
                    color: AppColors.borderSubtle,
                  ),
                ),
                child: comment.userAvatarUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: comment.userAvatarUrl!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          comment.username.isNotEmpty
                              ? comment.username[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: AppColors.accentCyan,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // Username
              Text(
                comment.username,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // Time
              Text(
                formatTimeAgo(comment.createdAt),
                style: TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 11,
                ),
              ),

              const Spacer(),

              // Delete button (only for own comments)
              if (isOwnComment)
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppColors.primaryDark,
                        title: const Text(
                          'Delete Comment?',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        content: Text(
                          'This action cannot be undone.',
                          style: TextStyle(color: AppColors.textSubtle),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onDelete();
                            },
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: AppColors.liveRed),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.textSubtle,
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Comment content
          Text(
            comment.content,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
