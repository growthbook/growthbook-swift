#!/bin/bash

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/ios.xcarchive" \
    -destination "generic/platform=iOS" \
    -destination "generic/platform=iOS Simulator" \
    SKIP_INSTALL=NO



xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/tv.xcarchive" \
    -destination "generic/platform=tvOS" \
    -destination "generic/platform=tvOS Simulator" \
    SKIP_INSTALL=NO



xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/watch.xcarchive" \
    -destination "generic/platform=watchOS" \
    -destination "generic/platform=watchOS Simulator" \
    SKIP_INSTALL=NO

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/vision.xcarchive" \
    -destination "generic/platform=visionOS" \
    -destination "generic/platform=visionOS Simulator" \
    SKIP_INSTALL=NO

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/macos.xcarchive" \
    -destination "generic/platform=macOS" \
    SKIP_INSTALL=NO

xcodebuild -create-xcframework \
    -framework "./build/ios.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/tv.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/watch.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/vision.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/macos.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -output "./build/GrowthBook.xcframework"
