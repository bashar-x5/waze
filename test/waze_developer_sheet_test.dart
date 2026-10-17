import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:darb/app/app_controller.dart';
import 'package:darb/ui/widgets/waze_developer_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('WazeDeveloperSheet renders developer details and contact channels in Arabic', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'darb.language.arabic': true});
    final controller = AppController(enableDeviceServices: false);
    addTearDown(controller.dispose);
    controller.arabic = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WazeDeveloperSheet(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Developer Name (both Arabic and English are displayed)
    expect(find.text('بشار محمود لفته'), findsOneWidget);
    expect(find.text('Bashar Mahmoud Lafta'), findsOneWidget);

    // Scroll down to build and reveal contact cards
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();

    // Verify Developer Phone Number & Email
    expect(find.text('07718239496'), findsWidgets);
    expect(find.text('extra.jassim@gmail.com'), findsOneWidget);

    // Verify Role and Iraq label
    expect(find.text('مطور ومؤسس تطبيق دَرب للملاحة'), findsOneWidget);
    expect(find.text('العراق • بغداد'), findsOneWidget);
  });

  testWidgets('WazeDeveloperSheet renders developer details in English mode', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'darb.language.arabic': false});
    final controller = AppController(enableDeviceServices: false);
    addTearDown(controller.dispose);
    controller.arabic = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WazeDeveloperSheet(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Developer Name
    expect(find.text('بشار محمود لفته'), findsOneWidget);
    expect(find.text('Bashar Mahmoud Lafta'), findsOneWidget);

    // Verify English role
    expect(find.text('Creator & Lead Developer of Darb Navigation'), findsOneWidget);
    expect(find.text('Baghdad, Iraq'), findsOneWidget);
  });
}
