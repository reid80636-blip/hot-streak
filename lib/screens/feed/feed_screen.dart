import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../providers/feed_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/feed/post_card.dart';
import 'create_post_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().fetchPosts();
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<FeedProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Filter chips
            _buildFilterChips(),

            // Feed list
            Expanded(
              child: Consumer<FeedProvider>(
                builder: (context, feedProvider, child) {
                  if (feedProvider.isLoading && feedProvider.posts.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentCyan,
                      ),
                    );
                  }

                  if (feedProvider.posts.isEmpty) {
                    return _buildEmptyState();
                  }

                  return RefreshIndicator(
                    onRefresh: () => feedProvider.fetchPosts(refresh: true),
                    color: AppColors.accentCyan,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: feedProvider.posts.length +
                          (feedProvider.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == feedProvider.posts.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                color: AppColors.accentCyan,
                              ),
                            ),
                          );
                        }

                        final post = feedProvider.posts[index];
                        return PostCard(post: post);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildCreatePostFAB(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Text(
            'Feed',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: AppColors.glassBackground(0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderGlow),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              color: AppColors.accentCyan,
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<FeedProvider>().fetchPosts(refresh: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Consumer<FeedProvider>(
      builder: (context, feedProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                isSelected: feedProvider.filter == FeedFilter.all,
                onTap: () => feedProvider.setFilter(FeedFilter.all),
              ),
              const SizedBox(width: AppSpacing.sm),
              _FilterChip(
                label: 'Trending',
                isSelected: feedProvider.filter == FeedFilter.trending,
                onTap: () => feedProvider.setFilter(FeedFilter.trending),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.glassBackground(0.4),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderGlow),
              ),
              child: Icon(
                Icons.dynamic_feed_outlined,
                size: 48,
                color: AppColors.textSubtle,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'No posts yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Be the first to share something about a game or player!',
              style: TextStyle(
                color: AppColors.textSecondaryOp,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () => _navigateToCreatePost(),
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePostFAB() {
    return FloatingActionButton(
      onPressed: () => _navigateToCreatePost(),
      backgroundColor: AppColors.accent,
      child: Icon(Icons.add, color: Colors.white),
    );
  }

  void _navigateToCreatePost() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create a post')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreatePostScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentCyan.withOpacity(0.2)
              : AppColors.glassBackground(0.4),
          borderRadius: BorderRadius.circular(AppRadius.round),
          border: Border.all(
            color: isSelected ? AppColors.accentCyan : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.accentCyan : AppColors.textSecondaryOp,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
