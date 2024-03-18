#!/bin/bash

xcodebuild test -project GrowthBook-IOS.xcodeproj \
   -scheme GrowthBook \
   -destination 'platform=iOS Simulator,name=iPhone 15'

xcodebuild test -project GrowthBook-IOS.xcodeproj \
   -scheme GrowthBook \
   -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation) (at 1080p)'

xcodebuild test -project GrowthBook-IOS.xcodeproj \
   -scheme GrowthBook \
   -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'

xcodebuild test -project GrowthBook-IOS.xcodeproj \
   -scheme GrowthBook \
   -destination 'platform=visionOS Simulator,name=Apple Vision Pro'
