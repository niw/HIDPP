//
//  HIDPPDevice.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/19/23.
//

import Foundation

public final actor HIDPPDevice {
    // Logitech, Inc.
    static let vendorID = 0x046d
    // HIDPP 2.0
    static let reportID = 0x11

    public static func enumerateDevices(runLoop: RunLoop, runLoopMode: RunLoop.Mode) -> AsyncThrowingStream<HIDPPDevice, any Error> {
        let matching = [
            kIOHIDVendorIDKey: vendorID
        ]
        return HIDManager.observeDevices(matching: matching, runLoop: runLoop, runLoopMode: runLoopMode).compactMap { (event: HIDManager.DeviceEvent) -> HIDPPDevice? in
            switch event {
            case let .matching(device: device, error: error):
                if error != nil {
                    return nil
                } else {
                    do {
                        return try await HIDPPDevice(device: device)
                    } catch {
                        return nil
                    }
                }
            default:
                return nil
            }
        }.eraseToThrowingStream()
    }

    private let device: HIDDevice

    init(device: HIDDevice) async throws {
        self.device = device

        await device.useInputReportHandler { [weak self] reportID, data, error in
            guard reportID == Self.reportID else {
                return
            }

            Task { [weak self] in
                guard let self else {
                    return
                }
                await self.resumeLastRequestContinuationOnInputReport(payload: data, error: error)
            }
        }

        try await device.open()
    }

    private func resumeLastRequestContinuationOnInputReport(payload: Data, error: (any Error)?) {
        guard let lastRequestContinuation else {
            return
        }

        let continuation = lastRequestContinuation.continuation

        if let error = error {
            continuation.resume(throwing: error)
        } else {
            let requestHeader = lastRequestContinuation.request.header

            // Input request payload must have same header as request.
            let headerSize = requestHeader.count
            guard payload.count > headerSize,
                  payload.subdata(in: 0..<headerSize) == requestHeader
            else {
                continuation.resume(throwing: HIDPPError.unexpectedInputRequest)
                return
            }

            let data = payload.subdata(in: headerSize..<payload.count)
            continuation.resume(returning: data)
        }
    }

    struct Request {
        var index: UInt8
        var featureIndex: UInt8
        var functionIndex: UInt8
        var data: Data?

        public init(
            index: UInt8 = 0xff,
            featureIndex: UInt8,
            functionIndex: UInt8 = 0x00,
            data: Data? = nil
        ) {
            self.index = index
            self.featureIndex = featureIndex
            self.functionIndex = functionIndex
            self.data = data
        }

        fileprivate var header: Data {
            Data([index, featureIndex, functionIndex << 4])
        }

        fileprivate var payload: Data {
            var payload = header
            let dataSize: Int
            if let data = data {
                payload.append(data)
                dataSize = data.count
            } else {
                dataSize = 0
            }
            if dataSize < 16 {
                payload.append(Data(repeating: 0x00, count: 16 - dataSize))
            }
            return payload
        }
    }

    private struct RequestContinuation {
        var request: Request
        var continuation: UnsafeContinuation<Data, any Error>
    }
    private var lastRequestContinuation: RequestContinuation?

    func send(request: Request) async throws -> Data {
        try await withUnsafeThrowingContinuation { continuation in
            Task {
                lastRequestContinuation = RequestContinuation(request: request, continuation: continuation)
                do {
                    try await device.sendReport(
                        type: kIOHIDReportTypeOutput,
                        reportID: Self.reportID,
                        data: request.payload
                    )
                } catch {
                    lastRequestContinuation = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    struct Feature {
        var index: UInt8
        var version: UInt8
    }

    private var features: [UInt16 : Feature] = [:]

    func feature(of identifier: UInt16) async throws -> Feature {
        if let feature = features[identifier] {
            return feature
        }

        let data = try await send(request: Request(
            featureIndex: 0x00,
            data: identifier.bigEndian.data
        ))
        guard data.count > 2 else {
            throw HIDPPError.invalidData(data)
        }

        let feature = Feature(index: data[0], version: data[2])
        features[identifier] = feature

        return feature
    }
}
