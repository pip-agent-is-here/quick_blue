@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_blue_platform_interface/quick_blue_platform_interface.dart';
import 'package:quick_blue_web/quick_blue_web.dart';
import 'package:quick_blue_example/web_bluetooth_hardware.dart';

@JS('eval')
external JSAny? evaluate(JSString source);

void main() {
  testWidgets(
    'missing hardware profile is BLOCKED and read-only is the default',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HardwarePage()));
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      final run = find.text('Select device and run loops');
      await tester.ensureVisible(run);
      await tester.tap(run);
      await tester.pumpAndSettle();
      final report = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      final decoded = jsonDecode(report) as Map<String, dynamic>;
      expect(decoded['aggregate'], 'BLOCKED');
      expect(report, contains('Provide adapter'));
    },
  );
  testWidgets(
    'unavailable real browser API blocks all hardware stages, never PASS',
    (tester) async {
      evaluate('delete navigator.bluetooth'.toJS);
      QuickBluePlatform.instance = QuickBlueWeb();
      await tester.pumpWidget(const MaterialApp(home: HardwarePage()));
      final input = tester.widget<TextField>(find.byType(TextField));
      final p = jsonDecode(input.controller!.text) as Map<String, dynamic>;
      // Explicitly a UI-validation fixture, not a claim about real peripherals.
      p['adapter'] = 'fixture';
      p['peripheral'] = 'fixture';
      p['firmware'] = 'fixture';
      input.controller!.text = jsonEncode(p);
      final run = find.text('Select device and run loops');
      await tester.ensureVisible(run);
      await tester.tap(run);
      await tester.pumpAndSettle();
      final decoded =
          jsonDecode(
                tester
                    .widget<SelectableText>(find.byType(SelectableText))
                    .data!,
              )
              as Map<String, dynamic>;
      expect(decoded['aggregate'], 'BLOCKED');
      final stages = (decoded['stages'] as List).cast<Map<String, dynamic>>();
      expect(
        stages.where((s) => s['stage'] == 'selection').single['result'],
        'BLOCKED',
      );
      expect(stages.any((s) => s['result'] == 'PASS'), false);
      expect(decoded['selectedDeviceId'], null);
    },
  );
}
