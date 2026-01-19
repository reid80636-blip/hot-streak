import 'package:flutter/material.dart';
import '../config/theme.dart';

enum SportType {
  soccerEpl,
  soccerLaLiga,
  soccerChampionsLeague,
  soccerMls,
  soccerSerieA,
  soccerBundesliga,
  soccerLigue1,
  nfl,
  nba,
  nhl,
  mlb,
  ncaaf,
  ncaab,
}

class Sport {
  final SportType type;
  final String key;
  final String name;
  final String shortName;
  final IconData icon;
  final Color color;
  final String emoji;
  final String? logoUrl;
  final Color? gradientStart;
  final Color? gradientEnd;

  const Sport({
    required this.type,
    required this.key,
    required this.name,
    required this.shortName,
    required this.icon,
    required this.color,
    required this.emoji,
    this.logoUrl,
    this.gradientStart,
    this.gradientEnd,
  });

  static const List<Sport> all = [
    Sport(
      type: SportType.nfl,
      key: 'americanfootball_nfl',
      name: 'NFL',
      shortName: 'NFL',
      icon: Icons.sports_football,
      color: AppColors.nfl,
      emoji: '🏈',
      logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/nfl.png',
      gradientStart: Color(0xFF013369),
      gradientEnd: Color(0xFFD50A0A),
    ),
    Sport(
      type: SportType.nba,
      key: 'basketball_nba',
      name: 'NBA',
      shortName: 'NBA',
      icon: Icons.sports_basketball,
      color: AppColors.nba,
      emoji: '🏀',
      logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/nba.png',
      gradientStart: Color(0xFF1D428A),
      gradientEnd: Color(0xFFC8102E),
    ),
    Sport(
      type: SportType.nhl,
      key: 'icehockey_nhl',
      name: 'NHL',
      shortName: 'NHL',
      icon: Icons.sports_hockey,
      color: Color(0xFF000000),
      emoji: '🏒',
      logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/nhl.png',
      gradientStart: Color(0xFF000000),
      gradientEnd: Color(0xFF041E42),
    ),
    Sport(
      type: SportType.mlb,
      key: 'baseball_mlb',
      name: 'MLB',
      shortName: 'MLB',
      icon: Icons.sports_baseball,
      color: Color(0xFF002D72),
      emoji: '⚾',
      logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/mlb.png',
      gradientStart: Color(0xFF002D72),
      gradientEnd: Color(0xFFD50032),
    ),
    Sport(
      type: SportType.soccerEpl,
      key: 'soccer_epl',
      name: 'Premier League',
      shortName: 'EPL',
      icon: Icons.sports_soccer,
      color: AppColors.soccer,
      emoji: '⚽',
      logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/23.png',
      gradientStart: Color(0xFF3D195B),
      gradientEnd: Color(0xFF00FF85),
    ),
    Sport(
      type: SportType.ncaaf,
      key: 'americanfootball_ncaaf',
      name: 'College Football',
      shortName: 'CFB',
      icon: Icons.sports_football,
      color: AppColors.ncaaf,
      emoji: '🏈',
      logoUrl: 'https://a.espncdn.com/i/espn/misc_logos/500/ncaaf.png',
      gradientStart: Color(0xFF002244),
      gradientEnd: Color(0xFFCC5500),
    ),
    Sport(
      type: SportType.ncaab,
      key: 'basketball_ncaab',
      name: 'College Basketball',
      shortName: 'CBB',
      icon: Icons.sports_basketball,
      color: AppColors.ncaab,
      emoji: '🏀',
      logoUrl: 'https://a.espncdn.com/i/espn/misc_logos/500/ncaam.png',
      gradientStart: Color(0xFF0033A0),
      gradientEnd: Color(0xFFFF6600),
    ),
    Sport(
      type: SportType.soccerChampionsLeague,
      key: 'soccer_uefa_champs_league',
      name: 'Champions League',
      shortName: 'UCL',
      icon: Icons.sports_soccer,
      color: AppColors.soccer,
      emoji: '⚽',
      logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/2.png',
      gradientStart: Color(0xFF0E1E5B),
      gradientEnd: Color(0xFF00A3E0),
    ),
    Sport(
      type: SportType.soccerLaLiga,
      key: 'soccer_spain_la_liga',
      name: 'La Liga',
      shortName: 'La Liga',
      icon: Icons.sports_soccer,
      color: AppColors.soccer,
      emoji: '⚽',
      logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/15.png',
      gradientStart: Color(0xFFEE8707),
      gradientEnd: Color(0xFFFF4B44),
    ),
    Sport(
      type: SportType.soccerMls,
      key: 'soccer_usa_mls',
      name: 'MLS',
      shortName: 'MLS',
      icon: Icons.sports_soccer,
      color: AppColors.soccer,
      emoji: '⚽',
      logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/19.png',
      gradientStart: Color(0xFF000000),
      gradientEnd: Color(0xFF80000A),
    ),
    Sport(
      type: SportType.soccerSerieA,
      key: 'soccer_italy_serie_a',
      name: 'Serie A',
      shortName: 'Serie A',
      icon: Icons.sports_soccer,
      color: AppColors.soccer,
      emoji: '⚽',
      logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/12.png',
      gradientStart: Color(0xFF008C45),
      gradientEnd: Color(0xFFCD212A),
    ),
    Sport(
      type: SportType.soccerBundesliga,
      key: 'soccer_germany_bundesliga',
      name: 'Bundesliga',
      shortName: 'Bundesliga',
      icon: Icons.sports_soccer,
      color: AppColors.soccer,
      emoji: '⚽',
      logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/10.png',
      gradientStart: Color(0xFFDD0000),
      gradientEnd: Color(0xFFFFCC00),
    ),
    Sport(
      type: SportType.soccerLigue1,
      key: 'soccer_france_ligue_one',
      name: 'Ligue 1',
      shortName: 'Ligue 1',
      icon: Icons.sports_soccer,
      color: AppColors.soccer,
      emoji: '⚽',
      logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/9.png',
      gradientStart: Color(0xFF0055A4),
      gradientEnd: Color(0xFFEF4135),
    ),
  ];

  static Sport? fromKey(String key) {
    try {
      return all.firstWhere((s) => s.key == key);
    } catch (_) {
      return null;
    }
  }

  static List<Sport> get soccerLeagues => all.where((s) =>
    s.type == SportType.soccerEpl ||
    s.type == SportType.soccerLaLiga ||
    s.type == SportType.soccerChampionsLeague ||
    s.type == SportType.soccerMls ||
    s.type == SportType.soccerSerieA ||
    s.type == SportType.soccerBundesliga ||
    s.type == SportType.soccerLigue1
  ).toList();

  static List<Sport> get americanSports => all.where((s) =>
    s.type == SportType.nfl ||
    s.type == SportType.nba ||
    s.type == SportType.ncaaf ||
    s.type == SportType.ncaab
  ).toList();

  /// Main sports for onboarding - limited selection
  static List<Sport> get mainSports => [
    all.firstWhere((s) => s.type == SportType.nfl),
    all.firstWhere((s) => s.type == SportType.nba),
    all.firstWhere((s) => s.type == SportType.nhl),
    all.firstWhere((s) => s.type == SportType.mlb),
    all.firstWhere((s) => s.type == SportType.ncaaf),
    all.firstWhere((s) => s.type == SportType.ncaab),
    // Combined Soccer option
    Sport(
      type: SportType.soccerEpl,
      key: 'soccer_all',
      name: 'Soccer',
      shortName: 'Soccer',
      icon: Icons.sports_soccer,
      color: AppColors.soccer,
      emoji: '⚽',
      logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/23.png',
      gradientStart: Color(0xFF3D195B),
      gradientEnd: Color(0xFF00FF85),
    ),
  ];
}
