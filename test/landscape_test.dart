import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:darb/app/app_controller.dart';
import 'package:darb/ui/home_screen.dart';
import 'package:darb/domain/demo_data.dart';
import 'package:darb/domain/navigation_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HomeScreen landscape test - navigating', (tester) async {
    SharedPreferences.setMockInitialValues({'darb.permissions_accepted.v1': true});
    final c = AppController(enableDeviceServices: false);
    await c.load();

    final sampleRoute = demoRoutes(demoPlaces.first).first;
    c.routes = [sampleRoute];
    c.routeIndex = 0;
    c.destination = demoPlaces.first;
    c.progress = calculateProgress(sampleRoute, sampleRoute.points.first);
    c.navigating = true;

    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          controller: c,
          renderMapTiles: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_panel_landscape')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });

  testWidgets('HomeScreen landscape test - idle', (tester) async {
    SharedPreferences.setMockInitialValues({'darb.permissions_accepted.v1': true});
    final c = AppController(enableDeviceServices: false);
    await c.load();

    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          controller: c,
          renderMapTiles: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('idle_panel_landscape')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
