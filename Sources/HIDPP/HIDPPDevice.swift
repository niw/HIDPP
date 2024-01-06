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
            case .matching(device: let device, error: let error):
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
                await self.handleInputReport(payload: data, error: error)
            }
        }

        try await device.open()
    }

    public var registryEntryID: UInt64 {
        get async throws {
            try await device.registryEntryID
        }
    }

    private struct Request: Equatable, Sendable {
        var identifier: UInt8

        var index: UInt8
        var featureIndex: UInt8
        var functionIndex: UInt8

        var data: Data?

        init(
            identifier: UInt8,
            index: UInt8 = 0xff,
            featureIndex: UInt8,
            functionIndex: UInt8 = 0x00,
            data: Data? = nil
        ) {
            // This `identifier`, so called `SwID` in some documentations, located at the lower
            // 4 bits of the `functionIndex`, is used to identify the response for the request.
            // The most significant bit of it is always set to identify the response from the
            // notifications thus, we only can use remaining 3 bits to identify it.
            // See `header` as well.
            self.identifier = identifier & 0x07

            self.index = index
            self.featureIndex = featureIndex
            self.functionIndex = functionIndex

            self.data = data
        }

        private var header: Data {
            Data([
                index,
                featureIndex,
                // Set the most significant of lower 4 bits of the `functionIndex` for the request
                // to identify the response from the notifications.
                (functionIndex << 4) | 0x08 | (identifier & 0x07)
            ])
        }

        var payload: Data {
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

    private var lastRequestIdentifier: UInt8 = 0

    private func nextRequestIdentifier() -> UInt8 {
        lastRequestIdentifier = (lastRequestIdentifier + 1) & 0x07
        return lastRequestIdentifier
    }

    private struct Response: Equatable, Sendable {
        var isNotification: Bool
        var identifier: UInt8

        var index: UInt8
        var featureIndex: UInt8
        var functionIndex: UInt8

        var data: Data

        var isError: Bool

        init(payload: Data) throws {
            guard payload.count > 3 else {
                throw HIDPPError.tooShortInputRequest
            }

            index = payload[0]

            let headerPosition: Int
            if payload[1] == 0xff {
                guard payload.count > 4 else {
                    throw HIDPPError.tooShortInputRequest
                }
                isError = true
                headerPosition = 1
            } else {
                isError = false
                headerPosition = 0
            }

            featureIndex = payload[headerPosition + 1]

            functionIndex = payload[headerPosition + 2] >> 4
            // The lower 4 bits of `functionIndex` is for the identifier.
            // The most significant bit of it is set on the response for the request.
            // Otherwise, it is a notification.
            isNotification = (payload[headerPosition + 2] & 0x08) == 0x00
            identifier = payload[headerPosition + 2] & 0x07

            let headerSize = headerPosition + 3
            data = payload.subdata(in: headerSize..<payload.count)
        }

        func isValid(for request: Request) -> Bool {
            !isNotification
            && identifier == request.identifier
            && index == request.index
            && featureIndex == request.featureIndex
            && functionIndex == request.functionIndex
        }
    }

    // This is `class` to have a simple object equality with its identify.
    private final class RequestContinuation: Equatable, Sendable, CustomStringConvertible {
        let request: Request
        let continuation: UnsafeContinuation<Data, any Error>

        init(request: Request, continuation: UnsafeContinuation<Data, any Error>) {
            self.request = request
            self.continuation = continuation
        }

        static func == (lhs: HIDPPDevice.RequestContinuation, rhs: HIDPPDevice.RequestContinuation) -> Bool {
            lhs === rhs
        }

        var description: String {
            "RequestContinuation request: \(request)"
        }
    }

    private var requestContinuations = [UInt8 : RequestContinuation]()

    private func useRequestContinuation(for identifier: UInt8, _ block: (RequestContinuation) throws -> Void) rethrows {
        guard let requestContinuation = requestContinuations[identifier] else {
            return
        }
        try block(requestContinuation)
        requestContinuations[identifier] = nil
    }

    private func setRequestContinuation(_ requestContinuation: RequestContinuation) {
        requestContinuations[requestContinuation.request.identifier] = requestContinuation
    }

    private func unsetRequestContinuation(_ requestContinuation: RequestContinuation) {
        requestContinuations[requestContinuation.request.identifier] = nil
    }

    private func handleInputReport(payload: Data, error: (any Error)?) {
        guard error == nil else {
            return
        }

        guard let response = try? Response(payload: payload) else {
            return
        }

        guard !response.isNotification else {
            return
        }

        useRequestContinuation(for: response.identifier) { requestContinuation in
            let continuation = requestContinuation.continuation
            let request = requestContinuation.request

            guard response.isValid(for: request) else {
                continuation.resume(throwing: HIDPPError.unexpectedInputRequest)
                return
            }

            if response.isError {
                continuation.resume(throwing: HIDPPError.errorInputRequest(data: response.data))
            } else {
                continuation.resume(returning: response.data)
            }
        }
    }

    func sendRequest(
        index: UInt8 = 0xff,
        featureIndex: UInt8,
        functionIndex: UInt8 = 0x00,
        data: Data? = nil
    ) async throws -> Data {
        try await withUnsafeThrowingContinuation { continuation in
            Task {
                let request = Request(
                    identifier: nextRequestIdentifier(),
                    featureIndex: featureIndex,
                    functionIndex: functionIndex,
                    data: data
                )
                let requestContinuation = RequestContinuation(request: request, continuation: continuation)
                setRequestContinuation(requestContinuation)
                do {
                    try await device.sendReport(
                        type: kIOHIDReportTypeOutput,
                        reportID: Self.reportID,
                        data: request.payload
                    )
                } catch {
                    // Reentrant
                    unsetRequestContinuation(requestContinuation)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    struct Feature: Equatable {
        var index: UInt8
        var version: UInt8
    }

    private var features: [UInt16 : Feature] = [:]

    func feature(of identifier: UInt16) async throws -> Feature {
        if let feature = features[identifier] {
            return feature
        }

        let data = try await sendRequest(
            featureIndex: 0x00,
            data: identifier.bigEndian.data
        )
        guard data.count > 2 else {
            throw HIDPPError.invalidData(data)
        }

        let feature = Feature(index: data[0], version: data[2])
        features[identifier] = feature

        return feature
    }
}
