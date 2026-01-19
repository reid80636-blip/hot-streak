import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../models/game.dart';
import '../../providers/feed_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/games_provider.dart';
import '../../widgets/feed/game_picker_sheet.dart';
import '../../widgets/feed/player_picker_sheet.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // Link selection
  bool _isGamePost = true;
  Game? _selectedGame;
  String? _selectedPlayerName;
  String? _selectedPlayerTeam;

  // Media
  final List<XFile> _selectedMedia = [];
  final List<String> _mediaTypes = [];

  bool _isPosting = false;

  bool get _canPost {
    final hasContent = _contentController.text.trim().isNotEmpty;
    final hasLink = _isGamePost ? _selectedGame != null : _selectedPlayerName != null;
    return hasContent && hasLink && !_isPosting;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MediaTypeSheet(),
    );

    if (result == null) return;

    try {
      if (result == 'photo') {
        final image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (image != null) {
          setState(() {
            _selectedMedia.add(image);
            _mediaTypes.add('image');
          });
        }
      } else if (result == 'video') {
        final video = await _imagePicker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 2),
        );
        if (video != null) {
          setState(() {
            _selectedMedia.add(video);
            _mediaTypes.add('video');
          });
        }
      } else if (result == 'camera') {
        final image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (image != null) {
          setState(() {
            _selectedMedia.add(image);
            _mediaTypes.add('image');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick media: $e')),
        );
      }
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
      _mediaTypes.removeAt(index);
    });
  }

  Future<void> _selectGame() async {
    final game = await showModalBottomSheet<Game>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GamePickerSheet(),
    );

    if (game != null) {
      setState(() {
        _selectedGame = game;
        _isGamePost = true;
      });
    }
  }

  Future<void> _selectPlayer() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlayerPickerSheet(),
    );

    if (result != null) {
      setState(() {
        _selectedPlayerName = result['name'];
        _selectedPlayerTeam = result['team'];
        _isGamePost = false;
      });
    }
  }

  Future<void> _createPost() async {
    if (!_canPost) return;

    final auth = context.read<AuthProvider>();

    // Check if user is logged in
    if (!auth.isLoggedIn || auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create a post')),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final feedProvider = context.read<FeedProvider>();

      // Upload media first
      final uploadedUrls = <String>[];
      final uploadedTypes = <String>[];

      for (var i = 0; i < _selectedMedia.length; i++) {
        final file = _selectedMedia[i];
        final bytes = await file.readAsBytes();
        final mimeType = _mediaTypes[i] == 'video' ? 'video/mp4' : 'image/jpeg';

        final url = await feedProvider.uploadMedia(
          fileBytes: bytes,
          fileName: file.name,
          mimeType: mimeType,
        );

        if (url != null) {
          uploadedUrls.add(url);
          uploadedTypes.add(_mediaTypes[i]);
        }
      }

      // Create post
      final success = await feedProvider.createPost(
        userId: auth.user!.id,
        content: _contentController.text.trim(),
        mediaUrls: uploadedUrls,
        mediaTypes: uploadedTypes,
        gameId: _isGamePost ? _selectedGame?.id : null,
        gameSportKey: _isGamePost ? _selectedGame?.sportKey : null,
        gameHomeTeam: _isGamePost ? _selectedGame?.homeTeam.name : null,
        gameAwayTeam: _isGamePost ? _selectedGame?.awayTeam.name : null,
        playerName: !_isGamePost ? _selectedPlayerName : null,
        playerTeam: !_isGamePost ? _selectedPlayerTeam : null,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created!')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create post. Check if tables exist in Supabase.')),
        );
      }
    } catch (e) {
      debugPrint('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
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
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create Post',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: TextButton(
              onPressed: _canPost ? _createPost : null,
              style: TextButton.styleFrom(
                backgroundColor: _canPost
                    ? AppColors.accent
                    : AppColors.glassBackground(0.3),
                foregroundColor: _canPost
                    ? Colors.white
                    : AppColors.textSubtle,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.round),
                ),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Post'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Link selector (Game or Player)
              _buildLinkSelector(),

              const SizedBox(height: AppSpacing.xl),

              // Selected link display
              if (_selectedGame != null || _selectedPlayerName != null)
                _buildSelectedLink(),

              const SizedBox(height: AppSpacing.lg),

              // Content input
              _buildContentInput(),

              const SizedBox(height: AppSpacing.lg),

              // Media preview
              if (_selectedMedia.isNotEmpty) _buildMediaPreview(),

              // Add media button
              _buildAddMediaButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Link to:',
          style: TextStyle(
            color: AppColors.textSecondaryOp,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _selectGame,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: _isGamePost && _selectedGame != null
                        ? AppColors.accent.withOpacity(0.2)
                        : AppColors.glassBackground(0.5),
                    borderRadius: BorderRadius.circular(DesignSystem.radiusLarge),
                    border: Border.all(
                      color: _isGamePost && _selectedGame != null
                          ? AppColors.accent
                          : AppColors.borderSubtle,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.sports,
                        color: _isGamePost && _selectedGame != null
                            ? AppColors.accentCyan
                            : AppColors.textSubtle,
                        size: 28,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Game',
                        style: TextStyle(
                          color: _isGamePost && _selectedGame != null
                              ? AppColors.textPrimary
                              : AppColors.textSubtle,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: GestureDetector(
                onTap: _selectPlayer,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: !_isGamePost && _selectedPlayerName != null
                        ? AppColors.accent.withOpacity(0.2)
                        : AppColors.glassBackground(0.5),
                    borderRadius: BorderRadius.circular(DesignSystem.radiusLarge),
                    border: Border.all(
                      color: !_isGamePost && _selectedPlayerName != null
                          ? AppColors.accent
                          : AppColors.borderSubtle,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person,
                        color: !_isGamePost && _selectedPlayerName != null
                            ? AppColors.accentCyan
                            : AppColors.textSubtle,
                        size: 28,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Player',
                        style: TextStyle(
                          color: !_isGamePost && _selectedPlayerName != null
                              ? AppColors.textPrimary
                              : AppColors.textSubtle,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Required: Select a game or player to post about',
          style: TextStyle(
            color: AppColors.textSubtle,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedLink() {
    final isGame = _isGamePost && _selectedGame != null;
    final label = isGame
        ? '${_selectedGame!.awayTeam.name} @ ${_selectedGame!.homeTeam.name}'
        : '$_selectedPlayerName ($_selectedPlayerTeam)';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppRadius.round),
        border: Border.all(color: AppColors.accent.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGame ? Icons.sports : Icons.person,
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
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedGame = null;
                _selectedPlayerName = null;
                _selectedPlayerTeam = null;
              });
            },
            child: Icon(
              Icons.close,
              size: 16,
              color: AppColors.textSubtle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentInput() {
    return Container(
      decoration: DesignSystem.glassDecoration(
        opacity: 0.4,
        borderOpacity: 0.2,
        radius: DesignSystem.radiusLarge,
      ),
      child: TextField(
        controller: _contentController,
        maxLines: 6,
        maxLength: 500,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: "What's on your mind about this ${_isGamePost ? 'game' : 'player'}?",
          hintStyle: TextStyle(
            color: AppColors.textSubtle,
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(AppSpacing.lg),
          counterStyle: TextStyle(
            color: AppColors.textSubtle,
            fontSize: 11,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Media',
          style: TextStyle(
            color: AppColors.textSecondaryOp,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedMedia.length,
            itemBuilder: (context, index) {
              return _MediaPreviewItem(
                file: _selectedMedia[index],
                type: _mediaTypes[index],
                onRemove: () => _removeMedia(index),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildAddMediaButton() {
    if (_selectedMedia.length >= 4) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _pickMedia,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.glassBackground(0.3),
          borderRadius: BorderRadius.circular(DesignSystem.radiusLarge),
          border: Border.all(
            color: AppColors.borderSubtle,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: AppColors.textSubtle,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Add Photo or Video',
              style: TextStyle(
                color: AppColors.textSubtle,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreviewItem extends StatelessWidget {
  final XFile file;
  final String type;
  final VoidCallback onRemove;

  const _MediaPreviewItem({
    required this.file,
    required this.type,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.glassBackground(0.5),
        borderRadius: BorderRadius.circular(DesignSystem.radiusMedium),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignSystem.radiusMedium),
            child: type == 'video'
                ? Center(
                    child: Icon(
                      Icons.videocam,
                      color: AppColors.textSubtle,
                      size: 32,
                    ),
                  )
                : FutureBuilder<Uint8List>(
                    future: file.readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                        );
                      }
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTypeSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesignSystem.radiusXxl),
        ),
        border: Border.all(color: AppColors.borderGlow),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesignSystem.handleBar(),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Add Media',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _MediaOption(
            icon: Icons.photo_library,
            label: 'Choose Photo',
            onTap: () => Navigator.of(context).pop('photo'),
          ),
          const SizedBox(height: AppSpacing.md),
          _MediaOption(
            icon: Icons.video_library,
            label: 'Choose Video',
            onTap: () => Navigator.of(context).pop('video'),
          ),
          const SizedBox(height: AppSpacing.md),
          _MediaOption(
            icon: Icons.camera_alt,
            label: 'Take Photo',
            onTap: () => Navigator.of(context).pop('camera'),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _MediaOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MediaOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: DesignSystem.glassDecoration(
          opacity: 0.4,
          borderOpacity: 0.2,
          radius: DesignSystem.radiusLarge,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.accentCyan,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.lg),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
