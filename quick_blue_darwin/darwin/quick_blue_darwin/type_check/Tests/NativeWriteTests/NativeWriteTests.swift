import XCTest
import CoreBluetooth
import Flutter
import QuickBlueRestorationSummary
@testable import QuickBlueDarwinPluginTypeCheck

private final class Messenger: FlutterBinaryMessenger {}

private final class RecordingPeripheral: CBPeripheral {
    var writes: [(Data, CBCharacteristicWriteType)] = []
    var acknowledgedLimit = 512
    var commandLimit = 97

    override func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int {
        type == .withResponse ? acknowledgedLimit : commandLimit
    }

    override func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {
        writes.append((data, type))
    }
}

final class NativeWriteTests: XCTestCase {
    func testNativeLimitsBackpressureAndCompletion() throws {
        let peripheral = RecordingPeripheral()
        peripheral.state = .connected
        peripheral.canSendWriteWithoutResponse = true
        let service = CBService()
        service.uuid = CBUUID(string: "180d")
        let characteristic = CBCharacteristic()
        characteristic.uuid = CBUUID(string: "2a37")
        characteristic.properties = [.write, .writeWithoutResponse]
        characteristic.service = service
        service.characteristics = [characteristic]
        peripheral.services = [service]
        CBCentralManager.testPeripherals = [peripheral]
        defer { CBCentralManager.testPeripherals = [] }
        let plugin = QuickBlueDarwinPlugin(
            flutterApi: QuickBlueFlutterApi(binaryMessenger: Messenger()),
            restorationBootstrapPolicy: CoreBluetoothRestorationBootstrapPolicy(persistentOptIn: false)
        )
        let deviceId = peripheral.identifier.uuidString
        try plugin.connect(deviceId: deviceId)
        XCTAssertEqual(try plugin.maximumWriteValueLength(deviceId: deviceId, bleOutputProperty: .withResponse), 512)
        XCTAssertEqual(try plugin.maximumWriteValueLength(deviceId: deviceId, bleOutputProperty: .withoutResponse), 97)
        peripheral.commandLimit = 80
        XCTAssertEqual(try plugin.maximumWriteValueLength(deviceId: deviceId, bleOutputProperty: .withoutResponse), 80)

        func write(_ size: Int, _ mode: PlatformBleOutputProperty, _ completion: @escaping (Result<Void, Error>) -> Void) {
            plugin.writeValue(
                deviceId: deviceId, service: "180d", characteristic: "2a37",
                value: FlutterStandardTypedData(bytes: Data(repeating: 1, count: size)),
                bleOutputProperty: mode, completion: completion
            )
        }

        var commandCompletions = 0
        write(80, .withoutResponse) { result in
            if case .failure(let error) = result { XCTFail("Unexpected error: \(error)") }
            commandCompletions += 1
        }
        XCTAssertEqual(commandCompletions, 1)
        XCTAssertEqual(peripheral.writes.count, 1)

        peripheral.canSendWriteWithoutResponse = false
        var busyError: String?
        write(1, .withoutResponse) { result in
            if case .failure(let error) = result { busyError = (error as? PigeonError)?.code }
        }
        XCTAssertEqual(busyError, "InvalidState")
        XCTAssertEqual(peripheral.writes.count, 1)

        var lengthError: String?
        write(81, .withoutResponse) { result in
            if case .failure(let error) = result { lengthError = (error as? PigeonError)?.code }
        }
        XCTAssertEqual(lengthError, "IllegalArgument")
        XCTAssertEqual(peripheral.writes.count, 1)

        var acknowledgedCompletions = 0
        write(512, .withResponse) { result in
            if case .failure(let error) = result { XCTFail("Unexpected error: \(error)") }
            acknowledgedCompletions += 1
        }
        XCTAssertEqual(acknowledgedCompletions, 0)
        XCTAssertEqual(peripheral.writes.count, 2)
        peripheral.delegate?.peripheral(peripheral, didWriteValueFor: characteristic, error: nil)
        XCTAssertEqual(acknowledgedCompletions, 1)

        peripheral.canSendWriteWithoutResponse = true
        write(1, .withoutResponse) { result in
            if case .failure(let error) = result { XCTFail("Unexpected error: \(error)") }
            commandCompletions += 1
        }
        XCTAssertEqual(commandCompletions, 2)
        XCTAssertEqual(peripheral.writes.count, 3)
        XCTAssertThrowsError(try plugin.maximumWriteValueLength(deviceId: UUID().uuidString, bleOutputProperty: .withResponse))
    }
}
