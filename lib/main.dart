import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/fire_detection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request camera permission
  await Permission.camera.request();
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fire Detection App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const FireDetectionScreen(),
    );
  }
}
