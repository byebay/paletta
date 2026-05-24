import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'features/gallery/providers/gallery_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await dotenv.load(fileName: '.env');

  final galleryProvider = GalleryProvider();
  await galleryProvider.init();

  runApp(
    ChangeNotifierProvider.value(
      value: galleryProvider,
      child: const App(),
    ),
  );
}