import 'package:dbus/dbus.dart';
import 'package:quick_blue_linux/quick_blue_linux.dart';
import 'package:quick_blue_linux/src/connection_lease.dart';
import 'package:test/test.dart';

import 'adapter_selection_test.dart' as fake;

void main() {
  for (final closeOnly in [false, true]) {
    test(
      'different adapters release independently (closeOnly=$closeOnly)',
      () async {
        final a = fake.Adapter('02:00:00:00:00:01');
        final b = fake.Adapter('02:00:00:00:00:02');
        const remote = '02:00:00:00:00:03';
        final da = fake.Device(a, remote)..connected = false;
        final db = fake.Device(b, remote)..connected = false;
        final owners = <String, String>{};
        final pa = platform([a, b], [da, db], a.address, owners, ':1.1');
        final pb = platform([a, b], [da, db], b.address, owners, ':1.2');
        await pa.device(remote).connect();
        await pb.device(remote).connect();
        expect(owners.length, 2);
        if (closeOnly) {
          await pa.close();
        } else {
          await pa.device(remote).disconnect();
        }
        expect(da.disconnects, 1);
        expect(da.connected, isFalse);
        expect(db.disconnects, 0);
        expect(db.connected, isTrue);
        expect(owners.length, 1);
        if (!closeOnly) await pb.device(remote).disconnect();
        await pa.close();
        await pb.close();
        expect(db.disconnects, 1);
        expect(db.connected, isFalse);
        expect(owners, isEmpty);
      },
    );
  }

  test(
    'default and explicit clients share the same adapter until final close',
    () async {
      final adapter = fake.Adapter('02:00:00:00:00:01');
      final device = fake.Device(adapter)..connected = false;
      final owners = <String, String>{};
      final a = platform([adapter], [device], null, owners, ':1.1');
      final b = platform([adapter], [device], adapter.address, owners, ':1.2');
      await a.device(device.address).connect();
      await b.device(device.address).connect();
      await a.device(device.address).disconnect();
      expect(device.disconnects, 0);
      expect(device.connected, isTrue);
      expect(owners.length, 1);
      await a.close();
      await b.close();
      await b.close();
      expect(device.disconnects, 1);
      expect(device.connected, isFalse);
      expect(owners, isEmpty);
    },
  );

  test('failed selected-adapter connect releases only its own lease', () async {
    final a = fake.Adapter('02:00:00:00:00:01');
    final b = fake.Adapter('02:00:00:00:00:02');
    const remote = '02:00:00:00:00:03';
    final da = fake.Device(a, remote)..connected = false;
    final db = FailingDevice(b, remote)..connected = false;
    final owners = <String, String>{};
    final pa = platform([a, b], [da, db], a.address, owners, ':1.1');
    final pb = platform([a, b], [da, db], b.address, owners, ':1.2');
    await pa.device(remote).connect();
    await expectLater(pb.connect(remote), throwsStateError);
    expect(owners.length, 1);
    await pb.close();
    expect(da.connected, isTrue);
    await pa.close();
    expect(da.disconnects, 1);
    expect(owners, isEmpty);
  });
}

QuickBlueLinux platform(
  List<fake.Adapter> adapters,
  List<fake.Device> devices,
  String? address,
  Map<String, String> owners,
  String uniqueName,
) {
  final client = fake.Client(adapters)..deviceList = devices;
  addTearDown(client.removed.close);
  final result = QuickBlueLinux.withClient(
    client,
    adapterAddress: address,
    connectionLease: DbusConnectionLease.withBus(Bus(owners, uniqueName)),
  );
  addTearDown(result.close);
  return result;
}

class FailingDevice extends fake.Device {
  FailingDevice(super.adapter, super.remoteAddress);
  @override
  Future<void> connect() async => throw StateError('connect');
}

class Bus implements ConnectionLeaseBus {
  Bus(this.owners, this.uniqueName);
  final Map<String, String> owners;
  @override
  final String uniqueName;
  @override
  Future<DBusRequestNameReply> requestName(
    String name, {
    Set<DBusRequestNameFlag> flags = const {},
  }) async {
    if (owners[name] == uniqueName) return DBusRequestNameReply.alreadyOwner;
    if (owners.containsKey(name)) return DBusRequestNameReply.exists;
    owners[name] = uniqueName;
    return DBusRequestNameReply.primaryOwner;
  }

  @override
  Future<void> releaseName(String name) async {
    if (owners[name] == uniqueName) owners.remove(name);
  }

  @override
  Future<List<String>> listNames() async => owners.keys.toList();
}
