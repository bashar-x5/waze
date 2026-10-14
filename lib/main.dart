import 'package:flutter/material.dart';
import 'app/app_controller.dart';
import 'app/darb_app.dart';
import 'services/android_auto_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  await controller.load();
  AndroidAutoService(controller);
  runApp(DarbApp(controller: controller));
}
