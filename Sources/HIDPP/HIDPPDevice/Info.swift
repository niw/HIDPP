//
//  Info.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/22/23.
//

import Foundation

extension HIDPPDevice {
    public var serialNumber: String {
        get async throws {
            let feature = try await feature(of: 0x0003)
            let data = try await sendRequest(
                featureIndex: feature.index,
                functionIndex: 0x02
            )
            return String(cString: Array(data))
        }
    }

    public var name: String {
        get async throws {
            let feature = try await feature(of: 0x0007)
            let lengthData = try await sendRequest(
                featureIndex: feature.index,
                functionIndex: 0x00
            )
            let length = Int(lengthData[2])
            var data = Data(capacity: length)
            while data.count < length {
                let partialData = try await sendRequest(
                    featureIndex: feature.index,
                    functionIndex: 0x01,
                    data: UInt8(data.count).data
                )
                let partialNameLength = min(length - data.count, partialData.count)
                data.append(partialData.subdata(in: 1..<(1 + partialNameLength)))
            }
            guard let name = String(data: data, encoding: .utf8) else {
                throw HIDPPError.invalidData(data)
            }
            return name
        }
    }
}
