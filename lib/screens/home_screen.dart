import 'package:flutter/material.dart';
import '../../features/camera/camera_preview_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      ),
      body: const CameraPreviewWidget(),
    );
  }
}