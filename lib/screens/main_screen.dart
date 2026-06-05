import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/inference/model_loader.dart';
import '../features/gallery/providers/gallery_provider.dart';
import 'scanner_screen.dart';
import '../features/gallery/screens/gallery_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final ModelLoader _modelLoader = ModelLoader();

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    await _modelLoader.load();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _modelLoader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ScannerScreen(modelLoader: _modelLoader),
          const GalleryScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF2196F3).withOpacity(0.15),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt, color: Color(0xFF2196F3)),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon:
                Icon(Icons.photo_library, color: Color(0xFF2196F3)),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Color(0xFF2196F3)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}