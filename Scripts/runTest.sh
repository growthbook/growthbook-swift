#!/bin/bash

set -e

xcodebuild test -project GrowthBook-IOS.xcodeproj \
   -scheme GrowthBook \
   -destination 'platform=iOS Simulator,name=iPhone 16'

xcodebuild test -project GrowthBook-IOS.xcodeproj \
   -scheme GrowthBook \
   -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation) (at 1080p)'

xcodebuild test -project GrowthBook-IOS.xcodeproj \
   -scheme GrowthBook \
   -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'

xcodebuild test -project GrowthBook-IOS.xcodeproj \
   -scheme GrowthBook \
   -destination 'platform=visionOS Simulator,name=Apple Vision Pro'

swift test
