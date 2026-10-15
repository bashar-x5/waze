import 'package:flutter_test/flutter_test.dart';
import 'package:darb/domain/voice_command_parser.dart';

void main() {
  const parser = VoiceCommandParser();

  group('VoiceCommandParser Navigation Intents', () {
    test('parses exact user phrase: اريد الذهاب لمطعم رويال كالاكسي في المنصور', () {
      final res = parser.parse('اريد الذهاب لمطعم رويال كالاكسي في المنصور');
      expect(res.intent, equals(VoiceIntentType.navigate));
      expect(res.destinationQuery, equals('مطعم رويال كالاكسي المنصور'));
    });

    test('parses Firdos Square: اريد الذهاب لساحة الفردوس', () {
      final res = parser.parse('اريد الذهاب لساحة الفردوس');
      expect(res.intent, equals(VoiceIntentType.navigate));
      expect(res.destinationQuery, equals('ساحة الفردوس'));
    });

    test('parses Iraqi phrasing: وديني لمول بغداد الحارثية', () {
      final res = parser.parse('وديني لمول بغداد الحارثية');
      expect(res.intent, equals(VoiceIntentType.navigate));
      expect(res.destinationQuery, equals('مول بغداد الحارثية'));
    });

    test('parses Iraqi phrasing: اخذني للكرادة داخل', () {
      final res = parser.parse('اخذني للكرادة داخل');
      expect(res.intent, equals(VoiceIntentType.navigate));
      expect(res.destinationQuery.contains('كرادة'), isTrue);
    });

    test('parses Iraqi phrasing: وصلني لمستشفى اليرموك', () {
      final res = parser.parse('وصلني لمستشفى اليرموك');
      expect(res.intent, equals(VoiceIntentType.navigate));
      expect(res.destinationQuery, equals('مستشفى اليرموك'));
    });

    test('parses English navigation: Take me to Royal Galaxy restaurant', () {
      final res = parser.parse('Take me to Royal Galaxy restaurant');
      expect(res.intent, equals(VoiceIntentType.navigate));
      expect(res.destinationQuery, equals('Royal Galaxy restaurant'));
    });

    test('parses cancel navigation', () {
      final res = parser.parse('الغاء الملاحة');
      expect(res.intent, equals(VoiceIntentType.cancelNavigation));
    });

    test('parses mute sound', () {
      final res = parser.parse('كتم الصوت');
      expect(res.intent, equals(VoiceIntentType.muteSound));
    });

    test('parses hazard reporting', () {
      final res = parser.parse('بلاغ عن مطب');
      expect(res.intent, equals(VoiceIntentType.reportHazard));
      expect(res.hazardType, equals('bump'));
    });
  });
}
