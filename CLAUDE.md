# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter app for reading novels from the Syosetu platform (小説家になろう). The app provides features for searching, ranking, bookmarking, and reading web novels with offline storage capabilities.

## Development Commands

### Build and Test Commands
```bash
# Get dependencies
flutter pub get

# Run code generation for Hive models
dart run build_runner build

# Run the app (development)
flutter run

# Build for production
flutter build apk --release
flutter build ios --release

# Run tests
flutter test

# Analyze code
flutter analyze
```

### Code Generation
When modifying Hive models (files with `@HiveType` annotations), run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Architecture Overview

### Core Structure
- **MVVM Pattern**: Uses Provider for state management with ViewModels
- **Local Storage**: Hive for offline data persistence (novels, bookmarks, reading history)
- **API Integration**: Custom API service for Syosetu platform
- **WebView**: For reading novels directly from the web

### Key Directories
```
lib/
├── models/          # Hive data models with code generation
├── services/        # API and database services
├── providers/       # Theme and state providers
├── viewmodels/      # Business logic and state management
├── views/
│   ├── screens/     # Full-screen pages
│   └── tabs/        # Tab components
└── utils/           # Constants and helpers
```

### Data Models (Hive)
All models use Hive for local storage:
- `Novel`: Main novel data structure
- `Bookmark`: User bookmarks with reading position
- `ReadingHistory`: Reading progress tracking
- Generated files (*.g.dart) are auto-generated - do not edit manually

### API Service Architecture
- **ApiService**: Handles Syosetu API calls with caching
- **DatabaseHelper**: Manages all local Hive operations
- Supports both regular and R18 content APIs
- Implements request timeouts and error handling

### State Management
- Uses Provider pattern with ChangeNotifier
- ViewModels handle business logic and API calls
- Theme management through ThemeProvider

### Navigation Structure
Main app uses TabBar with:
1. Reading List (bookmarks/history)
2. Rankings (daily/weekly/monthly)
3. Reviews (sample data)
4. Search (with R18 toggle)
5. Settings

### WebView Integration
- Custom WebView implementation for reading
- Automatic scroll position saving
- Chapter progress tracking
- Page load event handling

## Key Features to Understand

### Novel URL Handling
- Supports both serial and single-chapter novels
- URL patterns: `https://ncode.syosetu.com/{novelId}/{chapter}/`
- R18 content uses `novel18.syosetu.com` domain

### Reading Position Tracking
- Automatic scroll position saving
- Chapter progress tracking
- Last viewed timestamp updates
- Both bookmark and history systems maintain position

### Search and Ranking
- Genre-based filtering
- Multiple ranking types (daily, weekly, monthly, quarterly)
- Caching system for API responses
- Search supports keywords, genre filtering, and exclusions

### Theme System
- Light/dark theme support
- User preference persistence
- Material Design 3 color schemes

## Database Operations

All database operations go through DatabaseHelper:
- Bookmark management with position tracking
- Reading history with automatic cleanup (keeps latest 100)
- Novel metadata storage
- Statistics and data management

## API Integration Notes

- Syosetu API has rate limiting - use built-in caching
- Handle both JSON and non-JSON responses gracefully
- Always include proper User-Agent headers
- Timeout handling for network requests
- Support for both general and R18 APIs

## WebView Considerations

- Custom JavaScript injection for better reading experience
- Page load event monitoring
- Progress tracking and position restoration
- Mobile-optimized reading interface