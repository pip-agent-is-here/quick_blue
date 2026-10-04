import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_blue/src/android_security_recovery.dart';
import 'package:quick_blue_platform_interface/quick_blue_platform_interface.dart';

/// Covers every branch of [AndroidSecurityRecovery.perform]: the initial state
/// switch (bonded / unknown / bonding / notBonded), implicit-bond recovery,
/// explicit pairing, each failure path, and the "never reports" timeouts.
void main() {
  const deviceId = 'device-a';

  late StreamController<BluetoothBondStateChange> events;
  late List<Timer> scheduledEvents;
  late int pairingCalls;

  /// States returned by successive bond-state reads. Once exhausted, the read
  /// returns [steadyState].
  late List<BluetoothBondState> queuedStates;
  late BluetoothBondState steadyState;

  /// Work performed when pairing is requested, used to model a device that only
  /// starts bonding after [AndroidSecurityRecovery.startPairing] runs.
  Future<void> Function()? onPairing;

  setUp(() {
    events = StreamController<BluetoothBondStateChange>.broadcast();
    scheduledEvents = <Timer>[];
    pairingCalls = 0;
    queuedStates = <BluetoothBondState>[];
    steadyState = BluetoothBondState.notBonded;
    onPairing = null;
  });

  tearDown(() async {
    // Cancel first: a timer left over from one test must never deliver an event
    // into the next test's controller.
    for (final timer in scheduledEvents) {
      timer.cancel();
    }
    if (!events.isClosed) {
      await events.close();
    }
  });

  AndroidSecurityRecovery buildRecovery() {
    return AndroidSecurityRecovery(
      stateChanges: events.stream,
      readState: (_) async =>
          queuedStates.isEmpty ? steadyState : queuedStates.removeAt(0),
      startPairing: (_) async {
        pairingCalls += 1;
        final hook = onPairing;
        if (hook != null) {
          await hook();
        }
      },
      implicitBondStartTimeout: const Duration(milliseconds: 60),
      bondCompletionTimeout: const Duration(milliseconds: 300),
      bondStateQueryTimeout: const Duration(milliseconds: 100),
    );
  }

  /// Emits a bond-state change for [deviceId]. The controller is captured by
  /// value so a delayed event can never leak into a later test.
  void emitBondState(BluetoothBondState state, {Duration? after}) {
    final controller = events;
    void send() {
      if (!controller.isClosed) {
        controller.add(
          BluetoothBondStateChange(
            deviceId: deviceId,
            state: state,
            previousState: BluetoothBondState.notBonded,
          ),
        );
      }
    }

    if (after == null) {
      send();
    } else {
      scheduledEvents.add(Timer(after, send));
    }
  }

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
      await recovery.perform(deviceId),
      QuickBlueSecurityRecoveryResult.userActionRequired,
    );
    expect(listenCalls, 1);
    expect(cancelCalls, 1);
  });

  test(
    'an already bonded device asks the user and never starts pairing',
    () async {
      queuedStates = <BluetoothBondState>[BluetoothBondState.bonded];

      expect(
        await buildRecovery().perform(deviceId),
        QuickBlueSecurityRecoveryResult.userActionRequired,
      );
      expect(pairingCalls, 0);
    },
  );

  test('an unknown bond state reports unsupported', () async {
    queuedStates = <BluetoothBondState>[BluetoothBondState.unknown];

    expect(
      await buildRecovery().perform(deviceId),
      QuickBlueSecurityRecoveryResult.unsupported,
    );
    expect(pairingCalls, 0);
  });

  test(
    'a bonding device that reaches bonded is reported as recovered',
    () async {
      queuedStates = <BluetoothBondState>[BluetoothBondState.bonding];
      steadyState = BluetoothBondState.bonding;
      emitBondState(
        BluetoothBondState.bonded,
        after: const Duration(milliseconds: 10),
      );

      expect(
        await buildRecovery().perform(deviceId),
        QuickBlueSecurityRecoveryResult.recovered,
      );
      expect(pairingCalls, 0);
    },
  );

  test('a bonding device that never completes asks the user', () async {
    queuedStates = <BluetoothBondState>[BluetoothBondState.bonding];
    steadyState = BluetoothBondState.bonding;

    expect(
      await buildRecovery().perform(deviceId),
      QuickBlueSecurityRecoveryResult.userActionRequired,
    );
    expect(pairingCalls, 0);
  });

  test(
    'an implicit bond that reports bonded straight away needs no pairing',
    () async {
      emitBondState(
        BluetoothBondState.bonded,
        after: const Duration(milliseconds: 10),
      );

      expect(
        await buildRecovery().perform(deviceId),
        QuickBlueSecurityRecoveryResult.recovered,
      );
      expect(pairingCalls, 0);
    },
  );

  test('an implicit bond that starts then completes is recovered', () async {
    steadyState = BluetoothBondState.bonding;
    emitBondState(
      BluetoothBondState.bonding,
      after: const Duration(milliseconds: 10),
    );
    emitBondState(
      BluetoothBondState.bonded,
      after: const Duration(milliseconds: 40),
    );

    expect(
      await buildRecovery().perform(deviceId),
      QuickBlueSecurityRecoveryResult.recovered,
    );
    expect(pairingCalls, 0);
  });

  test('an implicit bond that starts and fails asks the user', () async {
    steadyState = BluetoothBondState.bonding;
    emitBondState(
      BluetoothBondState.bonding,
      after: const Duration(milliseconds: 10),
    );
    emitBondState(
      BluetoothBondState.notBonded,
      after: const Duration(milliseconds: 40),
    );

    expect(
      await buildRecovery().perform(deviceId),
      QuickBlueSecurityRecoveryResult.userActionRequired,
    );
    expect(pairingCalls, 0);
  });

  test('an explicit pairing that reaches bonded is recovered', () async {
    onPairing = () async {
      // The device starts bonding only after pairing has been requested.
      steadyState = BluetoothBondState.bonding;
      emitBondState(
        BluetoothBondState.bonding,
        after: const Duration(milliseconds: 10),
      );
      emitBondState(
        BluetoothBondState.bonded,
        after: const Duration(milliseconds: 40),
      );
    };

    expect(
      await buildRecovery().perform(deviceId),
      QuickBlueSecurityRecoveryResult.recovered,
    );
    expect(pairingCalls, 1);
  });

  test(
    'an explicit pairing that reports bonded straight away is recovered',
    () async {
      onPairing = () async {
        steadyState = BluetoothBondState.bonding;
        emitBondState(
          BluetoothBondState.bonded,
          after: const Duration(milliseconds: 10),
        );
      };

      expect(
        await buildRecovery().perform(deviceId),
        QuickBlueSecurityRecoveryResult.recovered,
      );
      expect(pairingCalls, 1);
    },
  );

  test(
    'an explicit pairing that never reports a state asks the user',
    () async {
      onPairing = () async {
        steadyState = BluetoothBondState.bonding;
      };

      expect(
        await buildRecovery().perform(deviceId),
        QuickBlueSecurityRecoveryResult.userActionRequired,
      );
      expect(pairingCalls, 1);
    },
  );

  test('a failing bond-state read asks the user', () async {
    final recovery = AndroidSecurityRecovery(
      stateChanges: events.stream,
      readState: (_) async => throw StateError('read failed'),
      startPairing: (_) async {},
      bondStateQueryTimeout: const Duration(milliseconds: 20),
    );

    expect(
      await recovery.perform(deviceId),
      QuickBlueSecurityRecoveryResult.userActionRequired,
    );
    expect(pairingCalls, 0);
  });

  test('a failing explicit pairing asks the user', () async {
    final recovery = AndroidSecurityRecovery(
      stateChanges: events.stream,
      readState: (_) async => BluetoothBondState.notBonded,
      startPairing: (_) async => throw StateError('pairing failed'),
      implicitBondStartTimeout: const Duration(milliseconds: 20),
      bondStateQueryTimeout: const Duration(milliseconds: 100),
    );

    expect(
      await recovery.perform(deviceId),
      QuickBlueSecurityRecoveryResult.userActionRequired,
    );
  });

  test('a bond-state stream error asks the user', () async {
    final controller = events;
    scheduledEvents.add(
      Timer(const Duration(milliseconds: 30), () {
        controller.addError(StateError('stream failed'));
      }),
    );

    expect(
      await buildRecovery().perform(deviceId),
      QuickBlueSecurityRecoveryResult.userActionRequired,
    );
  });

  test('a state change for another device is ignored', () async {
    events.add(
      const BluetoothBondStateChange(
        deviceId: 'device-b',
        state: BluetoothBondState.bonded,
        previousState: BluetoothBondState.notBonded,
      ),
    );

    expect(
      await buildRecovery().perform(deviceId),
      QuickBlueSecurityRecoveryResult.userActionRequired,
    );
  });
}
