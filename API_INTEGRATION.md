# Prezzi Benzina API Integration Guide

## Overview

This document explains how the app integrates with external APIs and data sources.

## Data Sources

### 1. OpenStreetMap Tiles

**Purpose**: Map visualization

**Library**: `flutter_map` package

**Configuration**:
```dart
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageIdentifier: 'com.example.app',
)
```

**Features**:
- Free, open-source map tiles
- No API key required
- Covers entire world
- Updates in real-time

**Tile Servers** (alternatives):
- OpenStreetMap: `https://tile.openstreetmap.org/`
- Stamen: `https://tiles.stadiamaps.com/tiles/stamen_terrain/`
- CartoDB: `https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/`

### 2. MIMIT Italian Fuel Prices API

**Purpose**: National fuel price data (optional, for initial population)

**Endpoint**: `https://dati.mise.gov.it/api/3/action`

**Dataset**: "prezzo-medio-nazionale-dei-carburanti"

**Example Query**:
```dart
GET /api/3/action/package_search?q=prezzo%20medio%20nazionale
```

**Response Structure**:
```json
{
  "result": {
    "results": [
      {
        "name": "Liguria",
        "prezzo_medio_benzina": 1.599,
        "prezzo_medio_diesel": 1.499,
        "data_lettura": "2024-04-29"
      }
    ]
  }
}
```

**Implementation**:
```dart
// In lib/data/datasources/fuel_price_api.dart
class FuelPriceApiImpl implements FuelPriceApi {
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getFuelPricesData() async {
    final response = await _dio.get('/package_search', 
      queryParameters: {'q': 'prezzo medio nazionale'},
    );
    // Parse and return
  }
}
```

### 3. Firebase Services

#### 3.1 Firestore Database

**Purpose**: Store gas stations, prices, and user data

**Collections**:
- `gas_stations`: Station information and current prices
- `price_updates`: Community-submitted price updates
- `users`: User preferences and account data
- `favorites`: User favorite stations

**Example Write**:
```dart
await firestore.collection('gas_stations').doc('station_1').set({
  'name': 'Q8 SELF SERVICE',
  'location': {
    'latitude': 41.9028,
    'longitude': 12.4964,
  },
  'prices': {
    'Benzina': 1.599,
    'Diesel': 1.499,
  },
});
```

**Example Query**:
```dart
final snapshot = await firestore
    .collection('gas_stations')
    .limit(50)
    .get();
```

#### 3.2 Firebase Authentication

**Purpose**: User authentication

**Methods**:
- Email/Password
- Anonymous

**Example**:
```dart
// Sign up
await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: 'user@example.com',
  password: 'password',
);

// Sign in
await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: 'user@example.com',
  password: 'password',
);

// Anonymous
await FirebaseAuth.instance.signInAnonymously();

// Get current user
final user = FirebaseAuth.instance.currentUser;
```

#### 3.3 Cloud Storage (Optional)

For storing user-uploaded images (future feature):

```dart
final storage = FirebaseStorage.instance;
final ref = storage.ref().child('images/${DateTime.now().toIso8601String()}.jpg');
await ref.putFile(imageFile);
```

### 4. Geolocation Services

**Purpose**: Get user location for nearby stations

**Library**: `geolocator` or `location` package

**Implementation**:
```dart
// In lib/data/datasources/location_service.dart
class LocationServiceImpl implements LocationService {
  Future<UserLocation> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition();
    return UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
    );
  }
}
```

**Permissions**:
- iOS: NSLocationWhenInUseUsageDescription
- Android: ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION

## Adding New API Integration

### Step 1: Create Data Source

```dart
// lib/data/datasources/example_api.dart
abstract class ExampleApi {
  Future<List<ExampleData>> fetchData();
}

class ExampleApiImpl implements ExampleApi {
  final Dio _dio;

  ExampleApiImpl(this._dio);

  @override
  Future<List<ExampleData>> fetchData() async {
    try {
      final response = await _dio.get('/endpoint');
      return (response.data as List)
          .map((e) => ExampleData.fromJson(e))
          .toList();
    } catch (e) {
      throw ApiException(message: 'Failed to fetch');
    }
  }
}
```

### Step 2: Create Model

```dart
// lib/data/models/example_model.dart
class ExampleModel {
  final String id;
  final String name;

  const ExampleModel({
    required this.id,
    required this.name,
  });

  factory ExampleModel.fromJson(Map<String, dynamic> json) {
    return ExampleModel(
      id: json['id'],
      name: json['name'],
    );
  }
}
```

### Step 3: Create Repository

```dart
// lib/data/repositories/example_repository_impl.dart
class ExampleRepositoryImpl implements ExampleRepository {
  final ExampleApi _api;

  ExampleRepositoryImpl(this._api);

  @override
  Future<List<ExampleData>> getData() async {
    try {
      return await _api.fetchData();
    } catch (e) {
      throw Exception('Failed to fetch data');
    }
  }
}
```

### Step 4: Register in Service Locator

```dart
// lib/core/services/service_locator.dart
void setupServiceLocator() {
  final dio = Dio();

  getIt.registerSingleton<ExampleApi>(
    ExampleApiImpl(dio),
  );

  getIt.registerSingleton<ExampleRepository>(
    ExampleRepositoryImpl(getIt<ExampleApi>()),
  );
}
```

## API Rate Limiting

**Best Practices**:

```dart
// Implement caching
class CachedRepository {
  DateTime? _lastFetchTime;
  List<T> _cache = [];

  Future<List<T>> getData() async {
    if (_lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < Duration(minutes: 30)) {
      return _cache;
    }

    final data = await _api.fetch();
    _cache = data;
    _lastFetchTime = DateTime.now();
    return data;
  }
}
```

## Error Handling

```dart
try {
  return await api.fetchData();
} on DioException catch (e) {
  if (e.response?.statusCode == 404) {
    throw NetworkException(message: 'Data not found');
  } else if (e.response?.statusCode == 429) {
    throw NetworkException(message: 'Rate limit exceeded');
  }
  throw NetworkException(message: 'Network error');
} catch (e) {
  throw UnexpectedFailure(message: 'Unknown error');
}
```

## Testing APIs

### Mock API Responses

```dart
// test/data/datasources/example_api_test.dart
void main() {
  group('ExampleApi', () {
    late MockDio mockDio;
    late ExampleApiImpl api;

    setUp(() {
      mockDio = MockDio();
      api = ExampleApiImpl(mockDio);
    });

    test('fetches data successfully', () async {
      when(mockDio.get('/endpoint'))
          .thenAnswer((_) async => Response(
            data: [{'id': '1', 'name': 'test'}],
            statusCode: 200,
          ));

      final result = await api.fetchData();

      expect(result, isNotEmpty);
    });
  });
}
```

## Security Considerations

1. **API Keys**: Store in secure configuration
   ```dart
   // Use environment variables or secure storage
   const apiKey = String.fromEnvironment('API_KEY');
   ```

2. **HTTPS Only**: Always use HTTPS
   ```dart
   _dio.options.baseUrl = 'https://api.example.com';
   ```

3. **Request Timeout**: Set reasonable timeouts
   ```dart
   _dio.options.connectTimeout = Duration(seconds: 10);
   _dio.options.receiveTimeout = Duration(seconds: 10);
   ```

4. **Authentication**: Use Firebase security rules
   ```
   allow write: if request.auth != null;
   ```

## Debugging APIs

### Enable Request Logging

```dart
_dio.interceptors.add(
  LoggingInterceptor(),
);
```

### Use Postman

Test API endpoints before integrating:
- GET `/api/3/action/package_search`
- Headers: `User-Agent: FlutterApp`

### Monitor Firestore

```bash
# In Firebase Console
# - View collections
# - Check document data
# - Monitor real-time updates
```

## Performance Tips

✅ **Do's**:
- Implement caching strategies
- Use pagination for large datasets
- Compress images before upload
- Batch requests when possible
- Use CDN for static assets

❌ **Don'ts**:
- Make unnecessary API calls
- Store large objects in Firestore
- Ignore error responses
- Use blocking operations
- Hardcode API endpoints

---

For more information:
- [OpenStreetMap Wiki](https://wiki.openstreetmap.org/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Dio Package](https://pub.dev/packages/dio)
- [Flutter Location Services](https://flutter.dev/docs/development/data-and-backend/firebase)
