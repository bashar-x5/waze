import 'package:darb/app/app_controller.dart';
import 'package:darb/domain/demo_data.dart';
import 'package:darb/domain/voice_command_parser.dart';
import 'package:darb/services/android_auto_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidAutoService Voice Integration', () {
    late AppController controller;
    late AndroidAutoService autoService;
    final List<MethodCall> channelInvocations = [];

    setUp(() async {
      channelInvocations.clear();
      SharedPreferences.setMockInitialValues({});
      controller = AppController(enableDeviceServices: false);
      await controller.load();
      controller.setDemoMode(true);

      // Intercept calls sent from AndroidAutoService to Android Auto native host
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('app.darb.darb/android_auto'),
        (MethodCall methodCall) async {
          channelInvocations.add(methodCall);
          return true;
        },
      );

      autoService = AndroidAutoService(controller);
    });

    tearDown(() {
      autoService.dispose();
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('app.darb.darb/android_auto'),
        null,
      );
    });

    test('Voice search "اريد الذهاب لمطعم رويال كالاكسي في المنصور" routes and starts navigation', () async {
      final reply = await autoService.handleMethodCall(
        const MethodCall('onVoiceSearchSubmitted', {
          'query': 'اريد الذهاب لمطعم رويال كالاكسي في المنصور',
        }),
      );

      expect(reply, isA<Map>());
      expect(reply['action'], 'navigating');
      expect(reply['placeId'], 'demo-royal-galaxy');

      // Verify controller updated destination and started navigation
      expect(controller.destination, isNotNull);
      expect(controller.destination!.nameAr, 'مطعم رويال كالاكسي');
      expect(controller.navigating, isTrue);

      // Verify Android Auto was sent updated navigation state
      final updateNavCalls = channelInvocations.where((c) => c.method == 'updateNavState').toList();
      expect(updateNavCalls, isNotEmpty);
      final lastNavArgs = updateNavCalls.last.arguments as Map;
      expect(lastNavArgs['isNavigating'], isTrue);
    });

    test('Voice search with hazard command reports hazard from Android Auto', () async {
      final initialReportsCount = controller.localReports.length;

      final reply = await autoService.handleMethodCall(
        const MethodCall('onVoiceSearchSubmitted', {
          'query': 'اكو سيطرة هنا',
        }),
      );

      expect(reply, isA<Map>());
      expect(reply['action'], 'command_executed');
      expect(reply['intent'], VoiceIntentType.reportHazard.name);

      expect(controller.localReports.length, initialReportsCount + 1);

      final statusCalls = channelInvocations.where((c) => c.method == 'setSearchStatus').toList();
      expect(statusCalls, isNotEmpty);
    });

    test('Voice search with cancel command stops navigation', () async {
      // Start navigation first
      final royalGalaxy = demoPlaces.firstWhere((p) => p.id == 'demo-royal-galaxy');
      await controller.navigateToPlaceFromVoice(royalGalaxy);
      expect(controller.navigating, isTrue);

      final reply = await autoService.handleMethodCall(
        const MethodCall('onVoiceSearchSubmitted', {
          'query': 'الغاء الملاحة',
        }),
      );

      expect(reply, isA<Map>());
      expect(reply['action'], 'command_executed');
      expect(reply['intent'], VoiceIntentType.cancelNavigation.name);
      expect(controller.navigating, isFalse);
    });

    test('Live text/query change sends search results to Android Auto', () async {
      await autoService.handleMethodCall(
        const MethodCall('onSearchQueryChanged', {
          'query': 'رويال',
        }),
      );

      final searchResultCalls = channelInvocations.where((c) => c.method == 'updateSearchResults').toList();
      expect(searchResultCalls, isNotEmpty);
      final results = searchResultCalls.last.arguments as List;
      expect(results, isNotEmpty);
      expect((results.first as Map)['id'], 'demo-royal-galaxy');
    });
  });
}
