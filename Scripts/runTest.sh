#!/bin/bash

set -e

# Prints the id of an available simulator for a platform (iOS, tvOS, watchOS, xrOS), preferring
# the given device type and creating one on the newest runtime when the machine has none
simulator_id() {
   local platform=$1
   local device_type=$2
   xcrun simctl list -j devices available runtimes | python3 -c '
import json, sys
platform, device_type = sys.argv[1], sys.argv[2]
data = json.load(sys.stdin)
runtimes = [r for r in data["runtimes"] if r.get("isAvailable") and r["identifier"].split(".")[-1].startswith(platform + "-")]
runtimes.sort(key=lambda r: [int(p) for p in r["version"].split(".")], reverse=True)
for r in runtimes:
    devices = data["devices"].get(r["identifier"], [])
    preferred = [d for d in devices if d["name"] == device_type] or devices
    if preferred:
        print(preferred[0]["udid"])
        sys.exit(0)
print("create " + runtimes[0]["identifier"] if runtimes else "")
' "$platform" "$device_type" | {
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
