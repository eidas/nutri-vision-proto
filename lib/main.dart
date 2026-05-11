import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait so the scan guide always has a consistent orientation.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final cameras = await availableCameras();

  runApp(NutriVisionApp(cameras: cameras));
}

class NutriVisionApp extends StatelessWidget {
  const NutriVisionApp({super.key, required this.cameras});
  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriVision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C853), // green accent
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      home: cameras.isEmpty
          ? const _NoCameraScreen()
          : CameraScreen(cameras: cameras),
    );
  }
}

class _NoCameraScreen extends StatelessWidget {
  const _NoCameraScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('カメラが見つかりません'),
      ),
    );
  }
}
