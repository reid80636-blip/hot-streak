import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../config/theme.dart';
import '../../services/espn_scores_service.dart';
import '../../widgets/common/team_logo.dart';

class LiveGameDetailScreen extends StatefulWidget {
  final String eventId;
  final String sportKey;
  final String homeTeam;
  final String awayTeam;
  final String? homeLogo;
  final String? awayLogo;
  final int? homeScore;
  final int? awayScore;
  final String? gameTime;
  final bool isLive;
  final int initialTabIndex; // 0 = Summary, 1 = Box Score, 2 = Plays

  const LiveGameDetailScreen({
    super.key,
    required this.eventId,
    required this.sportKey,
    required this.homeTeam,
    required this.awayTeam,
    this.homeLogo,
    this.awayLogo,
    this.homeScore,
    this.awayScore,
    this.gameTime,
    this.isLive = false,
    this.initialTabIndex = 0,
  });

  @override
  State<LiveGameDetailScreen> createState() => _LiveGameDetailScreenState();
}

class _LiveGameDetailScreenState extends State<LiveGameDetailScreen>
    with SingleTickerProviderStateMixin {
  final EspnScoresService _espnService = EspnScoresService();
  GameDetails? _gameDetails;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  // Box score team selector (0 = away, 1 = home)
  int _selectedBoxScoreTeam = 0;

  // Live score tracking - these update in real-time
  late int _currentHomeScore;
  late int _currentAwayScore;
  String? _currentGameTime;

  // Live play tracking
  Timer? _liveRefreshTimer;
  Set<String> _seenPlayIds = {};

  // Inline scoring animation state
  int? _scoringAnimationPoints;
  bool _isHomeTeamScoring = false;
  bool _showScoreAnimation = false;

  // Team colors
  Color _homeColor = AppColors.accent;
  Color _awayColor = const Color(0xFF3B82F6); // Blue

  @override
  void initState() {
    super.initState();
    // Initialize live scores from widget
    _currentHomeScore = widget.homeScore ?? 0;
    _currentAwayScore = widget.awayScore ?? 0;
    _currentGameTime = widget.gameTime;

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _fetchGameDetails();

    // Always start auto-refresh - game status can change and we want real-time scores
    _startLiveRefresh();
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startLiveRefresh() {
    // Refresh every 5 seconds for live games
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshGameData();
    });
  }

  Future<void> _refreshGameData() async {
    // Always refresh - don't skip based on isLive since game status might have changed
    try {
      final details = await _espnService.fetchGameDetails(widget.eventId, widget.sportKey);
      if (details != null && mounted) {
        // Get new scores - prioritize team data over scoring plays
        int newHomeScore = _currentHomeScore;
        int newAwayScore = _currentAwayScore;
        String? newGameTime = _currentGameTime;

        // First try to get scores directly from team data (most reliable)
        if (details.homeTeam?.score != null) {
          newHomeScore = details.homeTeam!.score!;
        }
        if (details.awayTeam?.score != null) {
          newAwayScore = details.awayTeam!.score!;
        }

        // Fallback: Use most recent scoring play if team data is missing
        if (details.homeTeam?.score == null && details.scoringPlays.isNotEmpty) {
          // Get the LAST scoring play (most recent) - not the first
          final latestPlay = details.scoringPlays.last;
          newHomeScore = latestPlay.homeScore;
          newAwayScore = latestPlay.awayScore;
        }

        // Update game time from most recent scoring play if available
        if (details.scoringPlays.isNotEmpty) {
          final latestPlay = details.scoringPlays.last;
          newGameTime = 'Q${latestPlay.period} ${latestPlay.clock}';
        }

        // Check for score changes
        final homeScored = newHomeScore > _currentHomeScore;
        final awayScored = newAwayScore > _currentAwayScore;
        final homePoints = newHomeScore - _currentHomeScore;
        final awayPoints = newAwayScore - _currentAwayScore;

        // Check for new scoring plays for seen tracking
        for (final play in details.scoringPlays) {
          final playId = '${play.period}_${play.clock}_${play.homeScore}_${play.awayScore}';
          _seenPlayIds.add(playId);
        }

        setState(() {
          // Update all game details
          _gameDetails = details;

          // Update current scores and time
          _currentHomeScore = newHomeScore;
          _currentAwayScore = newAwayScore;
          _currentGameTime = newGameTime;

          // Trigger inline scoring animation if someone scored
          if (homeScored || awayScored) {
            _isHomeTeamScoring = homeScored;
            _scoringAnimationPoints = homeScored ? homePoints : awayPoints;
            _showScoreAnimation = true;
          }
        });

        // Hide inline animation after 2 seconds
        if (homeScored || awayScored) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _showScoreAnimation = false;
                _scoringAnimationPoints = null;
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing game data: $e');
    }
  }

  Future<void> _fetchGameDetails() async {
    setState(() {
      _isLoading = true;
      _seenPlayIds.clear();
      _error = null;
    });

    try {
      final details = await _espnService.fetchGameDetails(
        widget.eventId.replaceFirst('espn_', ''),
        widget.sportKey,
      );

      if (mounted) {
        setState(() {
          _gameDetails = details;
          _isLoading = false;

          // Initialize seen plays for live refresh tracking
          if (details != null) {
            for (final play in details.scoringPlays) {
              final playId = '${play.period}_${play.clock}_${play.homeScore}_${play.awayScore}';
              _seenPlayIds.add(playId);
            }

            // Update scores - prioritize team data (most reliable)
            if (details.homeTeam?.score != null) {
              _currentHomeScore = details.homeTeam!.score!;
            }
            if (details.awayTeam?.score != null) {
              _currentAwayScore = details.awayTeam!.score!;
            }

            // Fallback: Use most recent scoring play if team data missing
            if (details.homeTeam?.score == null && details.scoringPlays.isNotEmpty) {
              final latestPlay = details.scoringPlays.last;
              _currentHomeScore = latestPlay.homeScore;
              _currentAwayScore = latestPlay.awayScore;
            }

            // Update game time from most recent scoring play
            if (details.scoringPlays.isNotEmpty) {
              final latestPlay = details.scoringPlays.last;
              _currentGameTime = 'Q${latestPlay.period} ${latestPlay.clock}';
            }
          }

          // Set team colors if available
          if (details?.homeTeam?.color != null) {
            _homeColor = _parseColor(details!.homeTeam!.color!);
          }
          if (details?.awayTeam?.color != null) {
            _awayColor = _parseColor(details!.awayTeam!.color!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load game details';
          _isLoading = false;
        });
      }
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildHeader(),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabController: _tabController,
              homeColor: _homeColor,
            ),
          ),
        ],
        body: _isLoading
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSummaryTab(),
                      _buildBoxScoreTab(),
                      _buildPlaysTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF0D0D0F),
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (widget.isLive)
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: _buildLiveBadge(),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _awayColor.withOpacity(0.3),
                const Color(0xFF0D0D0F),
                _homeColor.withOpacity(0.3),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
              child: _buildScoreHeader(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF416C).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 800.ms).then().fadeOut(duration: 800.ms),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreHeader() {
    return Row(
      children: [
        // Away team
        Expanded(
          child: _buildTeamColumn(
            name: widget.awayTeam,
            logo: widget.awayLogo,
            score: _currentAwayScore,
            record: _gameDetails?.awayTeam?.record,
            color: _awayColor,
            isWinning: _currentAwayScore > _currentHomeScore,
          ),
        ),

        // Score and status
        _buildScoreCenter(),

        // Home team
        Expanded(
          child: _buildTeamColumn(
            name: widget.homeTeam,
            logo: widget.homeLogo,
            score: _currentHomeScore,
            record: _gameDetails?.homeTeam?.record,
            color: _homeColor,
            isWinning: _currentHomeScore > _currentAwayScore,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamColumn({
    required String name,
    String? logo,
    int? score,
    String? record,
    required Color color,
    bool isWinning = false,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: isWinning ? Border.all(color: color, width: 3) : null,
          ),
          child: TeamLogo(
            logoUrl: logo,
            teamName: name,
            size: 56,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _getShortName(name),
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (record != null)
          Text(
            record,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  String _getShortName(String name) {
    final parts = name.split(' ');
    if (parts.length > 2) {
      return parts.last;
    }
    return name;
  }

  Widget _buildScoreCenter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Away score with inline animation
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    '$_currentAwayScore',
                    style: TextStyle(
                      color: _currentAwayScore >= _currentHomeScore
                          ? Colors.white
                          : Colors.white.withOpacity(0.6),
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  // "+X" animation for away team
                  if (_showScoreAnimation && !_isHomeTeamScoring && _scoringAnimationPoints != null)
                    Positioned(
                      right: -35,
                      top: -5,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, -20 * value),
                            child: Opacity(
                              opacity: value.clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          '+$_scoringAnimationPoints',
                          style: const TextStyle(
                            color: Color(0xFF22C55E),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Color(0xFF22C55E),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '-',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              // Home score with inline animation
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    '$_currentHomeScore',
                    style: TextStyle(
                      color: _currentHomeScore >= _currentAwayScore
                          ? Colors.white
                          : Colors.white.withOpacity(0.6),
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  // "+X" animation for home team
                  if (_showScoreAnimation && _isHomeTeamScoring && _scoringAnimationPoints != null)
                    Positioned(
                      left: -35,
                      top: -5,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, -20 * value),
                            child: Opacity(
                              opacity: value.clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          '+$_scoringAnimationPoints',
                          style: const TextStyle(
                            color: Color(0xFF22C55E),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Color(0xFF22C55E),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isLive
                  ? const Color(0xFFFF416C).withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _currentGameTime ?? 'Final',
              style: TextStyle(
                color: widget.isLive ? const Color(0xFFFF6B8A) : Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: _homeColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading game stats...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFFF6B6B),
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _error ?? 'Something went wrong',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchGameDetails,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _homeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SUMMARY TAB ====================

  Widget _buildSummaryTab() {
    if (_gameDetails == null) return _buildLoading();

    return RefreshIndicator(
      onRefresh: _fetchGameDetails,
      color: _homeColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Top Performers Card (prominent display)
          if (_gameDetails!.leaders.isNotEmpty) ...[
            _buildTopPerformersCard(),
            const SizedBox(height: 24),
          ],

          // Game Leaders (detailed by category)
          _buildGameLeaders(),
          const SizedBox(height: 24),

          // Team Stats Comparison
          if (_gameDetails!.homeStats.isNotEmpty) ...[
            _buildTeamStatsComparison(),
            const SizedBox(height: 24),
          ],

          // Game Info
          if (_gameDetails!.venue != null) _buildGameInfo(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTopPerformersCard() {
    // Get top 2 performers from different teams
    final leaders = _gameDetails!.leaders;
    if (leaders.isEmpty) return const SizedBox.shrink();

    // Find best performer from each team
    GameLeader? awayTop;
    GameLeader? homeTop;
    for (final leader in leaders) {
      if (leader.teamAbbr == _gameDetails?.awayTeam?.abbreviation && awayTop == null) {
        awayTop = leader;
      } else if (leader.teamAbbr == _gameDetails?.homeTeam?.abbreviation && homeTop == null) {
        homeTop = leader;
      }
      if (awayTop != null && homeTop != null) break;
    }

    if (awayTop == null && homeTop == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _awayColor.withOpacity(0.2),
            const Color(0xFF1A1A1F),
            _homeColor.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 24),
              const SizedBox(width: 8),
              const Text(
                'TOP PERFORMERS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 24),
            ],
          ),
          const SizedBox(height: 20),

          // Performers
          Row(
            children: [
              if (awayTop != null)
                Expanded(child: _buildTopPerformer(awayTop, _awayColor)),
              if (awayTop != null && homeTop != null)
                Container(
                  width: 1,
                  height: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.white.withOpacity(0.1),
                ),
              if (homeTop != null)
                Expanded(child: _buildTopPerformer(homeTop, _homeColor)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildTopPerformer(GameLeader leader, Color teamColor) {
    return Column(
      children: [
        // Headshot with glow
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                teamColor.withOpacity(0.4),
                teamColor.withOpacity(0.1),
              ],
            ),
            border: Border.all(color: teamColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: teamColor.withOpacity(0.3),
                blurRadius: 16,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: leader.headshot != null
                ? CachedNetworkImage(
                    imageUrl: leader.headshot!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Icon(
                      Icons.person_rounded,
                      color: Colors.white.withOpacity(0.4),
                      size: 36,
                    ),
                  )
                : Icon(
                    Icons.person_rounded,
                    color: Colors.white.withOpacity(0.4),
                    size: 36,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Stat value
        Text(
          leader.value,
          style: TextStyle(
            color: teamColor,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        // Name
        Text(
          leader.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Category
        Text(
          _formatCategoryName(leader.category),
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildGameLeaders() {
    final leaders = _gameDetails!.leaders;

    // Group leaders by category
    final leadersByCategory = <String, List<GameLeader>>{};
    for (final leader in leaders) {
      leadersByCategory.putIfAbsent(leader.category, () => []).add(leader);
    }

    if (leadersByCategory.isEmpty) {
      return _buildEmptyLeadersCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Game Leaders', Icons.emoji_events_rounded),
        const SizedBox(height: 12),
        ...leadersByCategory.entries.take(3).map((entry) {
          final categoryLeaders = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildLeaderCard(entry.key, categoryLeaders),
          );
        }),
      ],
    );
  }

  Widget _buildEmptyLeadersCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Game Leaders', Icons.emoji_events_rounded),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.sports_rounded,
                size: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              const SizedBox(height: 12),
              Text(
                widget.isLive ? 'Leaders will appear as the game progresses' : 'No leader data available',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderCard(String category, List<GameLeader> leaders) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // Category header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Text(
              _formatCategoryName(category),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Leaders row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: leaders.take(2).map((leader) {
                final isAway = leader.teamAbbr == _gameDetails?.awayTeam?.abbreviation;
                return Expanded(
                  child: _buildLeaderPlayer(
                    leader,
                    isAway ? _awayColor : _homeColor,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderPlayer(GameLeader leader, Color teamColor) {
    return Column(
      children: [
        // Player headshot
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                teamColor.withOpacity(0.3),
                teamColor.withOpacity(0.1),
              ],
            ),
            border: Border.all(color: teamColor.withOpacity(0.5), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: leader.headshot != null
                ? CachedNetworkImage(
                    imageUrl: leader.headshot!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Icon(
                      Icons.person_rounded,
                      color: Colors.white.withOpacity(0.3),
                      size: 32,
                    ),
                  )
                : Icon(
                    Icons.person_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 32,
                  ),
          ),
        ),
        const SizedBox(height: 10),
        // Stat value
        Text(
          leader.value,
          style: TextStyle(
            color: teamColor,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        // Player name
        Text(
          leader.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Team abbr
        if (leader.teamAbbr != null)
          Text(
            leader.teamAbbr!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  String _formatCategoryName(String name) {
    return name
        .replaceAll('passing', 'PASSING')
        .replaceAll('rushing', 'RUSHING')
        .replaceAll('receiving', 'RECEIVING')
        .replaceAll('rating', 'RATING')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .toUpperCase();
  }

  Widget _buildTeamStatsComparison() {
    final homeStats = _gameDetails!.homeStats;
    final awayStats = _gameDetails!.awayStats;

    if (homeStats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Team Stats', Icons.analytics_rounded),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              // Header with team logos
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    TeamLogo(
                      logoUrl: widget.awayLogo,
                      teamName: widget.awayTeam,
                      size: 28,
                    ),
                    Expanded(
                      child: Text(
                        _gameDetails?.awayTeam?.abbreviation ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Spacer(),
                    Expanded(
                      child: Text(
                        _gameDetails?.homeTeam?.abbreviation ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    TeamLogo(
                      logoUrl: widget.homeLogo,
                      teamName: widget.homeTeam,
                      size: 28,
                    ),
                  ],
                ),
              ),
              // Stats rows
              ...List.generate(
                homeStats.length.clamp(0, 10),
                (index) {
                  final homeStat = homeStats[index];
                  final awayStat = index < awayStats.length ? awayStats[index] : null;
                  return _buildStatRow(
                    homeStat.name,
                    awayStat?.value ?? '-',
                    homeStat.value,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String awayValue, String homeValue) {
    // Parse values for bar widths
    final awayNum = double.tryParse(awayValue.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final homeNum = double.tryParse(homeValue.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final total = awayNum + homeNum;
    final awayPercent = total > 0 ? awayNum / total : 0.5;
    final homePercent = total > 0 ? homeNum / total : 0.5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  awayValue,
                  style: TextStyle(
                    color: awayNum >= homeNum ? Colors.white : Colors.white.withOpacity(0.5),
                    fontSize: 15,
                    fontWeight: awayNum >= homeNum ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _formatStatLabel(label),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  homeValue,
                  style: TextStyle(
                    color: homeNum >= awayNum ? Colors.white : Colors.white.withOpacity(0.5),
                    fontSize: 15,
                    fontWeight: homeNum >= awayNum ? FontWeight.w700 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Comparison bar
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: awayPercent.clamp(0.05, 1.0),
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: awayNum >= homeNum ? _awayColor : _awayColor.withOpacity(0.3),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(2)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: homePercent.clamp(0.05, 1.0),
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: homeNum >= awayNum ? _homeColor : _homeColor.withOpacity(0.3),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatStatLabel(String label) {
    return label
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}')
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join(' ');
  }

  Widget _buildGameInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Game Info', Icons.info_outline_rounded),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              if (_gameDetails!.venue != null)
                _buildInfoItem(Icons.stadium_rounded, 'Venue', _gameDetails!.venue!),
              if (_gameDetails!.attendance != null)
                _buildInfoItem(
                  Icons.people_rounded,
                  'Attendance',
                  _formatNumber(_gameDetails!.attendance!),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(0.5), size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int num) {
    return num.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ==================== BOX SCORE TAB ====================

  Widget _buildBoxScoreTab() {
    if (_gameDetails == null) return _buildLoading();

    final homePlayers = _gameDetails!.homePlayers;
    final awayPlayers = _gameDetails!.awayPlayers;

    if (homePlayers.isEmpty && awayPlayers.isEmpty) {
      return _buildEmptyBoxScore();
    }

    final selectedPlayers = _selectedBoxScoreTeam == 0 ? awayPlayers : homePlayers;
    final selectedColor = _selectedBoxScoreTeam == 0 ? _awayColor : _homeColor;

    return Column(
      children: [
        // Team selector (buttons instead of TabBar to avoid swipe conflicts)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              // Away team button
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedBoxScoreTeam = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: _selectedBoxScoreTeam == 0
                          ? LinearGradient(
                              colors: [_awayColor, _awayColor.withOpacity(0.8)],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TeamLogo(
                          logoUrl: widget.awayLogo,
                          teamName: widget.awayTeam,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getShortName(widget.awayTeam),
                          style: TextStyle(
                            color: _selectedBoxScoreTeam == 0
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Home team button
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedBoxScoreTeam = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: _selectedBoxScoreTeam == 1
                          ? LinearGradient(
                              colors: [_homeColor, _homeColor.withOpacity(0.8)],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TeamLogo(
                          logoUrl: widget.homeLogo,
                          teamName: widget.homeTeam,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getShortName(widget.homeTeam),
                          style: TextStyle(
                            color: _selectedBoxScoreTeam == 1
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Player stats
        Expanded(
          child: _buildTeamBoxScore(selectedPlayers, selectedColor),
        ),
      ],
    );
  }

  Widget _buildEmptyBoxScore() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sports_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Box Score Not Available',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isLive
                ? 'Stats will appear as the game progresses'
                : 'Player statistics are not available for this game',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTeamBoxScore(List<PlayerStats> players, Color teamColor) {
    if (players.isEmpty) {
      return Center(
        child: Text(
          'No player stats available',
          style: TextStyle(color: Colors.white.withOpacity(0.4)),
        ),
      );
    }

    // Group by category
    final grouped = <String, List<PlayerStats>>{};
    for (final player in players) {
      grouped.putIfAbsent(player.category, () => []).add(player);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        return _buildCategorySection(entry.key, entry.value, teamColor);
      }).toList(),
    );
  }

  Widget _buildCategorySection(String category, List<PlayerStats> players, Color teamColor) {
    if (players.isEmpty) return const SizedBox.shrink();

    // Get stat labels from first player
    final statLabels = players.first.stats.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [teamColor.withOpacity(0.3), Colors.transparent],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: teamColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),

        // Stats table
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                Colors.white.withOpacity(0.03),
              ),
              dataRowColor: WidgetStateProperty.all(Colors.transparent),
              columnSpacing: 16,
              horizontalMargin: 12,
              headingTextStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              dataTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              columns: [
                const DataColumn(label: Text('PLAYER')),
                ...statLabels.take(8).map((label) => DataColumn(
                  label: Text(label),
                  numeric: true,
                )),
              ],
              rows: players.map((player) => DataRow(
                cells: [
                  DataCell(_buildPlayerCell(player, teamColor)),
                  ...statLabels.take(8).map((label) => DataCell(
                    Text(
                      player.stats[label] ?? '-',
                      style: TextStyle(
                        fontWeight: _isHighlightStat(label, player.stats[label])
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: _isHighlightStat(label, player.stats[label])
                            ? teamColor
                            : Colors.white,
                      ),
                    ),
                  )),
                ],
              )).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPlayerCell(PlayerStats player, Color teamColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Headshot or jersey
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: teamColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: player.headshot != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: player.headshot!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Center(
                      child: Text(
                        '#${player.jersey}',
                        style: TextStyle(
                          color: teamColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    '#${player.jersey}',
                    style: TextStyle(
                      color: teamColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              player.shortName.isNotEmpty ? player.shortName : player.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              player.position,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isHighlightStat(String label, String? value) {
    if (value == null) return false;
    final num = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

    // Highlight high values for certain stats
    if (label == 'PTS' && num >= 20) return true;
    if (label == 'REB' && num >= 10) return true;
    if (label == 'AST' && num >= 8) return true;
    if (label == 'YDS' && num >= 100) return true;
    if (label == 'TD' && num >= 2) return true;

    return false;
  }

  // ==================== PLAYS TAB ====================

  Widget _buildPlaysTab() {
    if (_gameDetails == null) return _buildLoading();

    final plays = _gameDetails!.scoringPlays;

    if (plays.isEmpty) {
      return _buildEmptyPlays();
    }

    // Group plays by period
    final playsByPeriod = <int, List<ScoringPlay>>{};
    for (final play in plays) {
      playsByPeriod.putIfAbsent(play.period, () => []).add(play);
    }

    // Sort plays within each period by clock time (most recent first = lower time)
    for (final period in playsByPeriod.keys) {
      playsByPeriod[period]!.sort((a, b) {
        // Parse clock time to seconds for comparison (e.g., "11:23" -> 683)
        final aSeconds = _clockToSeconds(a.clock);
        final bSeconds = _clockToSeconds(b.clock);
        return aSeconds.compareTo(bSeconds); // Lower time = more recent
      });
    }

    // Sort periods in descending order (Q4 before Q3, etc.)
    final sortedPeriods = playsByPeriod.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sortedPeriods.map((period) {
        return _buildPeriodSection(period, playsByPeriod[period]!);
      }).toList(),
    );
  }

  /// Convert clock string (e.g., "11:23") to total seconds for sorting
  int _clockToSeconds(String clock) {
    try {
      final parts = clock.split(':');
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 0;
        final seconds = int.tryParse(parts[1]) ?? 0;
        return minutes * 60 + seconds;
      }
      // Handle soccer-style clock (e.g., "45'")
      final minutesOnly = int.tryParse(clock.replaceAll(RegExp(r'[^0-9]'), ''));
      return (minutesOnly ?? 0) * 60;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildEmptyPlays() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sports_score_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Scoring Plays',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isLive
                ? 'Plays will appear as they happen'
                : 'No scoring plays recorded for this game',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSection(int period, List<ScoringPlay> plays) {
    final periodName = _getPeriodName(period);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period header
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  periodName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 12),
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ),
        // Plays
        ...plays.asMap().entries.map((entry) {
          return _buildPlayItem(entry.value, entry.key);
        }),
      ],
    );
  }

  String _getPeriodName(int period) {
    if (widget.sportKey.contains('soccer')) {
      return period == 1 ? '1ST HALF' : '2ND HALF';
    }
    if (period > 4) return 'OT${period - 4}';
    return 'Q$period';
  }

  Widget _buildPlayItem(ScoringPlay play, int index) {
    final isHomeTeam = play.teamAbbr == _gameDetails?.homeTeam?.abbreviation;
    final teamColor = isHomeTeam ? _homeColor : _awayColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: teamColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: teamColor.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 2,
                  height: 80,
                  color: Colors.white.withOpacity(0.1),
                ),
              ],
            ),
          ),

          // Play content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: teamColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      if (play.teamLogo != null)
                        CachedNetworkImage(
                          imageUrl: play.teamLogo!,
                          width: 24,
                          height: 24,
                          errorWidget: (_, __, ___) => Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: teamColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        play.teamAbbr ?? '',
                        style: TextStyle(
                          color: teamColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          play.clock,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Description
                  Text(
                    play.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Score badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _awayColor.withOpacity(0.3),
                          _homeColor.withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_gameDetails?.awayTeam?.abbreviation ?? 'AWAY'}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${play.awayScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '-',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          '${play.homeScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_gameDetails?.homeTeam?.abbreviation ?? 'HOME'}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate(delay: Duration(milliseconds: index * 80))
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.1, end: 0),
          ),
        ],
      ),
    );
  }
}

/// Tab bar delegate for sticky header
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final Color homeColor;

  _TabBarDelegate({
    required this.tabController,
    required this.homeColor,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: tabController,
        indicatorColor: homeColor,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.4),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: 'Summary'),
          Tab(text: 'Box Score'),
          Tab(text: 'Plays'),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 50;

  @override
  double get minExtent => 50;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return homeColor != oldDelegate.homeColor;
  }
}
