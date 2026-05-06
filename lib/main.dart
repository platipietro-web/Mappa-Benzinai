import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mappa_prezzi_benzina/core/services/service_locator.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/dashboard_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/favorites_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/location_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/map_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/user_profile_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/auth_page.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/dashboard_page.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/map_page.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/station_detail_page.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/favorites_page.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  setupServiceLocator();

  // Le tile OSM annullate per cambio viewport generano ClientException con
  // "abortTrigger": è comportamento normale, non un errore reale.
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exception.toString();
    if (msg.contains('abortTrigger') || msg.contains('XMLHttpRequest error')) {
      return;
    }
    FlutterError.presentError(details);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => getIt<AuthBloc>()),
        BlocProvider<FavoritesBloc>(create: (_) => getIt<FavoritesBloc>()),
        BlocProvider<LocationBloc>(create: (_) => getIt<LocationBloc>()),
        BlocProvider<MapBloc>(create: (_) => getIt<MapBloc>()),
        BlocProvider<UserProfileBloc>(create: (_) => getIt<UserProfileBloc>()),
        BlocProvider<DashboardBloc>(create: (_) => getIt<DashboardBloc>()),
      ],
      child: MaterialApp(
        title: 'Prezzi Benzina',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is Authenticated && !state.isAnonymous) {
              context
                  .read<FavoritesBloc>()
                  .add(LoadFavoritesEvent(state.userId));
              context
                  .read<UserProfileBloc>()
                  .add(LoadUserProfileEvent(state.userId));
              context
                  .read<DashboardBloc>()
                  .add(LoadDashboardEvent(state.userId));
            } else if (state is Unauthenticated) {
              context.read<FavoritesBloc>().add(const ClearFavoritesEvent());
              context
                  .read<UserProfileBloc>()
                  .add(const ClearUserProfileEvent());
              context.read<DashboardBloc>().add(const ClearDashboardEvent());
            }
          },
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is Authenticated) return const MapPage();
              if (state is Unauthenticated) return AuthPage(initialSignUp: state.signUpMode);
              return const AuthPage();
            },
          ),
        ),
        routes: {
          '/auth': (context) => const AuthPage(),
          '/map': (context) => const MapPage(),
          '/profile': (context) => const ProfilePage(),
          '/favorites': (context) => const FavoritesPage(),
          '/dashboard': (context) => const DashboardPage(),
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
