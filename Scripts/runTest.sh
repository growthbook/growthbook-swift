#!/bin/bash

xcodebuild test -project GrowthBook-IOS.xcodeproj \
   -scheme GrowthBook \
   -destination 'platform=iOS Simulator,name=iPhone 15'
