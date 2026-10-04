// Linux stub of the Flutter iOS/macOS embedder, for type-checking only.
import Foundation

public protocol FlutterBinaryMessenger: AnyObject {}

public typealias FlutterEventSink = (Any?) -> Void
public typealias FlutterReply = (Any?) -> Void

public protocol FlutterMessageCodec {}
public protocol FlutterMethodCodec {}

open class FlutterStandardTypedData: NSObject {
    public let data: Data
    public init(bytes: Data) {
        self.data = bytes
        super.init()
    }
}

open class FlutterStandardReader: NSObject {
    public init(data: Data) { super.init() }
    open func readValue() -> Any? { nil }
    open func readValue(ofType type: UInt8) -> Any? { nil }
}

open class FlutterStandardWriter: NSObject {
    public init(data: NSMutableData) { super.init() }
    open func writeByte(_ byte: UInt8) {}
    open func writeValue(_ value: Any) {}
}

open class FlutterStandardReaderWriter: NSObject {
    public override init() { super.init() }
    open func reader(with data: Data) -> FlutterStandardReader { FlutterStandardReader(data: data) }
    open func writer(with data: NSMutableData) -> FlutterStandardWriter { FlutterStandardWriter(data: data) }
}

open class FlutterStandardMessageCodec: NSObject, FlutterMessageCodec {
    public init(readerWriter: FlutterStandardReaderWriter) { super.init() }
}

open class FlutterStandardMethodCodec: NSObject, FlutterMethodCodec {
    public init(readerWriter: FlutterStandardReaderWriter) { super.init() }
}

open class FlutterBasicMessageChannel: NSObject {
    public init(name: String, binaryMessenger: FlutterBinaryMessenger, codec: FlutterMessageCodec) { super.init() }
    open func setMessageHandler(_ handler: ((Any?, @escaping FlutterReply) -> Void)?) {}
    open func sendMessage(_ message: Any?, completion: ((Any?) -> Void)? = nil) {}
}

public protocol FlutterStreamHandler: AnyObject {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError?
    func onCancel(withArguments arguments: Any?) -> FlutterError?
}

open class FlutterEventChannel: NSObject {
    public init(name: String, binaryMessenger: FlutterBinaryMessenger, codec: FlutterMethodCodec) { super.init() }
    open func setStreamHandler(_ handler: FlutterStreamHandler?) {}
}

open class FlutterError: NSObject {
    public let code: String
    public let message: String?
    public let details: Any?
    public init(code: String, message: String?, details: Any?) {
        self.code = code
        self.message = message
        self.details = details
        super.init()
    }
}

public let FlutterEndOfEventStream: NSObject = NSObject()

public protocol FlutterPluginRegistrar: AnyObject {
    func messenger() -> FlutterBinaryMessenger
    func publish(_ value: NSObject)
}

public protocol FlutterPlugin: AnyObject {
    static func register(with registrar: FlutterPluginRegistrar)
    func detachFromEngine(for registrar: FlutterPluginRegistrar)
}
