import 'package:flutter/material.dart';
import 'package:mappa_prezzi_benzina/core/services/service_locator.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_screen.dart';
import 'package:mappa_prezzi_benzina/presentation/pages/map_page.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final ValueNotifier<int> _tabNotifier;

  // IndexedStack keeps both pages alive so they retain their state
  // (map position, loaded stations, etc.) across tab switches.
  late final List<Widget> _pages = const [MapPage(), CarWashScreen()];

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
    if (mounted && _tabNotifier.value != _currentIndex) {
      setState(() => _currentIndex = _tabNotifier.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: AppTheme.surfaceColor,
        indicatorColor: AppTheme.primaryColor.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.local_gas_station_outlined),
            selectedIcon: const Icon(Icons.local_gas_station,
                color: AppTheme.primaryColor),
            label: _navLabel('Carburante'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_car_wash_outlined),
            selectedIcon: const Icon(Icons.local_car_wash,
                color: Color(0xFF0891B2)),
            label: _navLabel('Autolavaggio'),
          ),
        ],
      ),
    );
  }

  String _navLabel(String text) => text;
}
