# Prezzi Benzina - Modern Fuel Prices App MVP

A modern, scalable Flutter application for finding the best fuel prices across Italian gas stations.

## Features

- 🗺️ **Interactive Map**: Real-time visualization of nearby gas stations using OpenStreetMap
- ⛽ **Fuel Prices**: Compare prices for Benzina, Diesel, GPL, and Metano
- 🔍 **Advanced Filters**: Filter by fuel type and sort by price, distance, or rating
- ⭐ **Favorites**: Save your preferred gas stations
- 📍 **Location Services**: Find stations near you automatically
- 👤 **User Contributions**: Submit and update fuel prices from the community
- 🔐 **Authentication**: Support for email/password and anonymous login

## Tech Stack

### Frontend
- **Flutter 3.0+**: Modern, responsive mobile UI
- **BLoC Pattern**: State management with flutter_bloc
- **Get It**: Dependency injection and service locator
- **Flutter Map**: OpenStreetMap integration

### Backend
- **Firebase**:
  - Firestore: Real-time database for stations and prices
  - Firebase Auth: User authentication
- **REST API**:
  - MIMIT: Italian fuel price data
  - Dio: HTTP client

### Architecture
- **Clean Architecture**: Separation of concerns with Domain, Data, and Presentation layers
- **Repository Pattern**: Abstract data access
- **Event-Driven**: BLoC events and states for predictable state management

## Project Structure

```
lib/
├── core/
│   ├── constants/        # App constants
│   ├── errors/          # Exception and failure definitions
│   ├── utils/           # Logging and utilities
│   └── services/        # Service locator (dependency injection)
├── data/
│   ├── datasources/     # Firebase, Location, API integrations
│   ├── models/          # Data models (JSON serialization)
│   └── repositories/    # Repository implementations
├── domain/
│   ├── entities/        # Business logic entities
│   ├── repositories/    # Repository abstract classes
│   └── usecases/        # Business use cases (future expansion)
├── presentation/
│   ├── bloc/            # BLoC classes for state management
│   ├── pages/           # Full-page UI screens
│   ├── widgets/         # Reusable components
│   └── theme/           # App theme and styling
├── main.dart            # App entry point
└── firebase_options.dart # Firebase configuration
```

## Getting Started

### Prerequisites

- Flutter SDK 3.0+ ([Install Flutter](https://flutter.dev/docs/get-started/install))
- Firebase project ([Create Project](https://console.firebase.google.com))
- Git

### Installation

#### 1. Clone the repository
```bash
cd /Users/pietro/Desktop/App\ test/MappaPrezziBenzina
```

#### 2. Get Flutter dependencies
```bash
flutter pub get
```

#### 3. Configure Firebase

**Using FlutterFire CLI (Recommended)**:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for your platforms
flutterfire configure \
  --project=prezzi-benzina \
  --ios-bundle-id=com.example.mappaPrezziBenzina \
  --android-package-name=com.example.mappa_prezzi_benzina
```

**Manual Firebase Setup**:

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Add iOS and Android apps to your project
3. Download the configuration files:
   - **iOS**: `GoogleService-Info.plist` → `ios/Runner/`
   - **Android**: `google-services.json` → `android/app/`
4. Update `lib/firebase_options.dart` with your credentials

#### 4. Enable Firebase Services

In Firebase Console:

- **Firestore Database**:
  - Create in Production mode
  - Set rules:
    ```
    rules_version = '2';
    service cloud.firestore {
      match /databases/{database}/documents {
        // Public read, authenticated write
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

- **Authentication**:
  - Enable Email/Password provider
  - Enable Anonymous sign-in

#### 5. Run the app

```bash
# For iOS
flutter run -t lib/main.dart

# For Android
flutter run -t lib/main.dart

# For all platforms
flutter run
```

## API Integration

### Italian Fuel Prices (MIMIT)

The app integrates with the Italian Ministry of Business and Made in Italy (MIMIT) open data API:

```dart
// Example: Fetch fuel prices
final fuelPriceApi = FuelPriceApiImpl(Dio());
final prices = await fuelPriceApi.getFuelPricesData();
```

**API Endpoint**: `https://dati.mise.gov.it/api/3/action`

**Dataset**: Prezzo medio nazionale dei carburanti

### Custom Data Population

For initial development, sample data is automatically created in Firestore. You can also:

1. Import CSV data via Firestore console
2. Use batch import scripts
3. Populate via REST API

## Firestore Database Schema

### gas_stations collection
```json
{
  "name": "Q8 SELF SERVICE",
  "address": "Via Roma 123, 00100 Roma",
  "location": {
    "latitude": 41.9028,
    "longitude": 12.4964
  },
  "phoneNumber": "+39 06 1234567",
  "website": "https://q8.it",
  "prices": {
    "Benzina": 1.599,
    "Diesel": 1.499,
    "GPL": 0.799,
    "Metano": 1.299
  },
  "lastUpdated": "2024-04-29T10:30:00Z",
  "numberOfRatings": 256,
  "averageRating": 4.5
}
```

### price_updates subcollection
```json
{
  "stationId": "station_doc_id",
  "userId": "user_id",
  "fuelType": "Benzina",
  "price": 1.609,
  "timestamp": "2024-04-29T10:30:00Z",
  "likes": 15,
  "isFlagged": false
}
```

### users collection
```json
{
  "email": "user@example.com",
  "createdAt": "2024-04-29T10:30:00Z",
  "preferences": {
    "favoriteStations": ["station_id_1", "station_id_2"]
  }
}
```

## Environment Configuration

### Supported Platforms

- ✅ iOS 12.0+
- ✅ Android 5.0+ (API 21+)
- ✅ Web (Chrome, Firefox, Safari)

### Permissions Required

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby gas stations</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location to show nearby gas stations</string>
```

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

## Key Components

### Authentication BLoC
Handles user authentication states and events:
- Sign up with email
- Sign in with email
- Anonymous sign-in
- Sign out
- Password reset

### Map BLoC
Manages map screen state:
- Load nearby stations
- Filter and sort stations
- Station selection
- Refresh data

### Location BLoC
Handles location services:
- Request permissions
- Get current location
- Stream location updates
- Check service availability

## Extending the App

### Adding New Features

1. **Create Domain Entity** (`lib/domain/entities/`)
2. **Create Data Model** (`lib/data/models/`)
3. **Create Service Layer** (`lib/data/datasources/`)
4. **Create Repository** (`lib/data/repositories/`)
5. **Create BLoC** (`lib/presentation/bloc/`)
6. **Create UI Pages/Widgets** (`lib/presentation/`)

### Example: Adding Favorites Feature

```dart
// 1. Service
class FavoriteService {
  Future<void> addFavorite(String userId, String stationId) async {
    // Implementation
  }
}

// 2. Repository
class FavoriteRepository {
  Future<void> addFavorite(String userId, String stationId) async {
    return await _service.addFavorite(userId, stationId);
  }
}

// 3. BLoC Event
class AddFavoriteEvent extends FavoriteEvent {
  final String stationId;
  const AddFavoriteEvent(this.stationId);
}

// 4. Register in Service Locator
getIt.registerSingleton<FavoriteRepository>(...);
```

## Performance Optimization

- **Caching**: Implemented with `shared_preferences` (30-minute cache duration)
- **Lazy Loading**: Stations load only within 50km radius
- **Pagination**: Station lists support infinite scrolling
- **Debouncing**: Filter changes are debounced to reduce queries

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/presentation/bloc/map_bloc_test.dart
```

## Troubleshooting

### Firebase Connection Issues

```bash
# Clear build cache
flutter clean

# Rebuild
flutter pub get
flutter run
```

### Location Permission Denied

- iOS: Grant permission in Settings → Privacy → Location
- Android: Grant permission in App Settings → Permissions

### Map Not Loading

- Check OpenStreetMap tile server availability
- Verify internet connection
- Clear app cache: `flutter clean`

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Best Practices Used

- **Clean Code**: Readable, maintainable code structure
- **SOLID Principles**: Separation of concerns, dependency injection
- **Type Safety**: Strong typing throughout the codebase
- **Error Handling**: Comprehensive exception and failure handling
- **UI/UX**: Modern design patterns, smooth animations
- **Performance**: Efficient state management and data loading

## Future Enhancements

- [ ] Price history charts
- [ ] Fuel price predictions
- [ ] Station reviews and ratings
- [ ] Offline support with local caching
- [ ] Push notifications for price alerts
- [ ] Dark mode
- [ ] Multi-language support
- [ ] Social features (sharing, community ratings)
- [ ] Advanced analytics

## License

This project is open source and available under the MIT License.

## Support

For issues, feature requests, or questions:

- Open an issue on GitHub
- Contact: support@prezzi-benzina.app
- Documentation: [Full docs](https://prezzi-benzina.dev/docs)

## Disclaimer

This is an MVP (Minimum Viable Product). While fully functional, there may be areas for optimization and additional features. Please report bugs and suggestions for improvement.

---

Built with ❤️ using Flutter and Firebase
