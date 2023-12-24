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
            Enumerate.self,
            Battery.self,
            DPI.self
        ]
    )

    private struct Enumerate: AsyncParsableCommand {
        func run() async throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            for try await device in HIDPPDevice.enumerateDevices(runLoop: .main, runLoopMode: .default) {
                let info = try await [
                    "name": device.name,
                    "serialNumber": device.serialNumber
                ]
                print(String(data: try encoder.encode(info), encoding: .utf8)!)
            }
        }
    }

    private struct SingleDeviceOptions: ParsableArguments {
        @Option(name: [.short, .long])
        var serialNumber: String

        func run(_ block: (HIDPPDevice) async throws -> Encodable) async throws {
            for try await device in HIDPPDevice.enumerateDevices(runLoop: .main, runLoopMode: .default) {
                guard try await device.serialNumber == serialNumber else {
                    continue
                }

                let result = try await block(device)

                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                print(String(data: try encoder.encode(result), encoding: .utf8)!)

                break
            }
        }
    }

    private struct Battery: AsyncParsableCommand {
        @OptionGroup
        var options: SingleDeviceOptions

        func run() async throws {
            try await options.run { device in
                try await device.battery
            }
        }
    }

    private struct DPI: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            subcommands: [
                SensorCount.self,
                List.self,
                Get.self,
                Set.self
            ]
        )

        private struct SensorCount: AsyncParsableCommand {
            @OptionGroup
            var options: SingleDeviceOptions

            func run() async throws {
                try await options.run { device in
                    try await device.numberOfSensors
                }
            }
        }

        private struct List: AsyncParsableCommand {
            @OptionGroup
            var options: SingleDeviceOptions

            @Option
            var sensor: UInt8 = 0

            func run() async throws {
                try await options.run { device in
                    switch try await device.DPIList(sensorIndex: sensor) {
                    case .values(let dpis):
                        return dpis
                    case .stride(let stride):
                        return Array(stride)
                    }
                }
            }
        }

        private struct Get: AsyncParsableCommand {
            @OptionGroup
            var options: SingleDeviceOptions

            @Option
            var sensor: UInt8 = 0

            func run() async throws {
                try await options.run { device in
                    try await device.DPI(sensorIndex: sensor)
                }
            }
        }

        private struct Set: AsyncParsableCommand {
            @OptionGroup
            var options: SingleDeviceOptions

            @Option
            var sensor: UInt8 = 0

            @Argument
            var value: UInt16

            func run() async throws {
                try await options.run { device in
                    try await device.setDPI(value)
                }
            }
        }
    }
}
