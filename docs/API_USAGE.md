# API and service usage

Where each API and service is used so they stay wired and notifications stay contextual.

## Score and game data

| API / service | Where used | Purpose |
|---------------|------------|--------|
| **NFLScoreService** | `AppState.refreshWinnersFromCurrentScore()` (triggered by `ContentView` on `scoreService.lastUpdated`) | Live score; drives winner state and `GameContextService.review()`. |
| **SportsDataIO** | `NFLScoreService.fetchScoreFromAPI()` (when `SportsDataIOConfig.isConfigured`) | Primary source for NFL score when API key is set. |
| **ESPN scoreboard** | Same flow, fallback when Sports Data IO not configured or fails | Fallback score source. |
| **GamesService** | `CreateFromGameView` | List of games to create a pool from (team + structure). |

Score updates run on a timer (e.g. every 30s) and on manual refresh. Each update:

1. Updates pool winners from current score.
2. Calls `GameContextService.review()` with current score, previous score, pools, and `myName`.

## Notifications (local)

**NotificationService** is used only by **GameContextService**. No other code schedules local notifications.

When `GameContextService.review()` runs, it can schedule local notifications for:

1. **You’re leading** – Your square is the current winner in a pool.
2. **Period winner** – A quarter, halftime, or final just ended; who won that period (and for Final, the score).
3. **One score away** – A square of yours would win if one team’s last digit changed by one. Messages are contextual, e.g.:
   - “Mike just needs one more score from Seattle to take Q3 in My Pool.”
   - Uses pool + score (team names, period) from the same APIs above.

All of this uses the **current score and quarter** from `NFLScoreService` (SportsDataIO or ESPN), so notifications stay in sync with what’s on screen.

## Login / backend

| API / service | Where used | Purpose |
|---------------|------------|--------|
| **LoginDatabaseService** | `AuthService` after sign-in / sign-out | Sends login/logout events to configurable backend (see `docs/LOGIN_DATABASE.md`). |

## Push (remote) notifications

- **APNs**: Permission and device token registration in `NotificationService`; token stored and can be sent to your backend.
- **Backend**: Not in this repo. You can use the device token + score/pool data to send push notifications (e.g. “Mike just needs one more score from Seattle to take Q3”) from your server using the same logic as `GameContextService.oneScoreAwayMessage(...)`.

## Adding more contextual copy

To add more “what needs to happen to win” copy:

- **Local**: Extend `GameContextService.review()` and `oneScoreAwayMessage` (e.g. different titles, or extra notifications for “two scores away”).
- **Remote**: Reuse the same score + pool + period data and similar message formatting in your push backend.
