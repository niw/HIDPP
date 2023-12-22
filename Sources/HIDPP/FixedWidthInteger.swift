//
//  FixedWidthInteger.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/22/23.
//

import Foundation

extension FixedWidthInteger {
    var data: Data {
        withUnsafeBytes(of: self) { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return Data()
            }
            return Data(bytes: baseAddress, count: bytes.count)
        }
    }
}
