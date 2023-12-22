//
//  Command.swift
//  HIDPPCLI
//
//  Created by Yoshimasa Niwa on 12/22/23.
//

import ArgumentParser
import Foundation
import HIDPP

@main
struct Command: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        subcommands: [
            List.self,
            Battery.self
        ]
    )

    private struct List: AsyncParsableCommand {
        func run() async throws {
            for try await device in HIDPPDevice.enumerateDevices(runLoop: .main, runLoopMode: .default) {
                print(try await device.serialNumber)
            }
        }
    }

    private struct Battery: AsyncParsableCommand {
        @Option(name: [.short, .customLong("serialNumber")], help: "Serial number")
        private var serialNumber: String

        func run() async throws {
            for try await device in HIDPPDevice.enumerateDevices(runLoop: .main, runLoopMode: .default) {
                guard try await device.serialNumber == serialNumber else {
                    continue
                }

                let battery = try await device.battery
                print(battery)
                break
            }
        }
    }
}
