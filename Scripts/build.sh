#!/bin/bash

   xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/ios.xcarchive" \
    -sdk iphoneos \
    SKIP_INSTALL=NO

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/ios_sim.xcarchive" \
    -sdk iphonesimulator \
    SKIP_INSTALL=NO


xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/tv_sim.xcarchive" \
    -sdk appletvsimulator \
    SKIP_INSTALL=NO

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/tv.xcarchive" \
    -sdk appletvos \
    SKIP_INSTALL=NO


xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/watch_sim.xcarchive" \
    -sdk watchsimulator \
    SKIP_INSTALL=NO

xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/watch.xcarchive" \
    -sdk watchos \
    SKIP_INSTALL=NO


xcodebuild archive \
    -scheme GrowthBook \
    -archivePath "./build/macos.xcarchive" \
    -sdk macosx \
    SKIP_INSTALL=NO


xcodebuild -create-xcframework \
    -framework "./build/ios.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/ios_sim.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/tv.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/tv_sim.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/watch.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/watch_sim.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -framework "./build/macos.xcarchive/Products/Library/Frameworks/GrowthBook.framework" \
    -output "./build/GrowthBook.xcframework"
