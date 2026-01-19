/// Team logo URL mappings using ESPN's CDN
class TeamLogos {
  // ESPN logo base URLs
  static const String _nflBase = 'https://a.espncdn.com/i/teamlogos/nfl/500';
  static const String _nbaBase = 'https://a.espncdn.com/i/teamlogos/nba/500';
  static const String _mlbBase = 'https://a.espncdn.com/i/teamlogos/mlb/500';
  static const String _ncaaBase = 'https://a.espncdn.com/i/teamlogos/ncaa/500';
  static const String _soccerBase = 'https://a.espncdn.com/i/teamlogos/soccer/500';

  static const Map<String, String> logos = {
    // ===== NFL Teams =====
    'Kansas City Chiefs': '$_nflBase/kc.png',
    'San Francisco 49ers': '$_nflBase/sf.png',
    'Philadelphia Eagles': '$_nflBase/phi.png',
    'Dallas Cowboys': '$_nflBase/dal.png',
    'Buffalo Bills': '$_nflBase/buf.png',
    'Miami Dolphins': '$_nflBase/mia.png',
    'Baltimore Ravens': '$_nflBase/bal.png',
    'Detroit Lions': '$_nflBase/det.png',
    'Green Bay Packers': '$_nflBase/gb.png',
    'Chicago Bears': '$_nflBase/chi.png',
    'New York Giants': '$_nflBase/nyg.png',
    'New York Jets': '$_nflBase/nyj.png',
    'New England Patriots': '$_nflBase/ne.png',
    'Denver Broncos': '$_nflBase/den.png',
    'Las Vegas Raiders': '$_nflBase/lv.png',
    'Los Angeles Rams': '$_nflBase/lar.png',
    'Los Angeles Chargers': '$_nflBase/lac.png',
    'Seattle Seahawks': '$_nflBase/sea.png',
    'Arizona Cardinals': '$_nflBase/ari.png',
    'Minnesota Vikings': '$_nflBase/min.png',

    // ===== NBA Teams =====
    'Boston Celtics': '$_nbaBase/bos.png',
    'Denver Nuggets': '$_nbaBase/den.png',
    'Milwaukee Bucks': '$_nbaBase/mil.png',
    'Phoenix Suns': '$_nbaBase/phx.png',
    'LA Lakers': '$_nbaBase/lal.png',
    'Los Angeles Lakers': '$_nbaBase/lal.png',
    'Golden State Warriors': '$_nbaBase/gs.png',
    'Miami Heat': '$_nbaBase/mia.png',
    'New York Knicks': '$_nbaBase/ny.png',
    'Philadelphia 76ers': '$_nbaBase/phi.png',
    'LA Clippers': '$_nbaBase/lac.png',
    'Los Angeles Clippers': '$_nbaBase/lac.png',
    'Brooklyn Nets': '$_nbaBase/bkn.png',
    'Chicago Bulls': '$_nbaBase/chi.png',
    'Dallas Mavericks': '$_nbaBase/dal.png',
    'Houston Rockets': '$_nbaBase/hou.png',
    'Cleveland Cavaliers': '$_nbaBase/cle.png',
    'Sacramento Kings': '$_nbaBase/sac.png',
    'Atlanta Hawks': '$_nbaBase/atl.png',
    'Memphis Grizzlies': '$_nbaBase/mem.png',

    // ===== College Football (NCAAF) =====
    'Georgia Bulldogs': '$_ncaaBase/61.png',
    'Michigan Wolverines': '$_ncaaBase/130.png',
    'Alabama Crimson Tide': '$_ncaaBase/333.png',
    'Ohio State Buckeyes': '$_ncaaBase/194.png',
    'Texas Longhorns': '$_ncaaBase/251.png',
    'Florida State Seminoles': '$_ncaaBase/52.png',
    'Oregon Ducks': '$_ncaaBase/2483.png',
    'Washington Huskies': '$_ncaaBase/264.png',
    'NC State Wolfpack': '$_ncaaBase/152.png',
    'Clemson Tigers': '$_ncaaBase/228.png',
    'Penn State Nittany Lions': '$_ncaaBase/213.png',
    'Notre Dame Fighting Irish': '$_ncaaBase/87.png',
    'LSU Tigers': '$_ncaaBase/99.png',
    'USC Trojans': '$_ncaaBase/30.png',
    'Tennessee Volunteers': '$_ncaaBase/2633.png',
    'Miami Hurricanes': '$_ncaaBase/2390.png',
    'Oklahoma Sooners': '$_ncaaBase/201.png',
    'Auburn Tigers': '$_ncaaBase/2.png',
    'Florida Gators': '$_ncaaBase/57.png',
    'Wisconsin Badgers': '$_ncaaBase/275.png',

    // ===== College Basketball (NCAAB) =====
    'Duke Blue Devils': '$_ncaaBase/150.png',
    'North Carolina Tar Heels': '$_ncaaBase/153.png',
    'Kansas Jayhawks': '$_ncaaBase/2305.png',
    'Kentucky Wildcats': '$_ncaaBase/96.png',
    'UConn Huskies': '$_ncaaBase/41.png',
    'Purdue Boilermakers': '$_ncaaBase/2509.png',
    'Houston Cougars': '$_ncaaBase/248.png',
    'Arizona Wildcats': '$_ncaaBase/12.png',
    'Gonzaga Bulldogs': '$_ncaaBase/2250.png',
    'Villanova Wildcats': '$_ncaaBase/222.png',
    'Baylor Bears': '$_ncaaBase/239.png',
    'Michigan State Spartans': '$_ncaaBase/127.png',
    'UCLA Bruins': '$_ncaaBase/26.png',
    'Indiana Hoosiers': '$_ncaaBase/84.png',
    'Syracuse Orange': '$_ncaaBase/183.png',
    'Creighton Bluejays': '$_ncaaBase/156.png',

    // ===== English Premier League =====
    'Manchester City': '$_soccerBase/382.png',
    'Arsenal': '$_soccerBase/359.png',
    'Liverpool': '$_soccerBase/364.png',
    'Manchester United': '$_soccerBase/360.png',
    'Chelsea': '$_soccerBase/363.png',
    'Tottenham': '$_soccerBase/367.png',
    'Tottenham Hotspur': '$_soccerBase/367.png',
    'Newcastle': '$_soccerBase/361.png',
    'Newcastle United': '$_soccerBase/361.png',
    'Brighton': '$_soccerBase/331.png',
    'Brighton & Hove Albion': '$_soccerBase/331.png',
    'Aston Villa': '$_soccerBase/362.png',
    'West Ham': '$_soccerBase/371.png',
    'West Ham United': '$_soccerBase/371.png',
    'Everton': '$_soccerBase/368.png',
    'Fulham': '$_soccerBase/370.png',
    'Crystal Palace': '$_soccerBase/384.png',
    'Brentford': '$_soccerBase/337.png',
    'Wolverhampton': '$_soccerBase/380.png',
    'Wolves': '$_soccerBase/380.png',

    // ===== La Liga =====
    'Real Madrid': '$_soccerBase/86.png',
    'Barcelona': '$_soccerBase/83.png',
    'Atletico Madrid': '$_soccerBase/1068.png',
    'Sevilla': '$_soccerBase/243.png',
    'Real Sociedad': '$_soccerBase/89.png',
    'Villarreal': '$_soccerBase/102.png',
    'Athletic Bilbao': '$_soccerBase/93.png',
    'Real Betis': '$_soccerBase/244.png',
    'Valencia': '$_soccerBase/94.png',
    'Girona': '$_soccerBase/9812.png',

    // ===== Champions League (additional European teams) =====
    'Bayern Munich': '$_soccerBase/132.png',
    'PSG': '$_soccerBase/160.png',
    'Paris Saint-Germain': '$_soccerBase/160.png',
    'Inter Milan': '$_soccerBase/110.png',
    'Borussia Dortmund': '$_soccerBase/124.png',
    'AC Milan': '$_soccerBase/103.png',
    'Juventus': '$_soccerBase/111.png',
    'Napoli': '$_soccerBase/114.png',
    'RB Leipzig': '$_soccerBase/11420.png',
    'Porto': '$_soccerBase/ports.png',
    'Benfica': '$_soccerBase/1.png',

    // ===== MLS (All 29 Teams) - Using soccer base with ESPN team IDs =====
    'Inter Miami': '$_soccerBase/10266.png',
    'Inter Miami CF': '$_soccerBase/10266.png',
    'LA Galaxy': '$_soccerBase/14.png',
    'Los Angeles Galaxy': '$_soccerBase/14.png',
    'LAFC': '$_soccerBase/6011.png',
    'Los Angeles FC': '$_soccerBase/6011.png',
    'Seattle Sounders': '$_soccerBase/50.png',
    'Seattle Sounders FC': '$_soccerBase/50.png',
    'Atlanta United': '$_soccerBase/6009.png',
    'Atlanta United FC': '$_soccerBase/6009.png',
    'NYCFC': '$_soccerBase/6010.png',
    'New York City FC': '$_soccerBase/6010.png',
    'Portland Timbers': '$_soccerBase/48.png',
    'Austin FC': '$_soccerBase/6050.png',
    'FC Cincinnati': '$_soccerBase/6019.png',
    'Cincinnati': '$_soccerBase/6019.png',
    'Columbus Crew': '$_soccerBase/41.png',
    'New York Red Bulls': '$_soccerBase/45.png',
    'NY Red Bulls': '$_soccerBase/45.png',
    'Philadelphia Union': '$_soccerBase/47.png',
    'Houston Dynamo': '$_soccerBase/42.png',
    'Houston Dynamo FC': '$_soccerBase/42.png',
    'Orlando City': '$_soccerBase/6012.png',
    'Orlando City SC': '$_soccerBase/6012.png',
    'Sporting Kansas City': '$_soccerBase/46.png',
    'Sporting KC': '$_soccerBase/46.png',
    'Real Salt Lake': '$_soccerBase/49.png',
    'Minnesota United': '$_soccerBase/6013.png',
    'Minnesota United FC': '$_soccerBase/6013.png',
    'Nashville SC': '$_soccerBase/6030.png',
    'Charlotte FC': '$_soccerBase/6034.png',
    'Chicago Fire': '$_soccerBase/40.png',
    'Chicago Fire FC': '$_soccerBase/40.png',
    'CF Montreal': '$_soccerBase/43.png',
    'CF Montréal': '$_soccerBase/43.png',
    'Montreal': '$_soccerBase/43.png',
    'D.C. United': '$_soccerBase/39.png',
    'DC United': '$_soccerBase/39.png',
    'New England Revolution': '$_soccerBase/44.png',
    'NE Revolution': '$_soccerBase/44.png',
    'Toronto FC': '$_soccerBase/51.png',
    'Vancouver Whitecaps': '$_soccerBase/52.png',
    'Vancouver Whitecaps FC': '$_soccerBase/52.png',
    'Colorado Rapids': '$_soccerBase/38.png',
    'FC Dallas': '$_soccerBase/37.png',
    'San Jose Earthquakes': '$_soccerBase/53.png',
    'SJ Earthquakes': '$_soccerBase/53.png',
    'St. Louis City SC': '$_soccerBase/6048.png',
    'St. Louis City': '$_soccerBase/6048.png',
    'St Louis City SC': '$_soccerBase/6048.png',
    'San Diego FC': '$_soccerBase/6060.png',

    // ===== MLB (All 30 Teams) =====
    'New York Yankees': '$_mlbBase/nyy.png',
    'NY Yankees': '$_mlbBase/nyy.png',
    'Yankees': '$_mlbBase/nyy.png',
    'Los Angeles Dodgers': '$_mlbBase/lad.png',
    'LA Dodgers': '$_mlbBase/lad.png',
    'Dodgers': '$_mlbBase/lad.png',
    'Boston Red Sox': '$_mlbBase/bos.png',
    'Red Sox': '$_mlbBase/bos.png',
    'Chicago Cubs': '$_mlbBase/chc.png',
    'Cubs': '$_mlbBase/chc.png',
    'San Francisco Giants': '$_mlbBase/sf.png',
    'SF Giants': '$_mlbBase/sf.png',
    'Giants': '$_mlbBase/sf.png',
    'St. Louis Cardinals': '$_mlbBase/stl.png',
    'St Louis Cardinals': '$_mlbBase/stl.png',
    'Cardinals': '$_mlbBase/stl.png',
    'Philadelphia Phillies': '$_mlbBase/phi.png',
    'Phillies': '$_mlbBase/phi.png',
    'Atlanta Braves': '$_mlbBase/atl.png',
    'Braves': '$_mlbBase/atl.png',
    'Houston Astros': '$_mlbBase/hou.png',
    'Astros': '$_mlbBase/hou.png',
    'New York Mets': '$_mlbBase/nym.png',
    'NY Mets': '$_mlbBase/nym.png',
    'Mets': '$_mlbBase/nym.png',
    'Chicago White Sox': '$_mlbBase/chw.png',
    'White Sox': '$_mlbBase/chw.png',
    'Texas Rangers': '$_mlbBase/tex.png',
    'Rangers': '$_mlbBase/tex.png',
    'Detroit Tigers': '$_mlbBase/det.png',
    'Tigers': '$_mlbBase/det.png',
    'Seattle Mariners': '$_mlbBase/sea.png',
    'Mariners': '$_mlbBase/sea.png',
    'Baltimore Orioles': '$_mlbBase/bal.png',
    'Orioles': '$_mlbBase/bal.png',
    'Cleveland Guardians': '$_mlbBase/cle.png',
    'Guardians': '$_mlbBase/cle.png',
    'Minnesota Twins': '$_mlbBase/min.png',
    'Twins': '$_mlbBase/min.png',
    'Milwaukee Brewers': '$_mlbBase/mil.png',
    'Brewers': '$_mlbBase/mil.png',
    'San Diego Padres': '$_mlbBase/sd.png',
    'Padres': '$_mlbBase/sd.png',
    'Tampa Bay Rays': '$_mlbBase/tb.png',
    'Rays': '$_mlbBase/tb.png',
    'Arizona Diamondbacks': '$_mlbBase/ari.png',
    'Diamondbacks': '$_mlbBase/ari.png',
    'D-backs': '$_mlbBase/ari.png',
    'Los Angeles Angels': '$_mlbBase/laa.png',
    'LA Angels': '$_mlbBase/laa.png',
    'Angels': '$_mlbBase/laa.png',
    'Toronto Blue Jays': '$_mlbBase/tor.png',
    'Blue Jays': '$_mlbBase/tor.png',
    'Kansas City Royals': '$_mlbBase/kc.png',
    'Royals': '$_mlbBase/kc.png',
    'Pittsburgh Pirates': '$_mlbBase/pit.png',
    'Pirates': '$_mlbBase/pit.png',
    'Cincinnati Reds': '$_mlbBase/cin.png',
    'Reds': '$_mlbBase/cin.png',
    'Colorado Rockies': '$_mlbBase/col.png',
    'Rockies': '$_mlbBase/col.png',
    'Miami Marlins': '$_mlbBase/mia.png',
    'Marlins': '$_mlbBase/mia.png',
    'Washington Nationals': '$_mlbBase/wsh.png',
    'Nationals': '$_mlbBase/wsh.png',
    'Oakland Athletics': '$_mlbBase/oak.png',
    'Athletics': '$_mlbBase/oak.png',
  };

  /// Get logo URL for a team name
  static String? getLogoUrl(String teamName) {
    // Try exact match first
    if (logos.containsKey(teamName)) {
      return logos[teamName];
    }

    // Try case-insensitive match
    final lowerName = teamName.toLowerCase();
    for (final entry in logos.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return entry.value;
      }
    }

    // Try partial match (for API variations)
    for (final entry in logos.entries) {
      if (entry.key.toLowerCase().contains(lowerName) ||
          lowerName.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return null;
  }

  /// Get team initials for fallback display
  static String getInitials(String teamName) {
    final words = teamName.split(' ');
    if (words.length == 1) {
      return teamName.substring(0, 2).toUpperCase();
    }
    return words.take(2).map((w) => w[0]).join().toUpperCase();
  }
}
