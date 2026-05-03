import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mappa_prezzi_benzina/core/services/service_locator.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/location_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/map_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/auth_page.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/map_page.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/station_detail_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Setup Service Locator
  setupServiceLocator();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => getIt<AuthBloc>(),
        ),
        BlocProvider<LocationBloc>(
          create: (context) => getIt<LocationBloc>(),
        ),
        BlocProvider<MapBloc>(
          create: (context) => getIt<MapBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'Prezzi Benzina',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is Authenticated) {
              return const MapPage();
            }
            return const AuthPage();
          },
        ),
        routes: {
          '/auth': (context) => const AuthPage(),
          '/map': (context) => const MapPage(),
          '/station-detail': (context) {
            final arguments = ModalRoute.of(context)?.settings.arguments;
            final station = arguments is Map<String, Object?>
                ? arguments['station'] as GasStation?
                : arguments as GasStation?;
            final userLocation = arguments is Map<String, Object?>
                ? arguments['userLocation'] as UserLocation?
                : null;
            return StationDetailPage(
              station: station,
              userLocation: userLocation,
            );
          },
        },
      ),
    );
  }
}
