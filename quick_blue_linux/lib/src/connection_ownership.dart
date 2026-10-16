/// Coordinates clients of a process-wide Linux Bluetooth connection.
/// Lease identifiers are opaque; Linux combines local adapter and remote address.
abstract interface class QuickBlueLinuxConnectionLease {
  Future<void> attach(String deviceId);

  /// Detaches this client and runs [onLastClient] while new clients are blocked
  /// when no other Flutter engine remains attached.
  Future<void> detach(String deviceId, Future<void> Function() onLastClient);
}

/// Tracks the device leases held by one Linux Flutter-engine instance.
abstract interface class QuickBlueLinuxDisposableConnectionLease {
  Future<void> close();
}

class ConnectionOwnership {
  ConnectionOwnership(this._lease);

  final QuickBlueLinuxConnectionLease _lease;
  final Map<String, String> _leaseIds = <String, String>{};
  final Map<String, Future<void>> _detaching = <String, Future<void>>{};

  List<String> get deviceIds => List.unmodifiable(_leaseIds.keys);

  Future<void> close() async {
    if (_lease case final QuickBlueLinuxDisposableConnectionLease lease) {
      await lease.close();
    }
  }

  bool owns(String deviceId) => _leaseIds.containsKey(deviceId);

  Future<void> attach(String deviceId, {String? leaseId}) async {
    await _detaching[deviceId];
    if (_leaseIds.containsKey(deviceId)) {
      return;
    }
    final identity = leaseId ?? deviceId;
    await _lease.attach(identity);
    _leaseIds[deviceId] = identity;
  }

  Future<void> detach(
    String deviceId, {
    required Future<void> Function() onLastClient,
  }) {
    if (!_leaseIds.containsKey(deviceId)) return Future<void>.value();
    return _detaching[deviceId] ??= Future<void>.microtask(
      () => _detach(deviceId, onLastClient),
    );
  }

  Future<void> _detach(
    String deviceId,
    Future<void> Function() onLastClient,
  ) async {
    // Keep identity visible until teardown settles. Native disconnect events
    // can reenter detach while the final D-Bus unlock reply is still pending.
    final identity = _leaseIds[deviceId]!;
    try {
      await _lease.detach(identity, onLastClient);
      _leaseIds.remove(deviceId);
    } finally {
      _detaching.remove(deviceId);
    }
  }
}
