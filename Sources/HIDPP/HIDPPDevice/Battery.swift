//
//  Battery.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/22/23.
//

import Foundation

extension HIDPPDevice {
    public struct Battery: Codable, Sendable {
        public enum Status: UInt8, Codable, Sendable {
            case discharging
            case charging
            case almostFull
            case charged
            case slowRecharge
            case invalidBattery
            case terminalError
            case otherError
        }

        public enum Level: UInt8, Codable, Sendable {
            case critical = 0x01 // 0x01 << 0
            case low = 0x02 // 0x01 << 1
            case good = 0x04 // 0x01 << 2
            case full = 0x08 // 0x01 << 3
        }

        public var percentage: UInt8
        public var level: Level?
        public var status: Status?
    }

    public var battery: Battery {
        get async throws {
            let feature = try await feature(of: 0x1004)
            let data = try await sendRequest(index: 0xff, featureIndex: feature.index, functionIndex: 0x01)
            return Battery(
                percentage: data[0],
                level: Battery.Level(rawValue: data[1]),
                status: Battery.Status(rawValue: data[2])
            )
        }
    }
}
