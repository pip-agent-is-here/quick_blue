import 'dart:async';

import 'package:meta/meta.dart';

import '../models.dart';
import 'cancellation_signal.dart';
import 'observability.dart';
import 'quick_blue_exception.dart';

/// The two connection operations with every string and observation kind they
/// need, so a typo is a compile error instead of a silently-unmatched
/// comparison or a wrong-kind observation.
enum _ConnectionOperationKind {
  connect(name: 'connect', observationKind: QuickBlueOperationKind.connect),
  disconnect(
    name: 'disconnect',
    observationKind: QuickBlueOperationKind.disconnect,
  );

  const _ConnectionOperationKind({
    required this.name,
    required this.observationKind,
  });

  /// The operation name used in error messages and `QuickBlueException.operation`.
  final String name;

  /// The observation kind reported to the instrumentation observer.
  final QuickBlueOperationKind observationKind;
}

@internal
class ConnectionLifecycleCoordinator {
  ConnectionLifecycleCoordinator({
    required this.connect,
    required this.disconnect,
    required this.connectionStateStream,
  });

  final Future<void> Function(String deviceId) connect;
  final Future<void> Function(String deviceId) disconnect;
  final Stream<BluetoothConnectionStateChange> Function() connectionStateStream;

  final _activeOperations = <String, _ConnectionOperation>{};

  Future<void> connectDevice(String deviceId) async {
    final activeOperation = _activeOperations[deviceId];
    if (activeOperation?.kind == _ConnectionOperationKind.disconnect) {
      activeOperation!.cancellation.cancel();
      try {
        await activeOperation.completed;
      } on Object {
        // The reconnect is authoritative even if the superseded disconnect
        // fails or was abandoned by a caller-side timeout.
      }
    }

    return _runOperation(
      deviceId: deviceId,
      operationKind: _ConnectionOperationKind.connect,
      targetState: BlueConnectionState.connected,
      failureMessage: 'Failed to connect to Bluetooth device $deviceId.',
      operation: (cancellation) =>
          _connectWhenAvailable(deviceId, cancellation),
    );
  }

  Future<void> _connectWhenAvailable(
    String deviceId,
    _ConnectionOperationCancellation cancellation,
  ) async {
    const busyTimeout = Duration(seconds: 30);
    final stopwatch = Stopwatch()..start();
    while (true) {
      try {
        await cancellation.untilCancelled(
          connect(deviceId),
          error: _cancelledException(
            deviceId,
            _ConnectionOperationKind.connect.name,
          ),
        );
        return;
      } on QuickBlueException catch (error) {
        if (error.code != QuickBlueErrorCode.deviceBusy) {
          rethrow;
        }
        if (stopwatch.elapsed >= busyTimeout) {
          throw QuickBlueException(
            code: QuickBlueErrorCode.deviceBusy,
            operation: 'connect',
            deviceId: deviceId,
            details: busyTimeout,
            message:
                'Timed out waiting for the shared connection to $deviceId '
                'to finish disconnecting.',
          );
        }
        await cancellation.untilCancelled(
          Future<void>.delayed(const Duration(milliseconds: 100)),
          error: _cancelledException(
            deviceId,
            _ConnectionOperationKind.connect.name,
          ),
        );
      }
    }
  }

  Future<void> disconnectDevice(String deviceId) async {
    final activeOperation = _activeOperations[deviceId];
    if (activeOperation?.kind == _ConnectionOperationKind.connect) {
      activeOperation!.cancellation.cancel();
      try {
        await activeOperation.completed;
      } on Object {
        // The disconnect is authoritative even if the superseded connect fails.
      }
    }

    return _runOperation(
      deviceId: deviceId,
      operationKind: _ConnectionOperationKind.disconnect,
      targetState: BlueConnectionState.disconnected,
      failureMessage: 'Failed to disconnect Bluetooth device $deviceId.',
      operation: (_) => disconnect(deviceId),
    );
  }

  Future<void> _runOperation({
    required String deviceId,
    required _ConnectionOperationKind operationKind,
    required BlueConnectionState targetState,
    required String failureMessage,
    required Future<void> Function(
      _ConnectionOperationCancellation cancellation,
    )
    operation,
  }) {
    final operationName = operationKind.name;
    final observation = QuickBlueInstrumentation.startOperation(
      operationKind.observationKind,
      deviceId: deviceId,
    );
    final activeOperation = _activeOperations[deviceId];
    if (activeOperation != null) {
      return QuickBlueInstrumentation.observeCompletion<void>(
        Future<void>.error(
          QuickBlueException(
            code: QuickBlueErrorCode.invalidState,
            operation: operationName,
            deviceId: deviceId,
            details: activeOperation.kind.name,
            message:
                'Cannot $operationName Bluetooth device $deviceId while '
                '${activeOperation.kind.name} is pending.',
          ),
        ),
        observation,
      );
    }
    final connectionOperation = _ConnectionOperation(operationKind);
    _activeOperations[deviceId] = connectionOperation;
    connectionOperation.completed = _executeOperation(
      deviceId: deviceId,
      connectionOperation: connectionOperation,
      targetState: targetState,
      failureMessage: failureMessage,
      operation: operation,
    );
    return QuickBlueInstrumentation.observeCompletion<void>(
      connectionOperation.completed,
      observation,
    );
  }

  Future<void> _executeOperation({
    required String deviceId,
    required _ConnectionOperation connectionOperation,
    required BlueConnectionState targetState,
    required String failureMessage,
    required Future<void> Function(
      _ConnectionOperationCancellation cancellation,
    )
    operation,
  }) async {
    final operationName = connectionOperation.kind.name;
    final cancellation = connectionOperation.cancellation;

    final stateCompleter = Completer<BluetoothConnectionStateChange>();
    final stateSubscription = connectionStateStream()
        .where(
          (event) =>
              event.deviceId == deviceId &&
              (event.status == BleStatus.failure || event.state == targetState),
        )
        .listen((state) {
          if (!stateCompleter.isCompleted) {
            stateCompleter.complete(state);
          }
        });

    try {
      final cancellationError = _cancelledException(deviceId, operationName);
      await cancellation.untilCancelled(
        operation(cancellation),
        error: cancellationError,
      );
      final state = await cancellation.untilCancelled(
        stateCompleter.future,
        error: cancellationError,
      );
      if (state.status == BleStatus.failure) {
        if (state.error != null) {
          throw state.error!;
        }
        throw QuickBlueException(
          code: QuickBlueErrorCode.operationFailed,
          operation: operationName,
          deviceId: deviceId,
          details: state.status,
          message: failureMessage,
        );
      }
    } finally {
      await stateSubscription.cancel();
      if (_activeOperations[deviceId] == connectionOperation) {
        _activeOperations.remove(deviceId);
      }
    }
  }

  QuickBlueException _cancelledException(
    String deviceId,
    String operationName,
  ) {
    return QuickBlueException(
      code: QuickBlueErrorCode.cancelled,
      operation: operationName,
      deviceId: deviceId,
      message:
          '${operationName[0].toUpperCase()}${operationName.substring(1)} '
          'for Bluetooth device $deviceId was cancelled.',
    );
  }
}

class _ConnectionOperation {
  _ConnectionOperation(this.kind);

  final _ConnectionOperationKind kind;
  final cancellation = _ConnectionOperationCancellation();
  late final Future<void> completed;
}

class _ConnectionOperationCancellation {
  final CancellationSignal _signal = CancellationSignal();

  bool get isCancelled => _signal.isCancelled;

  void cancel() => _signal.cancel();

  Future<T> untilCancelled<T>(
    Future<T> operation, {
    required QuickBlueException error,
  }) {
    return _signal.race<T>(operation, cancellationError: error);
  }
}
