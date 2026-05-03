# Prezzi Benzina - Setup & Running Instructions

## Quick Start (5 minutes)

### Step 1: Prerequisites
```bash
# Check Flutter installation
flutter doctor

# Should show: Flutter, Dart, Android Studio/Xcode, etc. ✓
```

### Step 2: Install Dependencies
```bash
cd /Users/pietro/Desktop/App\ test/MappaPrezziBenzina
flutter pub get
```

### Step 3: Setup Firebase

**Option A: Using FlutterFire CLI (Recommended)**

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Run configuration wizard
flutterfire configure \
  --project=prezzi-benzina \
  --ios-bundle-id=com.example.mappaPrezziBenzina \
  --android-package-name=com.example.mappa_prezzi_benzina

# This creates firebase_options.dart automatically
```

**Option B: Manual Setup**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project: **prezzi-benzina**
3. Add iOS app:
   - Bundle ID: `com.example.mappaPrezziBenzina`
   - Download `GoogleService-Info.plist`
   - Copy to `ios/Runner/`
4. Add Android app:
   - Package name: `com.example.mappa_prezzi_benzina`
   - Download `google-services.json`
   - Copy to `android/app/`
5. Update `lib/firebase_options.dart` with your API keys

### Step 4: Firebase Security Rules

In Firebase Console → Firestore Database → Rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /gas_stations/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth.uid == uid;
    }
  }
}
```

### Step 5: Enable Authentication

1. Go to Firebase Console → Authentication
2. Enable providers:
   - Email/Password
   - Anonymous

### Step 6: Sample Data

Add sample gas stations to Firestore (optional):

```bash
# Import via Firebase Console or use this script:
dart run lib/scripts/seed_database.dart
```

Or manually add via Firebase Console:
```json
Collection: gas_stations
Document: station_001
{
  "name": "Q8 SELF SERVICE",
  "address": "Via Roma 123, 00100 Roma",
  "location": {
    "latitude": 41.9028,
    "longitude": 12.4964
  },
  "prices": {
    "Benzina": 1.599,
    "Diesel": 1.499
  },
  "lastUpdated": null
}
```

### Step 7: Run the App

```bash
# For iOS (macOS)
flutter run -t lib/main.dart

# For Android
flutter run -t lib/main.dart

# For Web
flutter run -d chrome

# For all platforms
flutter run
```

## Platform-Specific Setup

### iOS Setup

```bash
# Update pods
cd ios
rm Podfile.lock
pod install --repo-update
cd ..

# Run
flutter run
```

**iOS Info.plist** (`ios/Runner/Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby gas stations</string>
```

### Android Setup

**AndroidManifest.xml** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

### Web Setup

```bash
flutter run -d chrome
# Or
flutter run -d firefox
```

## Running the App

### Development Mode
```bash
flutter run
# Hot reload: Press 'r'
# Hot restart: Press 'R'
# Quit: Press 'q'
```

### Release Mode
```bash
# iOS
flutter build ios --release
open build/ios/iphoneos/Runner.app

# Android
flutter build apk --release
flutter build appbundle --release

# Web
flutter build web --release
```

### Profiling & Debug

```bash
# Debug mode
flutter run -d <device_id> --debug

# Profile mode (performance)
flutter run -d <device_id> --profile

# Verbose logging
flutter run -v

# Device list
flutter devices
```

## Testing

```bash
# Run all tests
flutter test

# Run specific test
flutter test test/presentation/bloc/map_bloc_test.dart

# Generate coverage
flutter test --coverage
```

## Building APK/IPA

### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Google Play)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS Archive
```bash
flutter build ios --release
# Follow Xcode steps to generate .ipa
```

## Troubleshooting

### Issue: Gradle build fails

```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

### Issue: Pod install fails (iOS)

```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
flutter run
```

### Issue: Firebase not initializing

```bash
# Check firebase_options.dart
# Verify API keys in Firebase Console
# Check platform-specific config files:
# - iOS: GoogleService-Info.plist
# - Android: google-services.json
```

### Issue: Location permission denied

**iOS**:
- Settings → App → Prezzi Benzina → Location → "While Using"

**Android**:
- App Settings → Permissions → Location → Allow

### Issue: Map not loading

```bash
# Check OpenStreetMap availability
# Try different tile provider in MapOptions
# Check internet connection
flutter clean && flutter run
```

## Development Commands

```bash
# Format code
dart format lib/

# Analyze code
dart analyze

# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Clean all
flutter clean && flutter pub get

# Generate code (for JSON serialization)
flutter pub run build_runner build
```

## VS Code Debug Launch Config

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "console": "integratedTerminal"
    }
  ]
}
```

## Android Studio Debug Launch Config

1. Run → Edit Configurations
2. Add new Flutter configuration
3. Select `lib/main.dart` as entry point
4. Click Run

## Next Steps After Running

1. **Sign In**: Use email/password or guest
2. **Allow Location**: Grant location permission
3. **Explore Map**: See nearby gas stations
4. **Test Filters**: Try fuel type and sort filters
5. **View Details**: Tap station to see prices
6. **Submit Prices**: Update prices (authenticated users)

## API & Data

### OpenStreetMap Tiles
- Free, open-source map tiles
- No API key required
- Documentation: https://wiki.openstreetmap.org/

### MIMIT API (Italian Fuel Prices)
- Endpoint: `https://dati.mise.gov.it/api/3/action`
- Dataset: Prezzo medio nazionale dei carburanti
- Updates: Daily

## Performance Tips

- Use Release mode for testing: `flutter run --release`
- Enable VM service: `flutter run --profile`
- Check frame rate: DevTools → Performance
- Monitor memory: DevTools → Memory

## Publishing

### To Google Play Store
```bash
flutter build appbundle --release
# Upload to Google Play Console
```

### To Apple App Store
```bash
flutter build ios --release
# Archive in Xcode and upload to App Store Connect
```

### To Web
```bash
flutter build web --release
# Deploy from build/web/ to hosting service
```

## Support & Documentation

- Flutter Docs: https://flutter.dev/docs
- Firebase Docs: https://firebase.flutter.dev/
- BLoC Library: https://bloclibrary.dev/
- OpenStreetMap: https://wiki.openstreetmap.org/

## Tips & Best Practices

✅ **Do's**:
- Use BLoC for state management
- Follow Clean Architecture pattern
- Test on real devices before releasing
- Keep dependencies updated
- Use ProGuard/R8 for Android release

❌ **Don'ts**:
- Don't hardcode API keys
- Don't skip permission requests
- Don't ignore BLoC state changes
- Don't use BuildContext across async gaps
- Don't build on unstable branches

---

**Happy coding!** 🚀
