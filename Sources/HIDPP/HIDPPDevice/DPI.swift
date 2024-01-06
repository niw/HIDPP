//
//  DPI.swift
//  HDIPP
//
//  Created by Yoshimasa Niwa on 12/22/23.
//

import Foundation

extension HIDPPDevice {
    public var numberOfSensors: UInt8 {
        get async throws {
            let feature = try await feature(of: 0x2201)
            let data = try await sendRequest(featureIndex: feature.index)
            return data[0]
        }
    }

    public func DPI(sensorIndex: UInt8 = 0) async throws -> UInt16 {
        let feature = try await feature(of: 0x2201)
        let data = try await sendRequest(
            featureIndex: feature.index,
            functionIndex: 0x02,
            data: sensorIndex.data
        )
        guard data[0] == sensorIndex else {
            throw HIDPPError.invalidData(data)
        }
        guard let value = UInt16(data: data, offset: 1) else {
            throw HIDPPError.invalidData(data)
        }
        return value.bigEndian
    }

    @discardableResult
    public func setDPI(_ value: UInt16, sensorIndex: UInt8 = 0) async throws -> UInt16 {
        let feature = try await feature(of: 0x2201)
        var requestData = sensorIndex.data
        requestData.append(value.bigEndian.data)
        let data = try await sendRequest(
            featureIndex: feature.index,
            functionIndex: 0x03,
            data: requestData
        )
        guard data[0] == sensorIndex else {
            throw HIDPPError.invalidData(data)
        }
        guard let value = UInt16(data: data, offset: 1) else {
            throw HIDPPError.invalidData(data)
        }
        return value.bigEndian
    }

    private enum DPIListSourceValue {
        case value(UInt16)
        case step(Int)

        init(_ value: UInt16) {
            if (value >> 13) == 0x07 {
                self = .step(Int(UInt16(value & 0x1fff)))
            } else {
                self = .value(value)
            }
        }
    }

    public enum DPIList: Sendable {
        case values([UInt16])
        case stride(StrideTo<UInt16>)
    }

    public func DPIList(sensorIndex: UInt8 = 0) async throws -> DPIList {
        let feature = try await feature(of: 0x2201)
        let data = try await sendRequest(
            featureIndex: feature.index,
            functionIndex: 0x01,
            data: sensorIndex.data
        )
        guard data[0] == sensorIndex else {
            throw HIDPPError.invalidData(data)
        }
        var sourceValues = [DPIListSourceValue]()
        for offset in stride(from: 1, to: data.count, by: 2) {
            guard let value = UInt16(data: data, offset: offset), value != 0x0000 else {
                break
            }
            sourceValues.append(DPIListSourceValue(value.bigEndian))
        }

        if sourceValues.count == 3,
           case .value(let from) = sourceValues[0],
           case .step(let step) = sourceValues[1],
           case .value(let to) = sourceValues[2]
        {
            return .stride(stride(from: from, to: to, by: step))
        }

        let values = try sourceValues.map { sourceValue in
            switch sourceValue {
            case .value(let value):
                value
            default:
                throw HIDPPError.invalidData(data)
            }
        }
        return .values(values)
    }
}
