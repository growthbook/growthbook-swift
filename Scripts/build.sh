#!/bin/bash

## Currently a bug introduced in Xcode 15.2 unresolved where the visionOS destination will use the iOS base SDK.
## Workaround available here: https://developer.apple.com/documentation/xcode-release-notes/xcode-15_2-release-notes
## This build script will fail unless workaround is applied.

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/ios.xcarchive" \
    -destination "generic/platform=iOS" \
    SKIP_INSTALL=NO \

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/ios_sim.xcarchive" \
    -destination "generic/platform=iOS Simulator" \
    SKIP_INSTALL=NO \

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/tv.xcarchive" \
    -destination "generic/platform=tvOS" \
    SKIP_INSTALL=NO \

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/tv_sim.xcarchive" \
    -destination "generic/platform=tvOS Simulator" \
    SKIP_INSTALL=NO \

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/watch.xcarchive" \
    -destination "generic/platform=watchOS" \
    SKIP_INSTALL=NO \

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/watch_sim.xcarchive" \
    -destination "generic/platform=watchOS Simulator" \
    SKIP_INSTALL=NO \

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/vision.xcarchive" \
    -destination "generic/platform=visionOS" \
    SKIP_INSTALL=NO \

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/vision_sim.xcarchive" \
    -destination "generic/platform=visionOS Simulator" \
    SKIP_INSTALL=NO \

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/macos.xcarchive" \
    -destination "generic/platform=macOS" \
    SKIP_INSTALL=NO

xcodebuild -create-xcframework \
    -framework "./build/ios.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/ios_sim.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/tv.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/tv_sim.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/watch.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/watch_sim.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/vision.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/vision_sim.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/macos.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -output "./build/GrowthBook.xcframework"
