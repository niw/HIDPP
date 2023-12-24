HIDPP
=====

A Swift package to communicate with Logitech, Inc. keyboards or mouses
by using their proprietary HID++ protocol.


Usage
-----

Add following lines to your `Package.swift`.

```swift
let package = Package(
    ...
    platforms: [
        // Minimum requirement of macOS version is 13.
        .macOS(.v13)
    ],
    ...
    dependencies: [
        .package(
            url: "https://github.com/niw/HIDPP",
            // This package is under development thus use tip branch for now.
            branch: "master"
        )
    ],
    ...
    targets: [
        .target(
            ...
            dependencies: [
                .product(name: "HIDPP", package: "HIDPP")
            ]
        )
    ]
    ...
)
```


Command Line Tool
-----------------

This package includes a simple command line tool that can communicate
with connected Logitech, Inc. devices.

```bash
# Build command line interface.
swift build -c release

# Run it.
.build/release/hidppcli
```

For example to set connected mouse DPI to 750, to make Logitech, Inc.
mouse behaves as like Apple Magic Mouse, which is lower DPI,
use following commands.

```bash
# Enumerate the serial number of connected Logitech, Inc. devices.
# Ctrl-C to stop.
hidppcli enumerate

# List supported DPIs
hidppcli dpi list -s $SERIAL_NUMBER

# Get current DPI
hidppcli dpi get -s $SERIAL_NUMBER

# Set DPI
hidppcli dpi set -s $SERIAL_NUMBER 750
```
