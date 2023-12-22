//
//  HIDPPError.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/22/23.
//

import Foundation

public enum HIDPPError: Error {
    case tooShortInputRequest
    case unexpectedInputRequest
    case errorInputRequest(data: Data)
    case invalidData(Data)
}
