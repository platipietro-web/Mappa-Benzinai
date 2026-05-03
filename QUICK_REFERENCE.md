# Prezzi Benzina - Quick Reference Guide

## File Structure

```
MappaPrezziBenzina/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── firebase_options.dart        # Firebase config
│   │
│   ├── core/
│   │   ├── constants/constants.dart # App constants
│   │   ├── errors/                  # Exceptions & failures
│   │   ├── utils/logger.dart        # Logging utility
│   │   └── services/service_locator.dart  # Dependency injection
│   │
│   ├── data/
│   │   ├── datasources/             # External integrations
│   │   │   ├── location_service.dart
│   │   │   ├── auth_service.dart
│   │   │   ├── firestore_service.dart
│   │   │   └── fuel_price_api.dart
│   │   ├── models/                  # Data models
│   │   │   ├── gas_station_model.dart
│   │   │   └── price_update_model.dart
│   │   └── repositories/            # Repository implementations
│   │       ├── gas_station_repository_impl.dart
│   │       ├── location_repository_impl.dart
│   │       └── auth_repository_impl.dart
│   │
│   ├── domain/
│   │   ├── entities/                # Business objects
│   │   │   ├── gas_station.dart
│   │   │   ├── user_location.dart
│   │   │   └── price_update.dart
│   │   └── repositories/            # Repository interfaces
│   │       └── repositories.dart
│   │
│   └── presentation/
│       ├── bloc/                    # State management
│       │   ├── map_bloc.dart
│       │   ├── location_bloc.dart
│       │   └── auth_bloc.dart
│       ├── pages/                   # Full screens
│       │   ├── map_page.dart
│       │   ├── station_detail_page.dart
│       │   └── auth_page.dart
│       ├── widgets/                 # Reusable components
│       │   ├── station_card.dart
│       │   └── filter_bottom_sheet.dart
│       └── theme/
│           └── app_theme.dart
│
├── pubspec.yaml                     # Dependencies
├── analysis_options.yaml            # Linting rules
├── .gitignore
├── README.md                        # Main documentation
├── SETUP_INSTRUCTIONS.md            # Setup & running guide
├── ARCHITECTURE.md                  # Architecture details
└── API_INTEGRATION.md               # API integration guide
```

## Key Classes

### BLoCs
- `MapBloc`: Manages nearby stations, filters
- `LocationBloc`: Handles location services
- `AuthBloc`: User authentication

### Services
- `LocationService`: GPS access
- `AuthService`: Firebase auth
- `FirestoreService`: Database access
- `FuelPriceApi`: External API

### Repositories
- `GasStationRepository`: Station operations
- `LocationRepository`: Location services
- `AuthRepository`: Authentication

### UI Components
- `MapPage`: Main map screen
- `StationDetailPage`: Station details screen
- `AuthPage`: Login/signup screen
- `StationCard`: Station list item
- `FilterBottomSheet`: Filters dialog

## State Flow Diagram

```
User Action (e.g., tap location button)
           ↓
      BLoC Event (LocationPermissionEvent)
           ↓
      BLoC Handler (_onRequestPermission)
           ↓
    Repository (LocationRepository)
           ↓
   Data Source (LocationService)
           ↓
  External Service (Geolocator)
           ↓
     Parse Response
           ↓
      BLoC State (LocationPermissionGranted)
           ↓
    UI Rebuild (MapPage)
```

## Common Tasks

### Load Gas Stations Near User

```dart
// In MapPage widget
context.read<MapBloc>().add(
  LoadNearbyStationsEvent(
    location: userLocation,
    radiusKm: 50,
  ),
);
```

### Submit Price Update

```dart
// In StationDetailPage
context.read<PriceUpdateBloc>().add(
  SubmitPriceUpdateEvent(
    stationId: stationId,
    fuelType: 'Benzina',
    price: 1.599,
  ),
);
```

### Change Authentication Status

```dart
// Sign in
context.read<AuthBloc>().add(
  SignInEvent(email: email, password: password),
);

// Sign out
context.read<AuthBloc>().add(const SignOutEvent());
```

## Important Constants

```dart
// In lib/core/constants/constants.dart
AppConstants.defaultLatitude      // 41.8719 (Italy center)
AppConstants.defaultLongitude     // 12.5674
AppConstants.defaultZoom          // 6.0
AppConstants.stationSearchRadius  // 50.0 km
AppConstants.cacheDuration        // 30 minutes
```

## Testing Commands

```bash
# Run all tests
flutter test

# Run specific test
flutter test test/path/to/test.dart

# Generate coverage
flutter test --coverage
```

## Build Commands

```bash
# Development
flutter run

# Release
flutter build apk --release      # Android
flutter build ios --release      # iOS
flutter build web --release      # Web

# Profile (performance)
flutter run --profile
```

## Debugging

```bash
# Enable verbose logging
flutter run -v

# Attach to running app
flutter attach

# Open DevTools
flutter pub global run devtools
```

## Important Dependencies

- **flutter_bloc**: State management
- **firebase_core**: Firebase initialization
- **cloud_firestore**: Database
- **firebase_auth**: Authentication
- **flutter_map**: Map display
- **geolocator**: Location services
- **dio**: HTTP client
- **get_it**: Service locator
- **google_fonts**: Typography
- **dartz**: Functional programming

## Git Workflow

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes and commit
git commit -m "feat: add new feature"

# Push to remote
git push origin feature/new-feature

# Create pull request
# (GitHub or your platform)
```

## Environment Setup Checklist

- [ ] Flutter SDK installed
- [ ] iOS dependencies (if macOS)
- [ ] Android SDK configured
- [ ] Firebase project created
- [ ] FlutterFire CLI configured
- [ ] Location permissions added
- [ ] API keys configured
- [ ] Dependencies installed (`flutter pub get`)

## Common Errors & Solutions

### "flutter command not found"
```bash
# Add Flutter to PATH
export PATH="$PATH:~/flutter/bin"
```

### "Pod install failed"
```bash
cd ios && rm -rf Pods Podfile.lock && pod install --repo-update && cd ..
```

### "Firebase initialization failed"
- Check firebase_options.dart
- Verify GoogleService-Info.plist (iOS)
- Verify google-services.json (Android)

### "Location permission denied"
- Grant permission in device settings
- Restart app

### "Map not loading"
- Check internet connection
- Verify OpenStreetMap tile server
- Check API key (if using paid service)

## Useful Links

- **Flutter Docs**: https://flutter.dev/docs
- **Firebase Flutter**: https://firebase.flutter.dev/
- **BLoC Library**: https://bloclibrary.dev/
- **OpenStreetMap**: https://www.openstreetmap.org/
- **MIMIT API**: https://dati.mise.gov.it/

## Performance Metrics

**Target**:
- App startup: < 2 seconds
- Map load: < 3 seconds
- Station list: < 1 second
- Filter apply: < 500ms

**Monitor**:
- Flutter DevTools → Performance tab
- Profiling → Timeline
- Memory usage: DevTools → Memory tab

---

For detailed information, refer to:
- README.md (overview)
- SETUP_INSTRUCTIONS.md (setup)
- ARCHITECTURE.md (architecture)
- API_INTEGRATION.md (API details)
