//
//  HIDManager.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/19/23.
//

import Foundation

public final actor HIDManager {
    private let manager: IOHIDManager

    private var hidDevices = [IOHIDDevice : HIDDevice]()

    public init() {
        manager = IOHIDManager.create()
    }

    deinit {
        guard let currentSchedule else {
            return
        }
        manager.close()
        manager.unschedule(from: currentSchedule.runLoop, mode: currentSchedule.mode)
    }

    private struct Schedule {
        var runLoop: RunLoop
        var mode: RunLoop.Mode
    }

    private var currentSchedule: Schedule?

    public var isRunning: Bool {
        currentSchedule != nil
    }

    public func start(
        matching: [String : Sendable],
        on runLoop: RunLoop,
        mode: RunLoop.Mode,
        options: IOOptionBits = IOOptionBits(kIOHIDOptionsTypeNone)
    ) throws {
        guard currentSchedule == nil else {
            return
        }

        manager.setDeviceMatching(matching)
        manager.schedule(with: runLoop, mode: mode)

        let result = manager.open(options: options)
        guard result == kIOReturnSuccess else {
            throw HIDError.IOReturn(result)
        }

        currentSchedule = Schedule(runLoop: runLoop, mode: mode)
    }

    public func stop() throws {
        guard let currentSchedule else {
            return
        }

        let result = manager.close()
        guard result == kIOReturnSuccess else {
            throw HIDError.IOReturn(result)
        }

        manager.unschedule(from: currentSchedule.runLoop, mode: currentSchedule.mode)
        self.currentSchedule = nil

        hidDevices.removeAll()
    }

    public typealias DeviceHandler = @Sendable (HIDDevice, (any Error)?) -> Void

    private func callDeviceMatchingHandler(result: IOReturn, device: IOHIDDevice) {
        let hidDevice = hidDevices.value(forKey: device) { device in
            HIDDevice(device: device)
        }
        deviceMatchingHandler?(hidDevice, result.error)
    }

    private var deviceMatchingHandler: DeviceHandler? {
        didSet {
            guard deviceMatchingHandler != nil else {
                manager.setDeviceMatchingCallback(nil)
                return
            }

            manager.setDeviceMatchingCallback({ context, result, _, device in
                // Called on the scheduled run loop.
                guard let context else {
                    // Should not reach here.
                    return
                }
                let this = Unmanaged<HIDManager>.fromOpaque(context).takeUnretainedValue()
                Task {
                    await this.callDeviceMatchingHandler(result: result, device: device)
                }
            }, context: Unmanaged.passUnretained(self).toOpaque())
        }
    }

    public func useDeviceMatchingHandler(_ handler: DeviceHandler?) {
        deviceMatchingHandler = handler
    }

    private func callDeviceRemovalHandler(result: IOReturn, device: IOHIDDevice) {
        if let hidDevice = hidDevices[device] {
            deviceRemovalHandler?(hidDevice, result.error)
            hidDevices.removeValue(forKey: device)
        } else {
            deviceRemovalHandler?(HIDDevice(device: device), result.error)
        }
    }

    private var deviceRemovalHandler: DeviceHandler? {
        didSet {
            guard deviceRemovalHandler != nil else {
                manager.setDeviceRemovalCallback(nil)
                return
            }

            manager.setDeviceRemovalCallback({ context, result, _, device in
                // Called on the scheduled run loop.
                guard let context else {
                    // Should not reach here.
                    return
                }
                let this = Unmanaged<HIDManager>.fromOpaque(context).takeUnretainedValue()
                Task {
                    await this.callDeviceRemovalHandler(result: result, device: device)
                }
            }, context: Unmanaged.passUnretained(self).toOpaque())
        }
    }

    public func useDeviceRemovalHandler(_ handler: DeviceHandler?) {
        deviceRemovalHandler = handler
    }

    public enum DeviceEvent {
        case matching(device: HIDDevice, error: (any Error)?)
        case removal(device: HIDDevice, error: (any Error)?)
    }

    public static func observeDevices(
        matching: [String : Sendable],
        on runLoop: RunLoop,
        mode: RunLoop.Mode,
        options: IOOptionBits = IOOptionBits(kIOHIDOptionsTypeNone)
    ) -> AsyncThrowingStream<DeviceEvent, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                let manager = HIDManager()
                await manager.useDeviceMatchingHandler { device, error in
                    continuation.yield(.matching(device: device, error: error))
                }
                await manager.useDeviceRemovalHandler { device, error in
                    continuation.yield(.removal(device: device, error: error))
                }
                // This is not necessary to stop `manager`, but necessary to retain `manager`
                // to extend its lifetime.
                continuation.onTermination = { _ in
                    Task {
                        do {
                            try await manager.stop()
                        } catch {
                        }
                    }
                }
                do {
                    try await manager.start(
                        matching: matching,
                        on: runLoop,
                        mode: mode,
                        options: options
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
