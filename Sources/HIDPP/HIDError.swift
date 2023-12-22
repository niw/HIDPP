//
//  HIDError.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/20/23.
//

import Foundation

public enum HIDError: Error, Equatable {
    case IOReturn(IOReturn)
}

extension IOReturn {
    var error: (any Error)? {
        switch self {
        case kIOReturnSuccess:
            nil
        default:
            HIDError.IOReturn(self)
        }
    }
}
