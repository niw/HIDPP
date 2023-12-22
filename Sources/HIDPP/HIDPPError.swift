//
//  HIDPPError.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/22/23.
//

import Foundation

public enum HIDPPError: Error {
    case unexpectedInputRequest
    case invalidData(Data)
}
