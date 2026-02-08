# Square Up — App Flow (Mermaid)

This document describes how the Square Up app works and the complete user/system flow using Mermaid flowcharts.

---

## 1. App entry and onboarding

```mermaid
flowchart TD
    subgraph Launch["App launch"]
        A[SquareUpApp starts] --> B[AppDelegate: HapticService.prepare]
        B --> C[ContentView with AppState]
        C --> D{hasCompletedOnboarding?}
    end
    D -->|No| E[fullScreenCover: InstructionsView]
    D -->|Yes| F[TabView: main app]
    E --> G[Onboarding steps]
    G --> G1[Step 0: Sign in to sync - Apple / Google / Email or Skip]
    G1 --> G2[Step 1: Create or scan a pool]
    G2 --> G3[Step 2: Set your name]
    G3 --> G4[Step 3: Watch live scores]
    G4 --> G5[Step 4: Stay in the loop - notifications]
    G5 --> G6[Step 5: See who wins]
    G6 --> H[User taps Get Started]
    H --> I[appState.completeOnboarding]
    I --> F
    F --> J[scoreService.startLiveUpdates]
    F --> K[NotificationService.requestPermissionAndRegister]
```

---

## 2. Main app structure (tabs)

```mermaid
flowchart LR
    subgraph Tabs["Main TabView"]
        T0[Live - DashboardView]
        T1[Pools - PoolsListView]
        T2[My Boxes - MySquaresView]
        T3[Settings - SettingsView]
    end
    T0 --> D[Next game score, Your Pools selector, On the Hunt, Current Leader / Winnings]
    T1 --> P[Add Pool options + list of My Pools]
    T2 --> M[Your boxes across pools, stats]
    T3 --> S[Profile, Account, Notifications, Join pool, Share My Pools, Erase data, About]
```

---

## 3. Adding a pool (high-level)

```mermaid
flowchart TD
    subgraph Entry["User wants to add a pool"]
        A[Tap Add Pool / + / empty state]
        A --> B{How?}
    end
    B --> C[Scan Pool Sheet]
    B --> D[Create New Pool]
    B --> E[Create from Game]
    B --> F[Join with Code]
    C --> C1[ScannerView]
    D --> D1[NewPoolSheet - manual grid]
    E --> E1[CreateFromGameView]
    F --> F1[JoinPoolSheet]
    C1 --> SAVE[appState.addPool]
    D1 --> SAVE
    E1 --> E2[EnterMyNumbersView]
    E2 --> SAVE
    F1 --> F2[ClaimYourSquaresView]
    F2 --> SAVE
    SAVE --> POOLS[Pool appears in Pools list & Live]
```

---

## 4. Scan pool sheet flow (detail)

```mermaid
flowchart TD
    subgraph Scan["ScannerView"]
        S0[Select game for scan - sport, pick game or Skip]
        S0 --> S1[Idle: Camera | Photo library | Manual entry]
        S1 --> |Camera| S2[CameraView - capture]
        S1 --> |Photo| S3[PhotosPicker - pick image]
        S1 --> |Manual| S4[ManualEntryView]
        S2 --> S5[handleCapturedImage]
        S3 --> S5
        S5 --> S6[Enter name as on sheet + optional pool name]
        S6 --> S7[Start OCR]
        S7 --> S8[Processing - VisionService or AIGrid backend]
        S8 --> S9{Success?}
        S9 -->|Yes| S10[ReviewScanView]
        S9 -->|No| S11[Error - Retry or Manual entry]
        S11 --> S1
        S11 --> S4
        S10 --> S12[Edit pool name, teams, numbers, grid]
        S12 --> S13[Payout rules: type / Speak / Photo]
        S13 --> S14[Optional: Parse with AI - PayoutParseService]
        S14 --> S15[Confirm & Save or Retry Scan]
        S15 --> S16[onPoolScanned - add pool, dismiss]
    end
```

---

## 5. Join pool with code flow

```mermaid
flowchart TD
    subgraph Join["Join with code"]
        J0[JoinPoolSheet]
        J0 --> J1[Enter 8-char invite code]
        J1 --> J2[Tap Join Pool]
        J2 --> J3[SharedPoolsService.fetchPool]
        J3 --> J4{Success?}
        J4 -->|No| J5[Show error]
        J5 --> J1
        J4 -->|Yes| J6[joinedPool = pool]
        J6 --> J7[ClaimYourSquaresView]
        J7 --> J8[Rules/payout already from host]
        J8 --> J9[Select name from grid OR type name OR manual boxes]
        J9 --> J10[Confirm]
        J10 --> J11[appState.addPool - dismiss]
    end
```

---

## 6. Create from game flow

```mermaid
flowchart TD
    subgraph FromGame["Create from game"]
        G0[CreateFromGameView]
        G0 --> G1[Pick sport - NFL etc]
        G1 --> G2[GamesService.fetchGames - upcoming games]
        G2 --> G3[User taps a game]
        G3 --> G4[EnterMyNumbersView]
        G4 --> G5[Enter numbers for each team 0-9, pool name, your name]
        G5 --> G6[Optional: payout rules]
        G6 --> G7[Save]
        G7 --> G8[appState.addPool]
    end
```

---

## 7. After a pool exists — Live & scores

```mermaid
flowchart TD
    subgraph Live["Live tab & score updates"]
        L0[scoreService.startLiveUpdates - NFLScoreService]
        L0 --> L1[SportsData.io or ESPN - current/next game]
        L1 --> L2[Score arrives - currentScore]
        L2 --> L3[onChange: refreshWinnersFromCurrentScore]
        L3 --> L4[For each pool: updateWinners from quarter/total score]
        L4 --> L5[Save pools if winners changed]
        L5 --> L6[GameContextService.review]
        L6 --> L7[Notifications: leader, period winner, on the hunt]
        L7 --> L8[Dashboard shows: Live score card, Pool selector, On the Hunt, Current Leader / Winnings]
    end
```

---

## 8. Grid detail (viewing/editing a pool)

```mermaid
flowchart TD
    subgraph Grid["GridDetailView"]
        GD0[User taps pool in Pools list]
        GD0 --> GD1[GridDetailView - binding to pool]
        GD1 --> GD2[Show pool structure & payout summary]
        GD2 --> GD3[10x10 grid - column/row numbers, names]
        GD3 --> GD4[Winning square highlighted from current score]
        GD4 --> GD5[Toolbar: Edit pool, Share Grid, Delete]
        GD5 --> |Edit| GD6[Edit sheet - name, teams, numbers, full grid editor]
        GD5 --> |Share Grid| GD7[Export grid as image - system share sheet]
        GD5 --> |Delete| GD8[Confirm - appState.removePool]
    end
```

*Invite codes are generated from **Settings → Share My Pools** (see section 9a).*

---

## 9. Settings and account

```mermaid
flowchart TD
    subgraph Settings["SettingsView"]
        SV0[Profile: Your name - used to highlight your boxes]
        SV0a[Profile/name carried over from sign-in when empty - Apple/Google displayName or email local part]
        SV1[Account: if signed out → Sign in to sync - sheet with Apple / Google / Email]
        SV1a[Account: if signed in → provider icon + name/email + Sign Out]
        SV1b[Sign-in sheet dismisses when currentUser is set; AppState forwards auth changes]
        SV2[Notifications toggles]
        SV3[Join pool with code]
        SV4[Share My Pools - list of pools, tap to get invite code]
        SV5[Erase all data - confirm then clear pools, myName, sign out]
        SV6[About: How it works, About Square Up, Version]
        SV3 --> JoinPoolSheet
        SV4 --> SharePoolSheet
    end
```

---

## 9a. Share pool (invite code) flow

```mermaid
flowchart TD
    subgraph Share["Generate & share invite code"]
        SH0[Settings → Share My Pools → tap a pool]
        SH0 --> SH1[SharePoolSheet opens - Square Up logo, pool name]
        SH1 --> SH2{Code exists?}
        SH2 -->|No| SH3[SharedPoolsService.uploadPool - POST to Supabase shared_pools]
        SH3 --> SH4[8-char code returned, stored in pool.sharedCode]
        SH2 -->|Yes| SH5[Show existing code]
        SH4 --> SH5
        SH5 --> SH6[Copy Code / Message / Email / More]
        SH6 --> SH7[Message, Email, More open system share sheet with invite text]
        SH7 --> SH8[Recipient gets: pool name, Invite Code, instructions to join]
    end
```

---

## 10. Data and backend dependencies

```mermaid
flowchart LR
    subgraph App["SquareUp app"]
        UI[Views]
        AS[AppState]
        AUTH[AuthService: Apple/Google/Email, currentUser, recordLogin]
        UI --> AS
        AS --> AUTH
    end
    subgraph Local["Local"]
        UD[UserDefaults: savedPools, myName, hasCompletedOnboarding, authUser]
        AS --> UD
    end
    AUTH --> LD
    subgraph Backends["Optional backends"]
        AI[AIGridConfig - Lambda/Claude for grid scan]
        TX[TextractConfig - fallback OCR]
        PP[PayoutParseConfig - parse payout rules]
        SP[SharedPoolsConfig - Supabase shared_pools]
        LD[LoginDatabaseConfig - Supabase logins]
    end
    subgraph External["External APIs"]
        SD[SportsData.io - NFL games/scores]
        ESPN[ESPN - fallback scores]
    end
    AS --> AI
    AS --> TX
    AS --> PP
    AS --> SP
    AS --> LD
    AS --> SD
    AS --> ESPN
```

---

## 11. End-to-end flow summary

```mermaid
flowchart TB
    Start([App open]) --> Onboard{First time?}
    Onboard -->|Yes| O[Onboarding: Sign in, Create/scan, Name, Scores, Notifications, Winners]
    Onboard -->|No| Main[Main app]
    O --> Main
    Main --> Live[Live: next game, pools, on the hunt, leader]
    Main --> Pools[Pools: add or list pools]
    Main --> Boxes[My Boxes: your squares]
    Main --> Set[Settings: profile, account, join code, share pools, erase]
    Set --> NameCarry[When signed in: name from login carries to Profile if empty]
    Pools --> Add{Add pool}
    Add --> Scan[Scan sheet → OCR/AI → Review → Payout rules → Save]
    Add --> Create[Create new / from game → Enter numbers → Save]
    Add --> Join[Join code → Claim boxes → Save]
    Scan --> Saved[Pool saved]
    Create --> Saved
    Join --> Saved
    Saved --> Live
    Saved --> Pools
    Live --> Score[Score updates → refresh winners → notifications]
    Pools --> Grid[Tap pool → Grid detail → Edit / Share grid image / Delete]
    Set --> SharePools[Share My Pools → invite code → Message/Email/More]
```

---

*Square Up — pool sheets, live scores, and payouts.*
