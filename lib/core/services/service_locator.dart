import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';

// Data Sources
import 'package:mappa_prezzi_benzina/data/datasources/auth_service.dart';
import 'package:mappa_prezzi_benzina/data/datasources/firestore_service.dart';
import 'package:mappa_prezzi_benzina/data/datasources/fuel_price_api.dart';
import 'package:mappa_prezzi_benzina/data/datasources/location_service.dart';

// Repositories
import 'package:mappa_prezzi_benzina/data/repositories/analytics_repository_impl.dart';
import 'package:mappa_prezzi_benzina/data/repositories/auth_repository_impl.dart';
import 'package:mappa_prezzi_benzina/data/repositories/gas_station_repository_impl.dart';
import 'package:mappa_prezzi_benzina/data/repositories/location_repository_impl.dart';
import 'package:mappa_prezzi_benzina/data/repositories/user_profile_repository_impl.dart';

// Domain
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

// BLoCs
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/dashboard_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/favorites_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/location_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/map_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/user_profile_bloc.dart';

// Car wash feature
import 'package:mappa_prezzi_benzina/features/carwash/carwash_bloc.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_favorites_bloc.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_repository.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_repository_impl.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_service.dart';
import 'package:mappa_prezzi_benzina/features/carwash/osm_carwash_importer.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  final firebaseAuth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final dio = Dio();

  // Data Sources
  getIt.registerSingleton<AuthService>(AuthServiceImpl(firebaseAuth));
  getIt.registerSingleton<FirestoreService>(FirestoreServiceImpl(firestore));
  getIt.registerSingleton<LocationService>(LocationServiceImpl());
  getIt.registerSingleton<FuelPriceApi>(FuelPriceApiImpl(dio));

  // Repositories
  getIt.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(
      getIt<AuthService>(),
      getIt<FirestoreService>(),
    ),
  );
  getIt.registerSingleton<GasStationRepository>(
    GasStationRepositoryImpl(
      getIt<FirestoreService>(),
      getIt<FuelPriceApi>(),
    ),
  );
  getIt.registerSingleton<LocationRepository>(
    LocationRepositoryImpl(getIt<LocationService>()),
  );
  getIt.registerSingleton<UserProfileRepository>(
    UserProfileRepositoryImpl(getIt<FirestoreService>()),
  );
  getIt.registerSingleton<AnalyticsRepository>(
    AnalyticsRepositoryImpl(getIt<FirestoreService>()),
  );

  // BLoCs
  getIt.registerSingleton<AuthBloc>(AuthBloc(getIt<AuthRepository>()));
  getIt.registerSingleton<FavoritesBloc>(
      FavoritesBloc(getIt<GasStationRepository>()));
  getIt.registerSingleton<LocationBloc>(
      LocationBloc(getIt<LocationRepository>()));
  getIt.registerSingleton<MapBloc>(MapBloc(getIt<GasStationRepository>()));
  getIt.registerSingleton<UserProfileBloc>(
      UserProfileBloc(getIt<UserProfileRepository>()));
  getIt.registerSingleton<DashboardBloc>(
      DashboardBloc(getIt<AnalyticsRepository>()));

  // Car wash feature
  getIt.registerSingleton<OsmCarWashImporter>(OsmCarWashImporter(dio));
  getIt.registerSingleton<CarWashService>(
      CarWashServiceImpl(firestore, getIt<OsmCarWashImporter>()));
  getIt.registerSingleton<CarWashRepository>(
      CarWashRepositoryImpl(getIt<CarWashService>()));
  getIt.registerSingleton<CarWashBloc>(
      CarWashBloc(getIt<CarWashRepository>()));
  getIt.registerSingleton<CarWashFavoritesBloc>(
      CarWashFavoritesBloc(firestore));
}
