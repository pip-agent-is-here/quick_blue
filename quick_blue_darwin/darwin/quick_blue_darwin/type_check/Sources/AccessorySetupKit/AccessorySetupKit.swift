// Linux stub of AccessorySetupKit, for type-checking only.
import Foundation
import Dispatch
import CoreBluetooth
import UIKit

public enum ASAccessoryEventType: Int, Sendable {
    case unknown = 0
    case activated = 1
    case invalidated = 2
    case accessoryAdded = 3
    case accessoryRemoved = 4
    case pickerDidPresent = 5
    case pickerDidDismiss = 6
    case pickerSetupFailed = 7
}

open class ASDiscoveryDescriptor: NSObject {
    public enum Range: Int, Sendable {
        case `default` = 0
        case immediate = 1
    }

    open var bluetoothServiceUUID: CBUUID?
    open var bluetoothNameSubstring: String?
    open var bluetoothServiceDataBlob: Data?
    open var bluetoothServiceDataMask: Data?
    open var bluetoothRange: Range = .default

    public override init() { super.init() }
}

open class ASPickerDisplayItem: NSObject {
    open var name: String
    open var productImage: UIImage
    open var descriptor: ASDiscoveryDescriptor

    public init(name: String, productImage: UIImage, descriptor: ASDiscoveryDescriptor) {
        self.name = name
        self.productImage = productImage
        self.descriptor = descriptor
        super.init()
    }
}

open class ASMigrationDisplayItem: ASPickerDisplayItem {
    open var peripheralIdentifier: UUID?
}

open class ASAccessory: NSObject {
    open var bluetoothIdentifier: UUID?
    open var displayName: String = ""
}

open class ASAccessoryEvent: NSObject {
    open var eventType: ASAccessoryEventType = .unknown
    open var error: Error?
    open var accessory: ASAccessory?
}

open class ASAccessorySession: NSObject {
    open var accessories: [ASAccessory] = []

    public override init() { super.init() }

    open func activate(on queue: DispatchQueue, eventHandler: @escaping (ASAccessoryEvent) -> Void) {}
    open func invalidate() {}
    open func showPicker(for items: [ASPickerDisplayItem], completionHandler: ((Error?) -> Void)?) {}
    open func removeAccessory(_ accessory: ASAccessory, completionHandler: ((Error?) -> Void)?) {}
}
