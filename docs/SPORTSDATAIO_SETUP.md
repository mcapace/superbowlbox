# Sports Data IO API Setup

The app uses [Sports Data IO](https://sportsdata.io) for **NFL** data (scores, and more). We’re starting with NFL only; other sports (e.g. NBA, NHL, MLB) can be added later. When you add your API key, the app prefers Sports Data IO for NFL; if the key is missing or a request fails, it falls back to the free ESPN scoreboard.

## 1. Get your API key

1. Sign up at [sportsdata.io](https://sportsdata.io) and log in.
2. In your account or dashboard, find **API keys** (or **Subscriptions** / **API access**).
3. Copy your key. It may be named for a specific product (e.g. NFL Scores).

## 2. Add the key to the app (kept out of version control)

- Copy **SuperBowlBox/Resources/Secrets.example.plist** to **Secrets.plist** in the same folder (if you don’t already have **Secrets.plist**).
- Open **Secrets.plist** and set **SportsDataIOApiKey** to your API key (String value).
- **Secrets.plist** is listed in **.gitignore**, so it is never committed. The app reads the key from this file at runtime (it is copied into the app bundle by Xcode). **Secrets.example.plist** is the template in the repo (empty key).

**Security:** Your real key lives only in **Secrets.plist**, which is gitignored. Do not add Secrets.plist to version control.

## 3. How the app uses it

- **NFL live score (dashboard):**  
  `NFLScoreService` calls Sports Data IO first (endpoint: **ScoresByDate** for today’s date). If the key is set and the request succeeds, that score is shown. Otherwise the app uses the ESPN scoreboard.
- **Authentication:** The key is sent in the **Ocp-Apim-Subscription-Key** HTTP header (see [Sports Data IO docs](https://sportsdata.io/developers/api-documentation/nfl)).
- **Base URL:** `https://api.sportsdata.io/v3/nfl/scores/json/`

## 4. Endpoints used

| Purpose        | Endpoint (NFL)              | Notes                          |
|----------------|-----------------------------|--------------------------------|
| Today’s scores | `ScoresByDate/{YYYY-MM-DD}` | Picks first in‑progress or game |

If Sports Data IO uses different path names in your plan (e.g. **ScoresByWeek**), you can change the path in `SportsDataIOService.fetchNFLScore()` (see `SportsDataIOConfig.nflScoresURL(pathComponent:)`).

### Other NFL API sections (same key)

This doc and the app currently focus on **NFL** only. The [NFL API documentation](https://sportsdata.io/developers/api-documentation/nfl) includes many more feeds you can call with the same **Ocp-Apim-Subscription-Key** header, for example:

- **[Standings](https://sportsdata.io/developers/api-documentation/nfl#standings)** – division/conference standings
- **[Standings, Rankings & Brackets](https://sportsdata.io/developers/api-documentation/nfl#standings-rankings-brackets)** – full standings, rankings, playoff brackets
- **[Teams, Players & Rosters](https://sportsdata.io/developers/api-documentation/nfl#teams-players-rosters)** – teams, players, rosters
- **[Depth Charts, Lineups & Injuries](https://sportsdata.io/developers/api-documentation/nfl#depth-charts-lineups-injuries)** – depth charts, lineups, and injuries
- **[Depth Charts (All)](https://sportsdata.io/developers/api-documentation/nfl#depth-charts--all)** – all depth charts
- **[Depth Charts (By Active)](https://sportsdata.io/developers/api-documentation/nfl#depth-charts--by-active)** – depth charts for active teams
- **[Injuries (By Team)](https://sportsdata.io/developers/api-documentation/nfl#injuries--by-team)** – injuries by team
- **[Player Details (All)](https://sportsdata.io/developers/api-documentation/nfl#player-details--all)** – player details for all players
- **[Player Details (By Free Agents)](https://sportsdata.io/developers/api-documentation/nfl#player-details--by-free-agents)** – player details for free agents
- **[Player Details (By Injured)](https://sportsdata.io/developers/api-documentation/nfl#player-details--by-injured)** – player details for injured players
- **[Player Details (By Rookie Draft Year)](https://sportsdata.io/developers/api-documentation/nfl#player-details--by-rookie-draft-year)** – player details by rookie draft year
- **[Player Details (By Team)](https://sportsdata.io/developers/api-documentation/nfl#player-details--by-team)** – player details by team
- **[Player Profiles (All)](https://sportsdata.io/developers/api-documentation/nfl#player-profiles--all)** – player profiles
- **[Player Profiles by Free Agent](https://sportsdata.io/developers/api-documentation/nfl#player-profiles--by-free-agent)** – free agent player profiles
- **[Player Profiles by Rookie Draft Year](https://sportsdata.io/developers/api-documentation/nfl#player-profiles--by-rookie-draft-year)** – player profiles by rookie draft year
- **[Player Profiles by Team](https://sportsdata.io/developers/api-documentation/nfl#player-profiles--by-team)** – player profiles by team
- **[Pro Bowlers](https://sportsdata.io/developers/api-documentation/nfl#pro-bowlers)** – Pro Bowl selections
- **[Team Player Stats](https://sportsdata.io/developers/api-documentation/nfl#team-player-stats)** – team and player statistics
- **[Box Score (Live & Final)](https://sportsdata.io/developers/api-documentation/nfl#box-score-live--final)** – box score per game (live and final)
- **[Box Score (Final)](https://sportsdata.io/developers/api-documentation/nfl#box-score-final)** – final box score per game
- **[Box Score (By Team, Live & Final)](https://sportsdata.io/developers/api-documentation/nfl#box-score--by-team-live--final)** – box score by team per game (live and final)
- **[Box Score (By Team, Final)](https://sportsdata.io/developers/api-documentation/nfl#box-score--by-team-final)** – final box score by team per game
- **[Box Scores Delta (By Week)](https://sportsdata.io/developers/api-documentation/nfl#box-scores-delta--by-week)** – box score deltas/changes by week
- **[Play-by-Play](https://sportsdata.io/developers/api-documentation/nfl#play-by-play)** – play-by-play data per game
- **[Play-by-Play (Live & Final)](https://sportsdata.io/developers/api-documentation/nfl#play-by-play-live--final)** – play-by-play per game (live and final)
- **[Play-by-Play (Final)](https://sportsdata.io/developers/api-documentation/nfl#play-by-play-final)** – final play-by-play per game
- **[Play-by-Play (By Team, Live & Final)](https://sportsdata.io/developers/api-documentation/nfl#play-by-play--by-team-live--final)** – play-by-play by team per game (live and final)
- **[Play-by-Play (By Team, Final)](https://sportsdata.io/developers/api-documentation/nfl#play-by-play--by-team-final)** – final play-by-play by team per game
- **[Play-by-Play Delta](https://sportsdata.io/developers/api-documentation/nfl#play-by-play-delta)** – play-by-play deltas/changes
- **[Game Stats by Season](https://sportsdata.io/developers/api-documentation/nfl#game-stats-by-season-deprecated-use-team-game-stats-instead)** – game stats by season *(deprecated; use Team Game Stats instead)*
- **[Player Game Logs (By Season)](https://sportsdata.io/developers/api-documentation/nfl#player-game-logs--by-season)** – player game logs by season
- **[Player Game Red Zone Stats](https://sportsdata.io/developers/api-documentation/nfl#player-game-red-zone-stats)** – player red zone stats per game
- **[Player Game Red Zone Stats (Inside Five)](https://sportsdata.io/developers/api-documentation/nfl#player-game-red-zone-stats-inside-five)** – player red zone stats inside the 5-yard line per game
- **[Player Game Stats (By Team, Live & Final)](https://sportsdata.io/developers/api-documentation/nfl#player-game-stats--by-team-live--final)** – player game stats by team (live and final)
- **[Player Game Stats (By Team, Final)](https://sportsdata.io/developers/api-documentation/nfl#player-game-stats--by-team-final)** – final player game stats by team
- **[Player Game Stats (By Week, Final)](https://sportsdata.io/developers/api-documentation/nfl#player-game-stats--by-week-final)** – final player game stats by week
- **[Player Game Stats Delta](https://sportsdata.io/developers/api-documentation/nfl#player-game-stats-delta)** – player game stats deltas/changes
- **[Player Game Stats Delta (By Week)](https://sportsdata.io/developers/api-documentation/nfl#player-game-stats-delta--by-week)** – player game stats deltas by week
- **[Player Season Red Zone Stats](https://sportsdata.io/developers/api-documentation/nfl#player-season-red-zone-stats)** – player red zone stats by season
- **[Player Season Red Zone Stats (Inside Five)](https://sportsdata.io/developers/api-documentation/nfl#player-season-red-zone-stats-inside-five)** – player red zone stats inside the 5-yard line by season
- **[Player Season Red Zone Stats (Inside Ten)](https://sportsdata.io/developers/api-documentation/nfl#player-season-red-zone-stats-inside-ten)** – player red zone stats inside the 10-yard line by season
- **[Player Season Stats](https://sportsdata.io/developers/api-documentation/nfl#player-season-stats)** – player season statistics
- **[Player Season Stats (By Team)](https://sportsdata.io/developers/api-documentation/nfl#player-season-stats--by-team)** – player season stats by team
- **[Player Season Third Down Stats](https://sportsdata.io/developers/api-documentation/nfl#player-season-third-down-stats)** – player third-down stats by season
- **[Team Game Stats (Live & Final)](https://sportsdata.io/developers/api-documentation/nfl#team-game-stats-live--final)** – team game stats (live and final)
- **[Team Game Stats (By Game, Final)](https://sportsdata.io/developers/api-documentation/nfl#team-game-stats--by-game-final)** – final team game stats per game
- **[Team Season Stats](https://sportsdata.io/developers/api-documentation/nfl#team-season-stats)** – team season statistics
- **[Team Profiles Basic (All)](https://sportsdata.io/developers/api-documentation/nfl#team-profiles-basic--all)** – basic team profiles for all teams
- **[Team Profiles (All)](https://sportsdata.io/developers/api-documentation/nfl#team-profiles--all)** – full team profiles for all teams
- **[Team Profiles by Active](https://sportsdata.io/developers/api-documentation/nfl#team-profiles--by-active)** – team profiles for active teams
- **[Team Profiles by Season](https://sportsdata.io/developers/api-documentation/nfl#team-profiles--by-season)** – team profiles by season
- **[Venues & Officials](https://sportsdata.io/developers/api-documentation/nfl#venues-officials)** – stadiums/venues and officials
- **[Stadiums](https://sportsdata.io/developers/api-documentation/nfl#stadiums)** – stadium data
- **[Referees](https://sportsdata.io/developers/api-documentation/nfl#referees)** – referee data
- **[Utility Endpoints](https://sportsdata.io/developers/api-documentation/nfl#utility-endpoints)** – utility/helper endpoints
- **[Player Headshots](https://sportsdata.io/developers/api-documentation/nfl#player-headshots)** – player headshot images (integration tools)
- **[Headshots](https://sportsdata.io/developers/api-documentation/nfl#headshots)** – headshot images (integration tools)
- **[Are Games In Progress](https://sportsdata.io/developers/api-documentation/nfl#are-games-in-progress)** – whether any NFL games are currently in progress
- **[Betting Events (By Date)](https://sportsdata.io/developers/api-documentation/nfl#betting-events--by-date)** – betting events (games with odds) by date
- **[Betting Events (By Season)](https://sportsdata.io/developers/api-documentation/nfl#betting-events--by-season)** – betting events (games with odds) by season
- **[Betting Markets (By Event)](https://sportsdata.io/developers/api-documentation/nfl#betting-markets--by-event)** – betting markets (e.g. spread, total) by event/game
- **[Betting Markets (By Event Sportsbook Group)](https://sportsdata.io/developers/api-documentation/nfl#betting-markets--by-event-sportsbook-group)** – betting markets by event and sportsbook group
- **[Betting Markets (By Game Sportsbook Group)](https://sportsdata.io/developers/api-documentation/nfl#betting-markets--by-game-sportsbook-group)** – betting markets by game and sportsbook group
- **[Betting Markets (By Market Type)](https://sportsdata.io/developers/api-documentation/nfl#betting-markets--by-market-type)** – betting markets filtered by market type (e.g. spread, total)
- **[Betting Markets (By Market Type Sportsbook Group)](https://sportsdata.io/developers/api-documentation/nfl#betting-markets--by-market-type-sportsbook-group)** – betting markets by market type and sportsbook group
- **[Betting Market](https://sportsdata.io/developers/api-documentation/nfl#betting-market)** – single betting market details
- **[Betting Market Sportsbook Group](https://sportsdata.io/developers/api-documentation/nfl#betting-market-sportsbook-group)** – single betting market by sportsbook group
- **[Betting Results (By Market)](https://sportsdata.io/developers/api-documentation/nfl#betting-results--by-market)** – betting/settlement results by market
- **[Betting Results (By Market Sportsbook Group)](https://sportsdata.io/developers/api-documentation/nfl#betting-results--by-market-sportsbook-group)** – betting results by market and sportsbook group
- **[Betting Metadata](https://sportsdata.io/developers/api-documentation/nfl#betting-metadata)** – betting-related metadata
- **[Betting Player Props (By Game)](https://sportsdata.io/developers/api-documentation/nfl#betting-player-props--by-game)** – player prop betting lines by game
- **[Betting Player Props (By Game Sportsbook Group)](https://sportsdata.io/developers/api-documentation/nfl#betting-player-props--by-game-sportsbook-group)** – player prop betting lines by game and sportsbook group
- **[Game Lines](https://sportsdata.io/developers/api-documentation/nfl#game-lines)** – betting lines (spreads, totals) per game
- **[In-Game Odds (By Week)](https://sportsdata.io/developers/api-documentation/nfl#ingame-odds--by-week)** – in-game/live odds by week
- **[In-Game Odds By Week Sportsbook Group](https://sportsdata.io/developers/api-documentation/nfl#ingame-odds-by-week-sportsbook-group)** – in-game odds by week and sportsbook group
- **[In-Game Odds Line Movement](https://sportsdata.io/developers/api-documentation/nfl#ingame-odds-line-movement)** – in-game odds line movement
- **[In-Game Odds Line Movement Sportsbook Group](https://sportsdata.io/developers/api-documentation/nfl#ingame-odds-line-movement-sportsbook-group)** – in-game odds line movement by sportsbook group
- **[In-Game Odds Line Movement With Resulting Sportsbook Group](https://sportsdata.io/developers/api-documentation/nfl#ingame-odds-line-movement-with-resulting-sportsbook-group)** – in-game odds line movement with resulting line by sportsbook group
- **[Pregame Odds (By Week)](https://sportsdata.io/developers/api-documentation/nfl#pregame-odds--by-week)** – pregame betting odds by week
- **[Pregame Odds Line Movement](https://sportsdata.io/developers/api-documentation/nfl#pregame-odds-line-movement)** – pregame odds line movement
- **[Period Game Odds (By Week)](https://sportsdata.io/developers/api-documentation/nfl#period-game-odds--by-week)** – period/half game odds by week
- **[Period Game Odds Line Movement](https://sportsdata.io/developers/api-documentation/nfl#period-game-odds-line-movement-)** – period game odds line movement
- **[Pregame and Period Game Odds Line Movement Sportsbook Group](https://sportsdata.io/developers/api-documentation/nfl#pregame-and-period-game-odds-line-movement-sportsbook-group)** – pregame and period game odds line movement by sportsbook group
- **[Pregame and Period Game Odds Line Movement With Resulting Sportsbook Group](https://sportsdata.io/developers/api-documentation/nfl#pregame-and-period-game-odds-line-movement-with-resulting-sportsbook-group)** – pregame and period game odds line movement with resulting line by sportsbook group
- **[Pregame and Period Game Odds (By Week Sportsbook Group)](https://sportsdata.io/developers/api-documentation/nfl#pregame-and-period-game-odds--by-week-sportsbook-group)** – pregame and period game odds by week and sportsbook group
- **[Futures](https://sportsdata.io/developers/api-documentation/nfl#futures)** – futures betting markets (e.g. Super Bowl, MVP)
- **[Betting Futures (By Season)](https://sportsdata.io/developers/api-documentation/nfl#betting-futures--by-season)** – futures betting markets by season
- **[Betting Futures (By Season Sportsbook Group)](https://sportsdata.io/developers/api-documentation/nfl#betting-futures--by-season-sportsbook-group)** – futures betting markets by season and sportsbook group
- **[Props](https://sportsdata.io/developers/api-documentation/nfl#props)** – player and game prop betting lines
- **[Matchups Trends Splits](https://sportsdata.io/developers/api-documentation/nfl#matchups-trends-splits)** – matchup trends and splits (betting insights)
- **[Betting Splits (By Betting Market)](https://sportsdata.io/developers/api-documentation/nfl#betting-splits--by-betting-market)** – betting splits by betting market
- **[Betting Splits (By Game)](https://sportsdata.io/developers/api-documentation/nfl#betting-splits--by-game)** – betting splits by game
- **[Betting Trends (By Matchup)](https://sportsdata.io/developers/api-documentation/nfl#betting-trends--by-matchup)** – betting trends by matchup
- **[Betting Trends (By Team)](https://sportsdata.io/developers/api-documentation/nfl#betting-trends--by-team)** – betting trends by team
- **[Sportsbooks (Active)](https://sportsdata.io/developers/api-documentation/nfl#sportsbooks--active)** – active sportsbooks list
- **[Projections](https://sportsdata.io/developers/api-documentation/nfl#projections)** – fantasy player projections
- **[Projected Player Game Stats (By Team)](https://sportsdata.io/developers/api-documentation/nfl#projected-player-game-stats--by-team)** – projected player game stats by team
- **[Projected Player Game Stats (By Week)](https://sportsdata.io/developers/api-documentation/nfl#projected-player-game-stats--by-week)** – projected player game stats by week
- **[Projected Player Season Stats With ADP](https://sportsdata.io/developers/api-documentation/nfl#projected-player-season-stats-with-adp)** – projected player season stats with ADP (average draft position)
- **[Projected Player Season Stats With ADP (By Team)](https://sportsdata.io/developers/api-documentation/nfl#projected-player-season-stats-with-adp--by-team)** – projected player season stats with ADP by team
- **[IDP Projected Player Game Stats (By Team)](https://sportsdata.io/developers/api-documentation/nfl#idp-projected-player-game-stats--by-team)** – IDP (individual defensive player) projected game stats by team
- **[IDP Projected Player Game Stats (By Week)](https://sportsdata.io/developers/api-documentation/nfl#idp-projected-player-game-stats--by-week)** – IDP projected game stats by week
- **[Projected Fantasy Defense Game Stats With DFS Salaries](https://sportsdata.io/developers/api-documentation/nfl#projected-fantasy-defense-game-stats-with-dfs-salaries)** – projected fantasy defense game stats with DFS salaries
- **[Projected Fantasy Defense Season Stats With ADP](https://sportsdata.io/developers/api-documentation/nfl#projected-fantasy-defense-season-stats-with-adp)** – projected fantasy defense season stats with ADP (average draft position)
- **[DFS Slate Ownership Projections (By Slate)](https://sportsdata.io/developers/api-documentation/nfl#dfs-slate-ownership-projections--by-slate)** – DFS slate ownership projections by slate
- **[DFS Slate Ownership Projections (Upcoming)](https://sportsdata.io/developers/api-documentation/nfl#dfs-slate-ownership-projections--upcoming)** – upcoming DFS slate ownership projections
- **[Fantasy Player Ownership Percentages Season Long (By Week)](https://sportsdata.io/developers/api-documentation/nfl#fantasy-player-ownership-percentages-seasonlong--by-week)** – fantasy player ownership percentages (season-long) by week
- **[Salaries Stats Points](https://sportsdata.io/developers/api-documentation/nfl#salaries-stats-points)** – fantasy salaries, stats, and points
- **[Fantasy Defense Game Stats (All)](https://sportsdata.io/developers/api-documentation/nfl#fantasy-defense-game-stats--all)** – fantasy defense game stats (all)
- **[Fantasy Defense Game Stats (By Team)](https://sportsdata.io/developers/api-documentation/nfl#fantasy-defense-game-stats--by-team)** – fantasy defense game stats by team
- **[Fantasy Defense Season Stats (All)](https://sportsdata.io/developers/api-documentation/nfl#fantasy-defense-season-stats--all)** – fantasy defense season stats (all)
- **[Fantasy Defense Season Stats (By Team)](https://sportsdata.io/developers/api-documentation/nfl#fantasy-defense-season-stats--by-team)** – fantasy defense season stats by team
- **[Fantasy Points (By Week)](https://sportsdata.io/developers/api-documentation/nfl#fantasy-points--by-week)** – fantasy points by week
- **[DFS Slates (By Date)](https://sportsdata.io/developers/api-documentation/nfl#dfs-slates--by-date)** – DFS slates by date
- **[DFS Slates (By Week)](https://sportsdata.io/developers/api-documentation/nfl#dfs-slates--by-week)** – DFS slates by week
- **[News](https://sportsdata.io/developers/api-documentation/nfl#news)** – NFL news
- **[News (By Date)](https://sportsdata.io/developers/api-documentation/nfl#news--by-date)** – NFL news by date
- **[News (By Player)](https://sportsdata.io/developers/api-documentation/nfl#news--by-player)** – NFL news by player
- **[News (By Team)](https://sportsdata.io/developers/api-documentation/nfl#news--by-team)** – NFL news by team
- **[Premium News](https://sportsdata.io/developers/api-documentation/nfl#premium-news)** – premium NFL news
- **[Premium News (By Date)](https://sportsdata.io/developers/api-documentation/nfl#premium-news--by-date)** – premium NFL news by date
- **[Premium News (By Team)](https://sportsdata.io/developers/api-documentation/nfl#premium-news--by-team)** – premium NFL news by team
- **[Player News Notes](https://sportsdata.io/developers/api-documentation/nfl#player-news-notes)** – player news and notes
- **[Bye Weeks](https://sportsdata.io/developers/api-documentation/nfl#bye-weeks)** – team bye weeks by season
- **[Transactions (By Date)](https://sportsdata.io/developers/api-documentation/nfl#transactions--by-date)** – transactions (roster moves) by date
- **[Season (Current)](https://sportsdata.io/developers/api-documentation/nfl#season--current)** – current NFL season info
- **[Season (Upcoming)](https://sportsdata.io/developers/api-documentation/nfl#season--upcoming)** – upcoming NFL season info
- **[Timeframes](https://sportsdata.io/developers/api-documentation/nfl#timeframes)** – timeframes (e.g. for betting/scheduling)
- **[Week (Current)](https://sportsdata.io/developers/api-documentation/nfl#week--current)** – current NFL week info
- **[Week (Last Completed)](https://sportsdata.io/developers/api-documentation/nfl#week--last-completed)** – last completed NFL week info
- **[Week (Upcoming)](https://sportsdata.io/developers/api-documentation/nfl#week--upcoming)** – upcoming NFL week info
- **[Scores (Game State)](https://sportsdata.io/developers/api-documentation/nfl#scores-game-state)** – game state / score state info
- **[Games (By Date, Live & Final)](https://sportsdata.io/developers/api-documentation/nfl#games--by-date-live--final)** – games by date (live and final)
- **[Games (By Date, Final)](https://sportsdata.io/developers/api-documentation/nfl#games--by-date-final)** – final score games by date
- **[Games (By Season, Live & Final)](https://sportsdata.io/developers/api-documentation/nfl#games--by-season-live--final)** – games by season (live and final)
- **[Games (By Season, Final)](https://sportsdata.io/developers/api-documentation/nfl#games--by-season-final)** – final score games by season
- **[Games (By Week, Final)](https://sportsdata.io/developers/api-documentation/nfl#games--by-week-final)** – final score games by week
- **[Schedules](https://sportsdata.io/developers/api-documentation/nfl#schedules)** – full season/week schedules
- **[Schedules (Game Day Info)](https://sportsdata.io/developers/api-documentation/nfl#schedules-game-day-info)** – game-day schedule info

Use `SportsDataIOConfig.scoresURL(league: "nfl", pathComponent: "...")` or the appropriate path for the feed (e.g. standings may live under a different base path in their API). Check the [NFL Data Dictionary](https://sportsdata.io/developers/data-dictionary/nfl) and [Workflow Guide](https://sportsdata.io/developers/workflow-guide/nfl) for exact URLs and response shapes.

## 5. Other sports (later)

Support for other leagues (NBA, NHL, MLB, etc.) via Sports Data IO is planned. For now the app uses Sports Data IO only for **NFL**. When adding other sports, use the same **Ocp-Apim-Subscription-Key** and each league’s base URL and docs (e.g. [NBA](https://sportsdata.io/developers/api-documentation/nba), [NHL](https://sportsdata.io/developers/api-documentation/nhl), [MLB](https://sportsdata.io/developers/api-documentation/mlb)).

## 6. Troubleshooting

- **401 Unauthorized:** Key missing or wrong. Double‑check **SportsDataIOApiKey** in Info.plist and that the key is active in your Sports Data IO account.
- **No games / no score:** For NFL, the app requests **ScoresByDate** for today. If there are no games today, the request may return an empty array and the app falls back to ESPN. Try on a day when NFL games are scheduled.
- **Wrong field names:** If the API returns different JSON keys (e.g. camelCase vs PascalCase), the parser in `SportsDataIOService` supports common variants; if your feed differs, add the needed keys in `parseNFLScoresResponse` and `parseTeam`.
