#!/bin/bash

set -e

# Prints the id of an available simulator for a platform (iOS, tvOS, watchOS, xrOS), preferring
# the given device type and creating one on the newest runtime when the machine has none
simulator_id() {
   local platform=$1
   local device_type=$2
   xcrun simctl list -j devices available runtimes | jq -r --arg platform "$platform" --arg name "$device_type" '
      .devices as $devices
      | [.runtimes[]
         | select(.isAvailable and (.identifier | split(".") | last | startswith($platform + "-")))]
      | sort_by(.version | split(".") | map(tonumber)) | reverse
      | (map(($devices[.identifier] // []) as $d | ([$d[] | select(.name == $name)] + $d)[0].udid // empty) | first)
        // (if length > 0 then "create " + .[0].identifier else "" end)
   ' | {
      read -r result runtime
      if [ "$result" = "create" ]; then
         xcrun simctl create "$device_type" "$device_type" "$runtime"
      elif [ -n "$result" ]; then
         echo "$result"
      else
         echo "No $platform simulator runtime is installed" >&2
         exit 1
      fi
   }
}

run_tests() {
   local id
   id=$(simulator_id "$1" "$2")
   xcodebuild test -project GrowthBook-IOS.xcodeproj \
      -scheme GrowthBook \
      -destination "id=$id"
}

run_tests iOS "iPhone 16"
run_tests tvOS "Apple TV 4K (3rd generation) (at 1080p)"
run_tests watchOS "Apple Watch Series 10 (46mm)"
run_tests xrOS "Apple Vision Pro"

swift test
