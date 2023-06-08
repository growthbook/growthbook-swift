![](https://docs.growthbook.io/images/hero-swift-sdk.png)

# GrowthBook - SDK

![](https://camo.githubusercontent.com/1fec6f0d044c5e1d73656bfceed9a78fd4121b17e82a2705d2a47f6fd1f0e3e5/687474703a2f2f696d672e736869656c64732e696f2f62616467652f706c6174666f726d2d696f732d4344434443442e7376673f7374796c653d666c6174) ![](https://camo.githubusercontent.com/4ac08d7fb1bcb8ef26388cd2bf53b49626e1ab7cbda581162a946dd43e6a2726/687474703a2f2f696d672e736869656c64732e696f2f62616467652f706c6174666f726d2d74766f732d3830383038302e7376673f7374796c653d666c6174) ![](https://camo.githubusercontent.com/135dbadae40f9cabe7a3a040f9380fb485cff36c90909f3c1ae36b81c304426b/687474703a2f2f696d672e736869656c64732e696f2f62616467652f706c6174666f726d2d77617463686f732d4330433043302e7376673f7374796c653d666c6174)

![](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)![](https://img.shields.io/cocoapods/v/GrowthBook.svg)




- **Lightweight and fast**
- **Supports iOS**
  - **iOS version 12 & Above**
  - **Apple TvOS version 12 & Above**
  - **Apple WatchOS version 5.0 & Above**
- **Adjust variation weights and targeting without deploying new code**



## Installation

##### CocoaPods 

[CocoaPods](https://cocoapods.org/) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate GrowthBook into your Xcode project using CocoaPods, specify it in your `Podfile`:

- Add below line in your podfile, if not there

```
source 'https://github.com/CocoaPods/Specs.git'
```

- Add below in podfile - in respective target block

```swift
pod 'GrowthBook-IOS'
```

- Execute below command in terminal

```swift
pod install
```

##### Swift Package Manager - SPM

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift`compiler.

Once you have your Swift package set up, adding GrowthBook as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/growthbook/growthbook-swift.git")
]
```


## Integration

Integration is super easy:

1. Create a Growth Book with a few methods: with the API key and host URL, only host URL, only JSON
2. At the start of your app, do SDK Initialization as per below

Now you can start/stop tests, adjust coverage and variation weights, and apply a winning variation to 100% of traffic, all within the Growth Book App without deploying code changes to your site.

```swift
var sdkInstance: GrowthBookSDK = GrowthBookBuilder(url: <GrowthBook_URL/API_KEY>,
    attributes: <[String: Any]>,
    trackingCallback: { experiment, experimentResult in 

    }).initializer()
```
You must also provide the encryption key if you intend to use data encryption.

```swift
var sdkInstance: GrowthBookSDK = GrowthBookBuilder(url: <GrowthBook_URL/API_KEY>,
    encryptionKey: <String>,
    attributes: <[String: Any]>,
    trackingCallback: { experiment, experimentResult in 

    }).initializer()
```

```swift
var sdkInstance: GrowthBookSDK = GrowthBookBuilder(features: <Data>,
    attributes: <[String: Any]>,
    trackingCallback: { experiment, experimentResult in 

    }).initializer()
```

There are additional properties which can be setup at the time of initialization

```swift
var sdkInstance: GrowthBookSDK = GrowthBookBuilder(url: <GrowthBook_URL/API_KEY>,
    attributes: <[String: Any]>,
    trackingCallback: { experiment, experimentResult in 

    })
    .setRefreshHandler { isRefreshed in
        
    } // Get Callbacks when SDK refreshed its cache
    .setNetworkDispatcher(networkDispatcher: <Network Dispatcher>) // Pass Network client to be used for API Calls
    .setEnabled(isEnabled: true) // Enable / Disable experiments
    .setQAMode(isEnabled: true) // Enable / Disable QA Mode
    .setForcedVariations(forcedVariations: <[String: Int]>) // Pass Forced Variations
    .setLogLevel(<LoggerLevel>) // Set log level for SDK Logger, by default log level is set to `info`
    .initializer()
```


## Usage

- Initialization returns SDK instance - GrowthBookSDK

  ###### Use sdkInstance to consume below features -
  
- The feature method takes a single string argument, which is the unique identifier for the feature and returns a FeatureResult object.

```swift
func evalFeature(id: String) -> FeatureResult
```
  
- The run method takes an Experiment object and returns an experiment result

```swift
func run(experiment: Experiment) -> ExperimentResult
```

- Manually Refresh Cache

```swift
func refreshCache()
```

- Get Context

```swift
func getGBContext() -> Context
```

- Get Features

```swift
func getFeatures() -> Features
```

- Get the value of the feature with a fallback
```swift
func getFeatureValue(feature id: String, defaultValue: JSON) -> JSON
```

- The isOn method takes a single string argument, which is the unique identifier for the feature and returns the feature state on/off

```swift
func isOn(feature id: String) -> Bool
```

- The setEncryptedFeatures method takes an encrypted string with an encryption key and then decrypts it with the default method of decrypting or with a method of decrypting from the user.

```swift
func setEncryptedFeatures(encryptedString: String, encryptionKey: String, subtle: CryptoProtocol? = nil)
```


## Models

```swift
/// Defines the GrowthBook context.
class Context {
    /// URL
    let url: String?
    /// Encryption key for encrypted features.
    let encryptionKey: String?
    /// Switch to globally disable all experiments. Default true.
    let isEnabled: Bool
    /// Map of user attributes that are used to assign variations
    var attributes: JSON
    /// Force specific experiments to always assign a specific variation (used for QA)
    let forcedVariations: JSON?
    /// If true, random assignment is disabled and only explicitly forced variations are used.
    let isQaMode: Bool
    /// A function that takes experiment and result as arguments.
    let trackingCallback: (Experiment, ExperimentResult) -> Void

    // Keys are unique identifiers for the features and the values are Feature objects.
    // Feature definitions - To be pulled from API / Cache
    var features: Features
}
```



```swift
/// A Feature object consists of possible values plus rules for how to assign values to users.
class Feature {
    /// The default value (should use null if not specified)
    let defaultValue: JSON?
    /// Array of Rule objects that determine when and how the defaultValue gets overridden
    let rules: [FeatureRule]?
}

/// Rule object consists of various definitions to apply to calculate feature value
struct FeatureRule {
    /// Optional targeting condition
    let condition: JSON?
    /// What percent of users should be included in the experiment (between 0 and 1, inclusive)
    let coverage: Float?
    /// Immediately force a specific value (ignore every other option besides condition and coverage)
    let force: JSON?
    /// Run an experiment (A/B test) and randomly choose between these variations
    let variations: [JSON]?
    /// The globally unique tracking key for the experiment (default to the feature key)
    let key: String?
    /// How to weight traffic between variations. Must add to 1.
    let weights: [Float]?
    /// A tuple that contains the namespace identifier, plus a range of coverage for the experiment.
    let namespace: [JSON]?
    /// What user attribute should be used to assign variations (defaults to id)
    let hashAttribute: String?
}

/// Enum For defining feature value source
enum FeatureSource: String {
    /// Queried Feature doesn't exist in GrowthBook
    case unknownFeature
    /// Default Value for the Feature is being processed
    case defaultValue
    /// Forced Value for the Feature is being processed
    case force
    /// Experiment Value for the Feature is being processed
    case experiment
}

 /// Result for Feature
class FeatureResult {
    /// The assigned value of the feature
    let value: JSON?
    /// The assigned value cast to a boolean
    public var isOn: Bool = false
    /// The assigned value cast to a boolean and then negated
    public var isOff: Bool = true
    /// One of "unknownFeature", "defaultValue", "force", or "experiment"
    let source: String
    /// When source is "experiment", this will be the Experiment object used
    let experiment: Experiment?
    /// When source is "experiment", this will be an ExperimentResult object
    let experimentResult: ExperimentResult?
}
```



```swift
/// Defines a single experiment
class Experiment {
    /// The globally unique tracking key for the experiment
    let key: String
    /// The different variations to choose between
    let variations: [JSON]
    /// A tuple that contains the namespace identifier, plus a range of coverage for the experiment
    let namespace: [JSON]?
    /// All users included in the experiment will be forced into the specific variation index
    let hashAttribute: String?
    /// How to weight traffic between variations. Must add to 1.
    var weights: [Float]?
    /// If set to false, always return the control (first variation)
    var isActive: Bool
    /// What percent of users should be included in the experiment (between 0 and 1, inclusive)
    var coverage: Float?
    /// Optional targeting condition
    var condition: JSON?
    /// All users included in the experiment will be forced into the specific variation index
    var force: Int?
}

/// The result of running an Experiment given a specific Context
class ExperimentResult {
    /// Whether or not the user is part of the experiment
    let inExperiment: Bool
    /// The array index of the assigned variation
    let variationId: Int
    /// The array value of the assigned variation
    let value: JSON
    /// The user attribute used to assign a variation
    let hashAttribute: String?
    /// The value of that attribute
    let hashValue: String?
}
```



## License

This project uses the MIT license. The core GrowthBook app will always remain open and free, although we may add some commercial enterprise add-ons in the future.
