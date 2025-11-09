//
//  IOHIDDevice.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/20/23.
//

import Foundation
import IOKit
import IOKit.hid

// TODO: This is fine.
extension IOHIDDevice: @retroactive @unchecked Sendable {
}

extension IOHIDDevice {
    @discardableResult
    func open(options: IOOptionBits = IOOptionBits(kIOHIDOptionsTypeNone)) -> IOReturn {
        IOHIDDeviceOpen(self, options)
    }

    @discardableResult
    func close(options: IOOptionBits = IOOptionBits(kIOHIDOptionsTypeNone)) -> IOReturn {
        IOHIDDeviceClose(self, options)
    }

    func property(for key: String) -> CFTypeRef? {
        IOHIDDeviceGetProperty(self, key as CFString)
    }

    func setRemovalCallback(_ callback: IOHIDCallback?, context: UnsafeMutableRawPointer? = nil) {
        IOHIDDeviceRegisterRemovalCallback(self, callback, context)
    }

    func setInputReportCallback(_ callback: IOHIDReportCallback?, context: UnsafeMutableRawPointer? = nil, buffer: UnsafeMutableRawBufferPointer?) {
        guard let callback else {
            // If `callback` is `nil`, `report` and `reportLength` for the buffer are not used.
            // However, due to Swift interface, it needs some `UnsafeMutablePointer<UInt8>`.
            // thus, use a placeholder address here.
            // See `HIDDevice.c`.
            var placeholder: UInt8 = 0;
            IOHIDDeviceRegisterInputReportCallback(self, &placeholder, 0, nil, nil)
            return
        }

        guard let buffer, let baseAddress = buffer.baseAddress else {
            return
        }

        IOHIDDeviceRegisterInputReportCallback(self, baseAddress, buffer.count, callback, context)
    }

    func setReport(reportType: IOHIDReportType, reportID: Int, report: UnsafeRawBufferPointer, timeout: TimeInterval = .infinity, callback: IOHIDReportCallback? = nil, context: UnsafeMutableRawPointer? = nil) -> IOReturn {
        guard let baseAddress = report.baseAddress else {
            return kIOReturnError
        }

        return IOHIDDeviceSetReportWithCallback(self, reportType, reportID, baseAddress, report.count, timeout, callback, context)
    }
}
