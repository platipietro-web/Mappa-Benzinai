import 'package:flutter/material.dart';
import 'package:mappa_prezzi_benzina/core/services/service_locator.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_screen.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/favorites_page.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/map_page.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

// Sempre 3 tab fissi: 0=Carburante, 1=Preferiti, 2=Autolavaggio.
// FavoritesPage gestisce internamente il caso utente non loggato.

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  late final ValueNotifier<int> _tabNotifier;

  static const _pages = [MapPage(), FavoritesPage(), CarWashScreen()];

  @override
  void initState() {
    super.initState();
    _tabNotifier = getIt<ValueNotifier<int>>(instanceName: 'mainTabIndex');
    _tabNotifier.addListener(_onExternalTabChange);
  }

  @override
  void dispose() {
    _tabNotifier.removeListener(_onExternalTabChange);
    super.dispose();
  }

  void _onExternalTabChange() {
    if (mounted && _tabNotifier.value != _index) {
      setState(() => _index = _tabNotifier.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppTheme.surfaceColor,
        indicatorColor: AppTheme.primaryColor.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_gas_station_outlined),
            selectedIcon: Icon(Icons.local_gas_station,
                color: AppTheme.primaryColor),
            label: 'Carburante',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, color: Colors.red),
            label: 'Preferiti',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_car_wash_outlined),
            selectedIcon: Icon(Icons.local_car_wash,
                color: Color(0xFF0891B2)),
            label: 'Autolavaggio',
          ),
        ],
      ),
    );
  }
}
