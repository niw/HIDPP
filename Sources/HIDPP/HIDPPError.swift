//
//  HIDPPError.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/22/23.
//

import Foundation

public enum HIDPPError: Error, Sendable {
    case duplicatedRequestIdentifier
    case timeout
    case tooShortInputRequest
    case unexpectedInputRequest
    case errorInputRequest(data: Data)
    case invalidData(Data)
}
