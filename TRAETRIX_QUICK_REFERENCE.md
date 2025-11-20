# TraeTrix Quick Reference Guide

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Dart SDK
- Chrome browser for web development
- Git for version control

### Project Setup
```bash
# Navigate to TraeTrix project
cd /path/to/traetrix

# Install dependencies
flutter pub get

# Generate JSON serialization code
flutter packages pub run build_runner build

# Run the app
flutter run -d chrome
```

### Current Preview URL
🌐 **Live Preview**: http://127.0.0.1:51410/t7jJip3uENs=

## 📁 Key File Locations

### Core Files
| File | Purpose | Status |
|------|---------|--------|
| `lib/main.dart` | App entry point | ✅ Complete |
| `lib/models/card.dart` | Card model with JSON serialization | ✅ Complete |
| `lib/models/player.dart` | Player model with game state | ✅ Complete |
| `lib/models/game.dart` | Game logic and state management | ✅ Complete |
| `lib/core/constants/game_constants.dart` | Game rules and constants | ✅ Complete |
| `lib/core/utils/game_utils.dart` | Utility functions | ✅ Complete |

### UI Files
| File | Purpose | Status |
|------|---------|--------|
| `lib/ui/themes/app_theme.dart` | Design system and styling | ✅ Complete |
| `lib/ui/screens/main_menu_screen.dart` | Main menu with animations | ✅ Complete |
| `lib/ui/screens/single_player_screen.dart` | Single player setup | ✅ Complete |
| `lib/ui/screens/multiplayer_lobby_screen.dart` | Multiplayer placeholder | ✅ Complete |
| `lib/ui/widgets/animated_background.dart` | Animated background widget | ✅ Complete |
| `lib/ui/widgets/menu_button.dart` | Custom menu button | ✅ Complete |

### Files to Create Next
| File | Purpose | Priority |
|------|---------|----------|
| `lib/ui/screens/game_screen.dart` | Main game interface | 🔥 High |
| `lib/ui/widgets/card_widget.dart` | Individual card display | 🔥 High |
| `lib/providers/game_provider.dart` | State management | 🔥 High |
| `lib/services/ai_engine.dart` | AI decision making | 🔥 High |

## 🎨 Design System Quick Reference

### Colors
```dart
// Primary colors
AppTheme.primaryColor      // #2E7D32 (Green)
AppTheme.backgroundColor   // #0D1B2A (Dark blue)
AppTheme.textPrimary      // #FFFFFF (White)

// Card suit colors
AppTheme.heartColor       // #E53935 (Red)
AppTheme.spadeColor       // #212121 (Black)
```

### Text Styles
```dart
AppTheme.titleStyle       // 32px, bold
AppTheme.subtitleStyle    // 20px, semi-bold
AppTheme.bodyStyle        // 16px, normal
AppTheme.buttonStyle      // 16px, semi-bold
```

### Dimensions
```dart
AppTheme.borderRadius     // 12.0
AppTheme.spacing          // 16.0
AppTheme.cardWidth        // 60.0
AppTheme.cardHeight       // 84.0
```

## 🎮 Game Logic Quick Reference

### Card Model
```dart
// Create a card
Card card = Card(suit: Suit.hearts, rank: Rank.ace);

// Check card properties
card.value              // Numeric value for game logic
card.isKingOfHearts     // Special card check
card.displayName        // Human-readable name
card.assetPath          // Path to card image
```

### Player Model
```dart
// Create a player
Player player = Player(
  id: 'player1',
  name: 'John',
  type: PlayerType.human,
);

// Manage player state
player.addCard(card);     // Add card to hand
player.playCard(card);    // Play a card
player.updateScore(10);   // Update score
```

### Game Model
```dart
// Create a game
Game game = Game(players: [player1, player2, player3, player4]);

// Game operations
game.dealCards();         // Deal cards to players
game.playCard(card);      // Play a card in current trick
game.finishTrick();       // Complete current trick
game.calculateScores();   // Calculate round scores
```

## 🛠️ Development Commands

### Flutter Commands
```bash
# Hot reload (while running)
r

# Hot restart (while running)
R

# Clear screen (while running)
c

# Quit app (while running)
q

# Analyze code
flutter analyze

# Format code
flutter format .

# Run tests
flutter test
```

### Build Commands
```bash
# Build for web
flutter build web

# Build for Android
flutter build apk

# Build for iOS
flutter build ios
```

## 🔧 Common Tasks

### Adding a New Screen
1. Create file in `lib/ui/screens/`
2. Import necessary dependencies
3. Extend `StatefulWidget` or `StatelessWidget`
4. Use `AppTheme` for consistent styling
5. Add navigation in existing screens

### Adding a New Widget
1. Create file in `lib/ui/widgets/`
2. Make it reusable with parameters
3. Follow existing naming conventions
4. Document public APIs

### Adding a New Model
1. Create file in `lib/models/`
2. Add JSON serialization annotations
3. Run build_runner to generate code
4. Add validation if needed

### Adding Dependencies
1. Add to `pubspec.yaml`
2. Run `flutter pub get`
3. Import in relevant files
4. Update documentation

## 🐛 Debugging Tips

### Common Issues
- **Build errors**: Check `flutter doctor` for setup issues
- **Hot reload not working**: Try hot restart (R)
- **JSON serialization errors**: Run build_runner again
- **Theme not applied**: Check MaterialApp theme configuration

### Debug Tools
- **Flutter Inspector**: Widget tree visualization
- **Dart DevTools**: Performance and memory profiling
- **Chrome DevTools**: Web-specific debugging
- **Print statements**: Use `debugPrint()` for logging

## 📱 Testing

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/models/card_test.dart

# Run with coverage
flutter test --coverage
```

### Test Structure
```dart
void main() {
  group('Card Model Tests', () {
    test('should create card with correct properties', () {
      // Test implementation
    });
  });
}
```

## 🚀 Deployment

### Web Deployment
```bash
# Build for production
flutter build web --release

# Deploy to hosting service
# (Copy build/web/ contents to web server)
```

### Mobile Deployment
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release
```

## 📚 Resources

### Documentation
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Provider Package](https://pub.dev/packages/provider)
- [JSON Serialization](https://flutter.dev/docs/development/data-and-backend/json)

### Project Documents
- `TRAETRIX_PROJECT_PROGRESS.md` - What's been completed
- `TRAETRIX_NEXT_STEPS.md` - Development roadmap
- `TRAETRIX_ARCHITECTURE.md` - Technical architecture

## 🎯 Current Status Summary

### ✅ Completed (Ready to Use)
- Project setup and dependencies
- Core models with JSON serialization
- UI theme and design system
- Main menu with animations
- Single player setup screen
- Navigation between screens
- App running successfully on Chrome

### 🚧 Next Priorities
1. **Game Screen Implementation** - Main gameplay interface
2. **AI Engine** - Computer player logic
3. **Game Logic Integration** - Connect UI to game models
4. **Multiplayer Server** - WebSocket-based multiplayer

### 📊 Progress
- **Phase 1 (UI Foundation)**: ✅ 100% Complete
- **Phase 2 (Game Logic)**: 🚧 0% Complete
- **Phase 3 (Multiplayer)**: ⏳ 0% Complete
- **Phase 4 (Polish)**: ⏳ 0% Complete

---

*Quick Reference Version: 1.0*
*Last Updated: January 2025*
*Keep this document updated as development progresses*