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
            let data = try await send(request: Request(
                featureIndex: feature.index,
                functionIndex: 0x02)
            )
            return String(cString: Array(data))
        }
    }
}
