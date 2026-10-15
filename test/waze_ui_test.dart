import 'package:darb/app/app_controller.dart';
import 'package:darb/app/darb_app.dart';
import 'package:darb/domain/demo_data.dart';
import 'package:darb/domain/models.dart';
import 'package:darb/domain/navigation_engine.dart';
import 'package:darb/ui/home_screen.dart';
import 'package:darb/ui/widgets/waze_bottom_panel.dart';
import 'package:darb/ui/widgets/waze_incident_popup.dart';
import 'package:darb/ui/widgets/waze_nav_hud.dart';
import 'package:darb/ui/widgets/waze_report_sheet.dart';
import 'package:darb/ui/widgets/waze_speedometer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Waze UI Components', () {
    testWidgets('Speedometer renders speed and unit properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WazeSpeedometer(
              speedKph: 55,
              miles: false,
              dark: false,
            ),
          ),
        ),
      );

      expect(find.text('55'), findsOneWidget);
      expect(find.text('km/h'), findsOneWidget);
    });

    testWidgets('Speedometer renders mph when miles is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WazeSpeedometer(
              speedKph: 100,
              miles: true,
              dark: true,
            ),
          ),
        ),
      );

      expect(find.text('62'), findsOneWidget);
      expect(find.text('mph'), findsOneWidget);
    });

    testWidgets('WazeReportSheet displays report categories and triggers submit', (tester) async {
      ReportType? submittedType;
      String? submittedComment;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WazeReportSheet(
              arabic: false,
              dark: false,
              onSubmit: (type, comment) async {
                submittedType = type;
                submittedComment = comment;
              },
            ),
          ),
        ),
      );

      expect(find.text('Share a Road Alert'), findsOneWidget);
      expect(find.text('Police'), findsOneWidget);
      expect(find.text('Traffic'), findsOneWidget);
      expect(find.text('Hazard'), findsOneWidget);

      // Tap Police
      await tester.tap(find.text('Police'));
      await tester.pump();

      expect(find.text('Send Alert Now'), findsOneWidget);

      // Enter comment
      await tester.enterText(find.byType(TextField), 'Speed trap ahead');
      await tester.pump();

      // Tap Send
      await tester.tap(find.text('Send Alert Now'));
      await tester.pump();

      expect(submittedType, ReportType.police);
      expect(submittedComment, 'Speed trap ahead');
    });

    testWidgets('WazeIncidentPopup displays alert and triggers confirmation', (tester) async {
      var confirmed = false;
      final report = RoadReport(
        id: 'rep-1',
        type: ReportType.traffic,
        point: baghdadCenter,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        description: 'Heavy traffic on expressway',
        confirmations: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WazeIncidentPopup(
              report: report,
              arabic: false,
              dark: false,
              isConfirmed: false,
              onConfirm: () {
                confirmed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Traffic'), findsOneWidget);
      expect(find.text('Heavy traffic on expressway'), findsOneWidget);
      expect(find.text('Still there'), findsOneWidget);

      await tester.tap(find.text('Still there'));
      await tester.pump();

      expect(confirmed, isTrue);
    });

    testWidgets('WazeNavHud shows turn instructions and distance', (tester) async {
      final sampleRoute = demoRoutes(demoPlaces.first).first;
      final progress = calculateProgress(sampleRoute, sampleRoute.points.first);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WazeNavHud(
              route: sampleRoute,
              progress: progress,
              arabic: false,
              miles: false,
              onTapList: () {},
            ),
          ),
        ),
      );

      expect(find.text(sampleRoute.steps.first.instruction), findsOneWidget);
    });

    testWidgets('DarbApp loads and displays HomeScreen with map', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = AppController(enableDeviceServices: false);
      await controller.load();

      await tester.pumpWidget(
        DarbApp(
          controller: controller,
          renderMapTiles: false,
        ),
      );
      await tester.pump();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(WazeBottomPanel), findsOneWidget);
      expect(find.text('Where to?'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    testWidgets('Parking slot feature saves spot, displays card, and navigates', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = AppController(enableDeviceServices: false);
      await controller.load();

      expect(controller.parkedLocation, isNull);
      expect(controller.showParkingPrompt, isFalse);

      controller.saveParkingLocation(point: baghdadCenter, note: 'Near gate 3');
      expect(controller.parkedLocation, isNotNull);
      expect(controller.parkedLocation!.point, baghdadCenter);
      expect(controller.parkedLocation!.note, 'Near gate 3');

      await tester.pumpWidget(
        DarbApp(
          controller: controller,
          renderMapTiles: false,
        ),
      );
      await tester.pump();

      expect(find.text('My Parked Car'), findsOneWidget);
      expect(find.text('Near gate 3'), findsOneWidget);

      await controller.navigateToParkedCar();
      expect(controller.destination, isNotNull);
      expect(controller.destination!.category, PlaceCategory.parking);
      expect(controller.destination!.point, baghdadCenter);

      controller.clearParkingLocation();
      expect(controller.parkedLocation, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    testWidgets('Arrival triggers parking prompt banner and can be dismissed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = AppController(enableDeviceServices: false);
      await controller.load();

      controller.showParkingPrompt = true;

      await tester.pumpWidget(
        DarbApp(
          controller: controller,
          renderMapTiles: false,
        ),
      );
      await tester.pump();

      expect(find.text("You've Arrived!"), findsOneWidget);

      controller.dismissParkingPrompt();
      await tester.pump();
      expect(find.text("You've Arrived!"), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  });
}
