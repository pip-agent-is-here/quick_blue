import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_blue/src/android_security_recovery.dart';
import 'package:quick_blue_platform_interface/quick_blue_platform_interface.dart';

void main() {
  test('a bond timeout cancels its state subscription', () async {
    var listenCalls = 0;
    var cancelCalls = 0;
    final stateChanges = StreamController<BluetoothBondStateChange>.broadcast(
      onListen: () => listenCalls += 1,
      onCancel: () => cancelCalls += 1,
    );
    addTearDown(stateChanges.close);
    final recovery = AndroidSecurityRecovery(
      stateChanges: stateChanges.stream,
      readState: (_) async => BluetoothBondState.bonding,
      startPairing: (_) async {},
      bondCompletionTimeout: const Duration(milliseconds: 10),
      bondStateQueryTimeout: const Duration(milliseconds: 100),
    );

    expect(
      await recovery.perform('device-a'),
      QuickBlueSecurityRecoveryResult.userActionRequired,
    );
    expect(listenCalls, 1);
    expect(cancelCalls, 1);
  });
}
