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
import 'package:mappa_prezzi_benzina/data/repositories/auth_repository_impl.dart';
import 'package:mappa_prezzi_benzina/data/repositories/gas_station_repository_impl.dart';
import 'package:mappa_prezzi_benzina/data/repositories/location_repository_impl.dart';

// Domain
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

// BLoCs
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/location_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/map_bloc.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Firebase Setup
  final firebaseAuth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  
  // External Dependencies
  final dio = Dio();

  // Data Sources
  getIt.registerSingleton<AuthService>(
    AuthServiceImpl(firebaseAuth),
  );

  getIt.registerSingleton<FirestoreService>(
    FirestoreServiceImpl(firestore),
  );

  getIt.registerSingleton<LocationService>(
    LocationServiceImpl(),
  );

  getIt.registerSingleton<FuelPriceApi>(
    FuelPriceApiImpl(dio),
  );

  // Repositories
  getIt.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(getIt<AuthService>()),
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

  // BLoCs
  getIt.registerSingleton<AuthBloc>(
    AuthBloc(getIt<AuthRepository>()),
  );

  getIt.registerSingleton<LocationBloc>(
    LocationBloc(getIt<LocationRepository>()),
  );

  getIt.registerSingleton<MapBloc>(
    MapBloc(getIt<GasStationRepository>()),
  );
}
