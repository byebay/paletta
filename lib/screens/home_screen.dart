import 'package:flutter/material.dart';
import '../features/inference/model_loader.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Paletta 🎨',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _modelLoader.isLoaded ? Icons.circle : Icons.circle_outlined,
              color: _modelLoader.isLoaded ? Colors.green : Colors.grey,
              size: 14,
            ),
          )
        ],
      ),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _modelLoader.isLoaded
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ScannerScreen(modelLoader: _modelLoader),
                    ),
                  )
              : null,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Mulai Scan'),
        ),
      ),
    );
  }
}