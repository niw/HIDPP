//
//  HIDDevice.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/20/23.
//

import Foundation

public final actor HIDDevice {
    private let device: IOHIDDevice

    // Allow only `HIDManager` to instantiate this to maintain equality in the subsystem.
    init(device: IOHIDDevice) {
        self.device = device
    }

    deinit {
        _ = device.close(options: IOOptionBits(kIOHIDOptionsTypeNone))
    }

    var registryEntryID: UInt64 {
        get throws {
            let service = IOHIDDeviceGetService(device)
            var entryID = UInt64()
            let result = IORegistryEntryGetRegistryEntryID(service, &entryID)
            guard result == KERN_SUCCESS else {
                throw HIDError.IOReturn(result)
            }
            return entryID
        }
    }

    public func open(options: IOOptionBits = IOOptionBits(kIOHIDOptionsTypeNone)) throws {
        let result = device.open(options: options)
        guard result == kIOReturnSuccess else {
            throw HIDError.IOReturn(result)
        }
    }

    public func close(options: IOOptionBits = IOOptionBits(kIOHIDOptionsTypeNone)) throws {
        let result = device.close(options: options)
        guard result == kIOReturnSuccess else {
            throw HIDError.IOReturn(result)
        }
    }

    public typealias Handler = @Sendable ((any Error)?) -> Void

    private func callRemovalHandler(result: IOReturn) {
        removalHandler?(result.error)
    }

    private var removalHandler: Handler? {
        didSet {
            guard removalHandler != nil else {
                device.setRemovalCallback(nil)
                return
            }

            device.setRemovalCallback({ context, result, _ in
                // Called on the scheduled run loop.
                guard let context else {
                    // Should not reach here.
                    return
                }
                let this = Unmanaged<HIDDevice>.fromOpaque(context).takeUnretainedValue()
                Task {
                    await this.callRemovalHandler(result: result)
                }
            }, context: Unmanaged.passUnretained(self).toOpaque())
        }
    }

    public func useRemovalHandler(_ handler: Handler?) {
        removalHandler = handler
    }

    private lazy var inputReportBuffer: Buffer = {
        let inputReportBufferSize: Int
        if let maxInputReportSizeNumber = device.property(for: kIOHIDMaxInputReportSizeKey) as? NSNumber {
            inputReportBufferSize = maxInputReportSizeNumber.intValue
        } else {
            // This is a default size used in `IOHIDManager`.
            // See `IOHIDManager.c`.
            inputReportBufferSize = 64
        }
        return Buffer(size: inputReportBufferSize)
    }()

    public typealias InputReportHandler = @Sendable (Int, Data, (any Error)?) -> Void

    private func callInputReportHandler(
        result: IOReturn,
        type: IOHIDReportType,
        reportID: UInt32,
        report: UnsafeMutablePointer<UInt8>,
        reportLength: CFIndex
    ) {
        let data: Data
        // Skip `reportID` in report for non-zero reportID. This is required for macOS.
        // See <https://source.chromium.org/chromium/chromium/src/+/main:services/device/hid/hid_connection_mac.cc;l=163-168>.
        if reportID == 0x00 || reportLength < 1 {
            data = Data(bytes: report, count: reportLength)
        } else {
            data = Data(bytes: report.advanced(by: 1), count: reportLength - 1)
        }
        inputReportHandler?(Int(reportID), data, result.error)
    }

    private var inputReportHandler: InputReportHandler? {
        didSet {
            guard inputReportHandler != nil else {
                device.setInputReportCallback(nil, buffer: nil)
                return
            }

            device.setInputReportCallback({ context, result, _, type, reportID, report, reportLength  in
                // Called on the scheduled run loop.
                guard let context else {
                    // Should not reach here.
                    return
                }
                let this = Unmanaged<HIDDevice>.fromOpaque(context).takeUnretainedValue()
                Task {
                    await this.callInputReportHandler(
                        result: result,
                        type: type,
                        reportID: reportID,
                        report: report,
                        reportLength: reportLength
                    )
                }
            }, context: Unmanaged.passUnretained(self).toOpaque(), buffer: inputReportBuffer.pointer)
        }
    }

    public func useInputReportHandler(_ handler: InputReportHandler?) {
        inputReportHandler = handler
    }

    private func sendReport(type: IOHIDReportType, reportID: Int, data: Data, completion: Handler? = nil) throws {
        // Add `reportID` as prefix to `data` for non-zero `reportID`.
        // This is required for macOS.
        // See <https://source.chromium.org/chromium/chromium/src/+/main:services/device/hid/hid_connection_mac.cc;l=163-168>.
        var dataWithReportID: Data
        if reportID == 0x00 {
            dataWithReportID = data
        } else {
            dataWithReportID = Data([UInt8(reportID)])
            dataWithReportID.append(data)
        }

        if let completion = completion {
            // Use boxed pointer to manually manage life time of the completion.
            let boxedCompletion = Box<Handler>(completion)
            // Retain `completion`.
            let unmanagedRetainedBoxedCompletion = Unmanaged.passRetained(boxedCompletion)
            let result = dataWithReportID.withUnsafeBytes { report in
                device.setReport(
                    reportType: type,
                    reportID: reportID,
                    report: report,
                    callback: { context, result, _, _, _, _, _ in
                        // Called on the scheduled run loop.
                        guard let context else {
                            // Should not reach here.
                            return
                        }
                        // Release `completion`.
                        let boxedCompletion = Unmanaged<Box<Handler>>.fromOpaque(context).takeRetainedValue()
                        boxedCompletion.value(result.error)
                    },
                    context: unmanagedRetainedBoxedCompletion.toOpaque()
                )
            }
            if result != kIOReturnSuccess {
                // Release `completion`.
                unmanagedRetainedBoxedCompletion.release()
                throw HIDError.IOReturn(result)
            }
        } else {
            let result = dataWithReportID.withUnsafeBytes { report in
                // If `callback` is `null`, underlying `setReport()` will behave synchronously.
                // Thus, set non-null `callback` always.
                // See `IOHIDDevicePlugIn.h`.
                device.setReport(
                    reportType: type,
                    reportID: reportID,
                    report: report,
                    callback: { _, _, _, _, _, _, _ in
                        // Called on the scheduled run loop.
                    }
                )
            }
            if result != kIOReturnSuccess {
                throw HIDError.IOReturn(result)
            }
        }
    }

    public func sendReport(type: IOHIDReportType, reportID: Int, data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) -> Void in
            do {
                try sendReport(type: type, reportID: reportID, data: data) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

extension HIDDevice: Equatable {
    public static func == (lhs: HIDDevice, rhs: HIDDevice) -> Bool {
        lhs.device == rhs.device
    }
}

extension HIDDevice: Hashable {
    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(device)
    }
}
