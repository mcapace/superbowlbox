# GridIron - Super Bowl Squares App

A modern iOS app for managing Super Bowl box pools (squares) with real-time score tracking.

## Features

### Core Features
- **Smart Scanning**: Use your camera to scan physical pool sheets with OCR technology (Vision framework)
- **Live Scores**: Real-time NFL score updates during the game via ESPN API
- **Multiple Pools**: Manage multiple box pools in one place
- **Winner Tracking**: Automatically highlights winning squares based on current score
- **My Squares**: Quickly find all your squares across pools

### Pool Management
- **Create Pools**: Build pools manually with a step-by-step wizard
- **Scan Sheets**: Import existing pool sheets via camera or photo library
- **Share Pools**: Generate invite codes to share with friends
- **Join Pools**: Enter invite codes to join shared pools

### User Experience
- **Beautiful UI**: Modern SwiftUI design with smooth animations
- **Dark Mode**: Full support for light and dark modes
- **Responsive Grid**: Zoomable grid view with player details
- **Quick Stats**: At-a-glance stats for your squares and wins

## Screenshots

The app features:
1. **Dashboard** - Live score display with current winner spotlight
2. **Grid View** - Interactive 10x10 grid with team numbers
3. **My Squares** - Search and view all your squares
4. **Settings** - Profile, sharing, and app configuration

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository
2. Open `SuperBowlBox.xcodeproj` in Xcode
3. Build and run on your device or simulator

## Project Structure

```
SuperBowlBox/
├── SuperBowlBoxApp.swift      # App entry point
├── ContentView.swift          # Main tab view and dashboard
├── Info.plist                 # App configuration
├── Models/
│   ├── BoxGrid.swift          # Main pool grid model
│   ├── BoxSquare.swift        # Individual square model
│   ├── GameScore.swift        # Score tracking model
│   └── Team.swift             # NFL team model
├── Views/
│   ├── GridView.swift         # Full grid detail view
│   ├── PoolsListView.swift    # Pool management list
│   ├── MySquaresView.swift    # User's squares view
│   ├── ScannerView.swift      # OCR scanning interface
│   ├── ManualEntryView.swift  # Manual pool creation
│   ├── SettingsView.swift     # App settings
│   ├── CameraViewController.swift  # Camera capture
│   ├── ScoreOverlayView.swift # Live score overlay
│   └── SquareDetailView.swift # Square detail sheet
├── ViewModels/
│   └── GridViewModel.swift    # Grid business logic
├── Services/
│   ├── VisionService.swift    # OCR text recognition
│   └── NFLScoreService.swift  # Live score fetching
└── Resources/
    └── Assets.xcassets/       # App icons and colors
```

## How It Works

### Super Bowl Squares Rules
1. A 10x10 grid creates 100 squares
2. Each column is assigned a number 0-9 (one team)
3. Each row is assigned a number 0-9 (other team)
4. At the end of each quarter, check the last digit of each team's score
5. The square at the intersection of those two numbers wins

### Using the App
1. **Create or Scan a Pool**: Start fresh or scan an existing sheet
2. **Set Your Name**: Go to Settings to set your name for highlighting
3. **Watch the Game**: Scores update automatically during the game
4. **Track Winners**: See who's winning in real-time

## Technologies Used

- **SwiftUI**: Modern declarative UI framework
- **Vision Framework**: OCR text recognition for scanning
- **AVFoundation**: Camera capture functionality
- **Combine**: Reactive data flow
- **ESPN API**: Live NFL score data

## Future Enhancements

- [ ] Cloud sync for shared pools
- [ ] Push notifications for quarter wins
- [ ] Historical game data
- [ ] Payout calculator
- [ ] Widget support

## License

MIT License - Feel free to use and modify for your own projects.

---

Made with love for football fans. Go team!
