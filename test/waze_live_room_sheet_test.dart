import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:darb/app/app_controller.dart';
import 'package:darb/domain/demo_data.dart';
import 'package:darb/domain/models.dart';
import 'package:darb/ui/widgets/waze_live_room_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WazeLiveRoomSheet Convoy & Track Tests', () {
    testWidgets('renders creation form and convoy destination chips in Arabic', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({'darb.language.arabic': true});
      final controller = AppController(enableDeviceServices: false);
      addTearDown(controller.dispose);
      controller.arabic = true;

      bool fitTrackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WazeLiveRoomSheet(
              controller: controller,
              onFitTrack: () {
                fitTrackCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Title & Subtitle in Arabic
      expect(find.text('دَرب شلّة — مشاركة الموقع المباشر'), findsOneWidget);
      expect(find.text('إنشاء غرفة جديدة'), findsOneWidget);

      // Verify Shared Convoy Destination card prompt
      expect(find.text('وجهة الموكب المشتركة'), findsOneWidget);
      expect(find.text('اختيار وجهة من البحث أو المحفوظات 🔍'), findsOneWidget);

      // Tap on a landmark chip (e.g. Al-Mutanabbi Street)
      final chipFinder = find.text(demoPlaces.first.label(true));
      expect(chipFinder, findsOneWidget);
      await tester.ensureVisible(chipFinder);
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Destination should now be set and onFitTrack should have been called!
      expect(controller.destination, isNotNull);
      expect(controller.destination!.nameAr, demoPlaces.first.nameAr);
      expect(fitTrackCalled, isTrue);

      // Verify Track card now displays shared convoy track
      expect(find.text('مسار الشلّة المشترك 🚗'), findsOneWidget);
      expect(find.text('معاينة المسار على الخريطة (تصغير اللوحة) 🗺️'), findsOneWidget);

      // Tapping "معاينة المسار على الخريطة" triggers onFitTrack
      fitTrackCalled = false;
      await tester.tap(find.text('معاينة المسار على الخريطة (تصغير اللوحة) 🗺️'));
      await tester.pumpAndSettle();
      expect(fitTrackCalled, isTrue);
    });

    testWidgets('renders Active Room view with convoy destination card and overview action', (tester) async {
      SharedPreferences.setMockInitialValues({'darb.language.arabic': false});
      final controller = AppController(enableDeviceServices: false);
      addTearDown(controller.dispose);
      controller.arabic = false;

      final now = DateTime.now().toUtc();
      controller.activeLiveRoom = LiveRoom(
        code: 'XYZ123',
        name: 'Weekend Drive',
        mode: 'convoy',
        creatorId: controller.userId,
        creatorName: 'Bashar',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 2)),
        shareUrl: 'http://139.185.47.123:5000/track.html?code=XYZ123',
        destinationName: 'Baghdad Mall',
        destinationPoint: baghdadCenter,
        members: [
          LiveRoomMember(
            memberId: controller.userId,
            displayName: 'Bashar',
            avatarColor: '#00E676',
            point: baghdadCenter,
            updatedAt: now,
            speedKmh: 45,
            heading: 90,
            isCreator: true,
          ),
          LiveRoomMember(
            memberId: 'member-2',
            displayName: 'Ahmed',
            avatarColor: '#00C8F8',
            point: baghdadCenter,
            updatedAt: now,
            speedKmh: 40,
            heading: 90,
            isCreator: false,
          ),
        ],
      );

      bool fitTrackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WazeLiveRoomSheet(
              controller: controller,
              onFitTrack: () {
                fitTrackCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Active Room info
      expect(find.text('Weekend Drive'), findsOneWidget);
      expect(find.text('XYZ123'), findsOneWidget);
      expect(find.text('Baghdad Mall'), findsOneWidget);
      expect(find.text('Shared Convoy Track 🚗'), findsOneWidget);

      // Tap peek track
      await tester.tap(find.text('Peek Track on Map (Minimize) 🗺️'));
      await tester.pumpAndSettle();
      expect(fitTrackCalled, isTrue);
    });
  });
}
