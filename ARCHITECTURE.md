# Prezzi Benzina Architecture Guide

## Clean Architecture Overview

This project follows Clean Architecture principles with clear separation of concerns across three main layers:

```
┌─────────────────────────────────────────┐
│         PRESENTATION LAYER              │
│  (BLoC, Pages, Widgets, Theme)          │
├─────────────────────────────────────────┤
│          DOMAIN LAYER                   │
│  (Entities, Repositories, Use Cases)    │
├─────────────────────────────────────────┤
│          DATA LAYER                     │
│  (Models, Repositories, Data Sources)   │
├─────────────────────────────────────────┤
│         EXTERNAL SERVICES               │
│  (Firebase, OpenStreetMap, APIs)        │
└─────────────────────────────────────────┘
```

## Layer Descriptions

### Presentation Layer (`lib/presentation/`)

**Purpose**: Handles all UI and user interactions

**Components**:
- **BLoC**: State management (bloc/, map_bloc.dart, location_bloc.dart, auth_bloc.dart)
- **Pages**: Full-screen widgets (pages/, map_page.dart, station_detail_page.dart, auth_page.dart)
- **Widgets**: Reusable UI components (widgets/, station_card.dart, filter_bottom_sheet.dart)
- **Theme**: App styling and colors (theme/app_theme.dart)

**Key Features**:
- Widget builds based on BLoC state
- Events trigger business logic
- No direct database access
- Single responsibility principle

### Domain Layer (`lib/domain/`)

**Purpose**: Contains business logic and entities

**Components**:
- **Entities**: Core business objects (entities/gas_station.dart, user_location.dart, price_update.dart)
- **Repositories**: Abstract interfaces (repositories/repositories.dart)
- **Use Cases**: Business operations (optional, future expansion)

**Key Features**:
- Framework-independent
- Pure Dart code
- No external dependencies
- Single source of truth

### Data Layer (`lib/data/`)

**Purpose**: Handles data access and transformation

**Components**:
- **Data Sources**: External service integration
  - Firebase: firestore_service.dart, auth_service.dart
  - Location: location_service.dart
  - API: fuel_price_api.dart
- **Models**: Extend entities with serialization (models/)
- **Repositories**: Implement domain interfaces (repositories/)

**Key Features**:
- Converts external data to entities
- Implements repository contracts
- Handles errors and exceptions
- Caching and optimization

## Data Flow

### Example: Map Screen Loading Nearby Stations

```
UI Layer (MapPage)
       ↓
   User Action (RequestLocation)
       ↓
BLoC Event (LoadNearbyStationsEvent)
       ↓
BLoC Handler (_onLoadNearbyStations)
       ↓
Repository (GasStationRepository)
       ↓
Data Source (FirestoreService)
       ↓
External Service (Firestore)
       ↓
Parse Response (GasStationModel → GasStation)
       ↓
BLoC State (MapLoaded)
       ↓
UI Rebuild (StationCard widgets)
```

## Dependency Injection

Uses `get_it` package for service locator pattern.

### Service Locator Setup (`lib/core/services/service_locator.dart`)

```dart
void setupServiceLocator() {
  // Register Data Sources
  getIt.registerSingleton<FirestoreService>(...);
  
  // Register Repositories
  getIt.registerSingleton<GasStationRepository>(...);
  
  // Register BLoCs
  getIt.registerSingleton<MapBloc>(...);
}
```

### Usage in BLoC

```dart
class MapBloc extends Bloc<MapEvent, MapState> {
  final GasStationRepository _repository;
  
  MapBloc(this._repository) : super(const MapInitial());
}
```

### Registration in App

```dart
void main() {
  setupServiceLocator();
  
  MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => getIt<MapBloc>()),
      // ...
    ],
  )
}
```

## State Management (BLoC Pattern)

### Components

1. **Events**: User actions or external triggers
   ```dart
   class LoadNearbyStationsEvent extends MapEvent {
     final UserLocation location;
     const LoadNearbyStationsEvent({required this.location});
   }
   ```

2. **States**: UI states based on events
   ```dart
   class MapLoaded extends MapState {
     final List<GasStation> stations;
     const MapLoaded({required this.stations});
   }
   ```

3. **BLoC**: Handles events and emits states
   ```dart
   class MapBloc extends Bloc<MapEvent, MapState> {
     MapBloc(this._repository) : super(const MapInitial()) {
       on<LoadNearbyStationsEvent>(_onLoadNearbyStations);
     }
   }
   ```

### Benefits

✅ Predictable state changes
✅ Separation of business logic
✅ Easy testing
✅ Single responsibility
✅ Reactive and responsive UI

## Adding New Feature: Price History

### Step 1: Create Domain Entity

```dart
// lib/domain/entities/price_history.dart
class PriceHistory extends Equatable {
  final String fuelType;
  final List<PricePoint> points;
  
  const PriceHistory({...});
}

class PricePoint extends Equatable {
  final double price;
  final DateTime timestamp;
  
  const PricePoint({...});
}
```

### Step 2: Create Data Model

```dart
// lib/data/models/price_history_model.dart
class PriceHistoryModel extends PriceHistory {
  const PriceHistoryModel({...});
  
  factory PriceHistoryModel.fromFirestore(Map<String, dynamic> json) {
    // Conversion logic
  }
}
```

### Step 3: Create Service Layer

```dart
// lib/data/datasources/price_history_service.dart
abstract class PriceHistoryService {
  Future<List<PricePoint>> getPriceHistory(String stationId, String fuelType);
}

class PriceHistoryServiceImpl implements PriceHistoryService {
  // Implementation
}
```

### Step 4: Create Repository

```dart
// lib/data/repositories/price_history_repository_impl.dart
class PriceHistoryRepositoryImpl implements PriceHistoryRepository {
  final PriceHistoryService _service;
  
  Future<List<PricePoint>> getPriceHistory(...) async {
    return await _service.getPriceHistory(...);
  }
}
```

### Step 5: Create BLoC

```dart
// lib/presentation/bloc/price_history_bloc.dart
class PriceHistoryBloc extends Bloc<PriceHistoryEvent, PriceHistoryState> {
  final PriceHistoryRepository _repository;
  
  PriceHistoryBloc(this._repository) : super(const PriceHistoryInitial()) {
    on<LoadPriceHistoryEvent>(_onLoadPriceHistory);
  }
}
```

### Step 6: Create UI

```dart
// lib/presentation/pages/price_history_page.dart
class PriceHistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PriceHistoryBloc, PriceHistoryState>(
      builder: (context, state) {
        // UI based on state
      },
    );
  }
}
```

### Step 7: Register in Service Locator

```dart
// In setupServiceLocator()
getIt.registerSingleton<PriceHistoryService>(...);
getIt.registerSingleton<PriceHistoryRepository>(...);
getIt.registerSingleton<PriceHistoryBloc>(...);
```

## Error Handling

### Exception Hierarchy

```
AppException
├── LocationException
├── NetworkException
├── DatabaseException
├── AuthException
└── ApiException
```

### Failure Hierarchy

```
Failure
├── LocationFailure
├── NetworkFailure
├── DatabaseFailure
├── AuthFailure
├── ServerFailure
└── UnexpectedFailure
```

### Usage in Repository

```dart
try {
  return await _firestore.getStations(...);
} catch (e) {
  throw DatabaseException(message: 'Failed to fetch stations');
}
```

### Usage in BLoC

```dart
try {
  final stations = await _repository.getNearbyStations(...);
  emit(MapLoaded(stations: stations));
} catch (e) {
  emit(MapError('Failed to load: ${e.toString()}'));
}
```

## Firebase Security

### Firestore Rules

```
- Public read access to gas_stations
- Authenticated write access to gas_stations
- User-only access to personal data
```

### Authentication

```
- Email/Password: Secure credential storage
- Anonymous: For guest users
- Token refresh: Automatic
```

## Performance Optimization

### Caching Strategy

```dart
// 30-minute cache duration
const Duration cacheDuration = Duration(minutes: 30);

// Implemented in repository
if (_lastFetchTime != null && 
    DateTime.now().difference(_lastFetchTime!) < cacheDuration) {
  return _cachedStations;
}
```

### Lazy Loading

```dart
// Load only 50 stations at a time
query.limit(50).get()
```

### Pagination

```dart
// ListView with pagination
ListView.builder(
  itemBuilder: (context, index) {
    if (index == stations.length - 1) {
      // Load more
      _loadMore();
    }
  },
)
```

## Testing Structure (Future)

```
test/
├── data/
│   ├── datasources/
│   └── repositories/
├── domain/
│   └── entities/
└── presentation/
    └── bloc/
```

### Example Test

```dart
group('MapBloc', () {
  late MapBloc mapBloc;
  late MockGasStationRepository mockRepository;
  
  setUp(() {
    mockRepository = MockGasStationRepository();
    mapBloc = MapBloc(mockRepository);
  });
  
  test('emits MapLoaded when stations loaded', () async {
    // Arrange
    when(mockRepository.getNearbyStations(...))
        .thenAnswer((_) async => [...]);
    
    // Act
    mapBloc.add(LoadNearbyStationsEvent(...));
    
    // Assert
    expect(mapBloc.stream, emits(MapLoaded(...)));
  });
});
```

## Best Practices

✅ **Do's**:
- Keep entities simple and immutable
- Use sealed classes for enums
- Implement proper error handling
- Write testable code
- Follow naming conventions
- Keep BLoC functions single-purpose

❌ **Don'ts**:
- Don't add Firebase directly to UI
- Don't expose repositories to widgets
- Don't mix concerns in layers
- Don't hardcode values
- Don't ignore error states
- Don't make state mutable

---

This architecture ensures:
- **Maintainability**: Clear separation and organization
- **Testability**: Each layer independently testable
- **Scalability**: Easy to add new features
- **Reusability**: Shared components across screens
- **Type Safety**: Strong typing throughout
