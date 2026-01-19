import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../models/post.dart';
import '../../providers/feed_provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/feed/post_detail_screen.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
  });

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

  void _navigateToDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _navigateToDetail(context),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: DesignSystem.glassDecoration(
          opacity: 0.5,
          borderOpacity: 0.25,
          radius: DesignSystem.radiusXxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar + Username + Time
            _buildHeader(),

            // Linked game/player badge
            _buildLinkedBadge(),

            // Post content
            _buildContent(),

            // Media (if any)
            if (post.hasMedia) _buildMediaSection(),

            // Action buttons: Like, Comment
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentCyan.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyanGlow,
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: post.userAvatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: post.userAvatarUrl!,
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
                  post.username,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimeAgo(post.createdAt),
                  style: TextStyle(
                    color: AppColors.textSecondaryOp,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // More options (future: delete, report)
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: AppColors.textSubtle,
              size: 20,
            ),
            onPressed: () {
              // TODO: Show options menu
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      color: AppColors.glassBackground(0.6),
      child: Center(
        child: Text(
          post.username.isNotEmpty ? post.username[0].toUpperCase() : '?',
          style: TextStyle(
            color: AppColors.accentCyan,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedBadge() {
    final isGame = post.isGamePost;
    final icon = isGame ? Icons.sports : Icons.person;
    final label = post.linkedDisplay;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
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
              size: 14,
              color: AppColors.accentCyan,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        post.content,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    // Show media grid/carousel
    final mediaCount = post.mediaUrls.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignSystem.radiusLarge),
        child: mediaCount == 1
            ? _buildSingleMedia(post.mediaUrls[0], post.mediaTypes[0])
            : _buildMediaGrid(),
      ),
    );
  }

  Widget _buildSingleMedia(String url, String type) {
    if (type == 'video') {
      return _buildVideoThumbnail(url);
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildMediaPlaceholder(),
        errorWidget: (_, __, ___) => _buildMediaPlaceholder(),
      ),
    );
  }

  Widget _buildMediaGrid() {
    final urls = post.mediaUrls;
    final types = post.mediaTypes;
    final count = urls.length;

    if (count == 2) {
      return Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: _buildGridItem(urls[0], types[0]),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: _buildGridItem(urls[1], types[1]),
            ),
          ),
        ],
      );
    }

    if (count == 3) {
      return Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 0.75,
              child: _buildGridItem(urls[0], types[0]),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildGridItem(urls[1], types[1]),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: _buildGridItem(urls[2], types[2]),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 4+ items
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildGridItem(urls[0], types[0]),
          _buildGridItem(urls[1], types[1]),
          _buildGridItem(urls[2], types[2]),
          if (count > 4)
            _buildMoreOverlay(urls[3], types[3], count - 4)
          else
            _buildGridItem(urls[3], types[3]),
        ],
      ),
    );
  }

  Widget _buildGridItem(String url, String type) {
    if (type == 'video') {
      return _buildVideoThumbnail(url);
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => _buildMediaPlaceholder(),
      errorWidget: (_, __, ___) => _buildMediaPlaceholder(),
    );
  }

  Widget _buildVideoThumbnail(String url) {
    return Container(
      color: AppColors.glassBackground(0.8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // TODO: Use video_thumbnail package for actual thumbnail
          Container(
            color: AppColors.primaryDark,
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.glassBackground(0.8),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderGlow),
            ),
            child: const Icon(
              Icons.play_arrow,
              color: AppColors.textPrimary,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreOverlay(String url, String type, int moreCount) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildGridItem(url, type),
        Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: Text(
              '+$moreCount',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaPlaceholder() {
    return Container(
      color: AppColors.glassBackground(0.6),
      child: Center(
        child: Icon(
          Icons.image,
          color: AppColors.textSubtle,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final feedProvider = context.read<FeedProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          // Like button
          _ActionButton(
            icon: post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
            label: post.likesCount > 0 ? '${post.likesCount}' : 'Like',
            isActive: post.isLikedByMe,
            activeColor: AppColors.liveRed,
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
          ),

          const SizedBox(width: AppSpacing.lg),

          // Comment button
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: post.commentsCount > 0 ? '${post.commentsCount}' : 'Comment',
            onTap: () {
              HapticFeedback.lightImpact();
              _navigateToDetail(context);
            },
          ),

          const Spacer(),

          // Share button
          _ActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () {
              // TODO: Share post
              HapticFeedback.lightImpact();
            },
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? (activeColor ?? AppColors.accentCyan)
        : AppColors.textSubtle;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
