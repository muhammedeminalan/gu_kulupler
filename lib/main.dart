import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // ENV=emulator ise Auth/Firestore/Storage yerel emülatöre bağlanır;
  // Firebase'e dokunan her şeyden önce çağrılır (architecture §4–§5).
  await AppEnvironment.configure();
  runApp(const GuApp());
}

/// Geçici uygulama kökü (T-00 iskeleti).
// TODO(T-11): bootstrap (AppErrorHandler, AppEnvironment, DI), GoRouter ve GuTheme.
class GuApp extends StatelessWidget {
  const GuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: SizedBox.shrink());
  }
}
