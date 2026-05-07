import 'package:flutter/material.dart';
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

  // IndexedStack keeps both pages alive so they retain their state
  // (map position, loaded stations, etc.) across tab switches.
  late final List<Widget> _pages = const [MapPage(), CarWashScreen()];

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
