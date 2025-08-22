![](https://docs.growthbook.io/images/hero-swift-sdk.png)

# GrowthBook - SDK

![](https://camo.githubusercontent.com/1fec6f0d044c5e1d73656bfceed9a78fd4121b17e82a2705d2a47f6fd1f0e3e5/687474703a2f2f696d672e736869656c64732e696f2f62616467652f706c6174666f726d2d696f732d4344434443442e7376673f7374796c653d666c6174) ![](https://camo.githubusercontent.com/4ac08d7fb1bcb8ef26388cd2bf53b49626e1ab7cbda581162a946dd43e6a2726/687474703a2f2f696d672e736869656c64732e696f2f62616467652f706c6174666f726d2d74766f732d3830383038302e7376673f7374796c653d666c6174) ![](https://camo.githubusercontent.com/135dbadae40f9cabe7a3a040f9380fb485cff36c90909f3c1ae36b81c304426b/687474703a2f2f696d672e736869656c64732e696f2f62616467652f706c6174666f726d2d77617463686f732d4330433043302e7376673f7374796c653d666c6174)

![](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)![](https://img.shields.io/cocoapods/v/GrowthBook.svg)




- **Lightweight and fast**
- **Supports native Apple platforms**
  - **macOS version 10.15 & Above**
  - **iOS version 12.0 & Above**
  - **Apple tvOS version 12.0 & Above**
  - **Apple watchOS version 5.0 & Above**
  - **Apple visionOS version 1.0 & Above**
- **Adjust variation weights and targeting without deploying new code**
- **Latest spec version: 0.7.0 [View Changelog](https://docs.growthbook.io/lib/build-your-own#changelog)**



## Installation

##### CocoaPods 

[CocoaPods](https://cocoapods.org/) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate GrowthBook into your Xcode project using CocoaPods, specify it in your `Podfile`:

- If you're using version 1.0.46 or above, it could be necessary to set "User Script Sandboxing" to "No" in your build settings.

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
var sdkInstance: GrowthBookSDK = GrowthBookBuilder(apiHost: <GrowthBook/API_HOST>,
    clientKey: <GrowthBook/Client_KEY>,
    attributes: <[String: Any]>,
    trackingCallback: { experiment, experimentResult in 

    }, backgroundSync: Bool?).initializer()
```
You must also provide the encryption key if you intend to use data encryption.

```swift
var sdkInstance: GrowthBookSDK = GrowthBookBuilder(apiHost: <GrowthBook/API_HOST>,
    clientKey: <GrowthBook/Client_KEY>,
    attributes: <[String: Any]>,
    trackingCallback: { experiment, experimentResult in 

    }).initializer()
```

```swift
var sdkInstance: GrowthBookSDK = GrowthBookBuilder(apiHost: <GrowthBook/API_HOST>,
    clientKey: <GrowthBook/Client_KEY>,
    attributes: <[String: Any]>,
    trackingCallback: { experiment, experimentResult in 

    }).initializer()
```

There are additional properties which can be setup at the time of initialization

```swift
var sdkInstance: GrowthBookSDK = GrowthBookBuilder(apiHost: <GrowthBook/API_HOST>,
    clientKey: <GrowthBook/Client_KEY>,
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
    .setCacheDirectory(<CacheDirectory>) // This function configures the cache directory used by the application to the designated directory type. Subsequent cache-related operations will target this directory.
    .setStickyBucketService(stickyBucketService: StickyBucketService()) // This function creates a sticky bucket service.
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
    /// api host
    public let apiHost: String?
    /// unique client key
    public let clientKey: String?
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
    /// Hash version of hash function
    let hashVersion: Float?
    /// A more precise version of `coverage`
    let range: BucketRange?
    /// Ranges for experiment variations
    let ranges: [BucketRange]?
    /// Meta info about the experiment variations
    let meta: [VariationMeta]?
    /// Array of filters to apply to the rule
    let filters: [Filter]?
    /// Seed to use for hashing
    let seed: String?
    /// Human-readable name for the experiment
    let name: String?
    /// The phase id of the experiment
    let phase: String?
    /// Array of tracking calls to fire
    let tracks: [TrackData]?
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
    /// Array of ranges, one per variation
    let ranges: [BucketRange]?
    /// Meta info about the variations
    let meta: [VariationMeta]?
    /// Array of filters to apply
    let filters: [Filter]?
    /// The hash seed to use
    let seed: String?
    /// Human-readable name for the experiment
    let name: String?
    /// Id of the current experiment phase
    let phase: String?
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
    let valueHash: String?
    /// The unique key for the assigned variation
    let key: String
    /// The human-readable name of the assigned variation
    let name: String?
    /// The hash value used to assign a variation (float from `0` to `1`)
    let bucket: Float?
    /// Used for holdout groups
    let passthrough: Bool?
}

/// Meta info about the variations
public struct VariationMeta {
    /// Used to implement holdout groups
    let passthrough: Bool?
    /// A unique key for this variation
    let key: String?
    /// A human-readable name for this variation
    let name: String?
}

///Used for remote feature evaluation to trigger the `TrackingCallback`
public struct TrackData {
    let experiment: Experiment
    let result: ExperimentResult
}

```


## Streaming updates

To enable streaming updates set backgroundSync variable to "true"

```swift
var sdkInstance: GrowthBookSDK = GrowthBookBuilder(apiHost: <GrowthBook/API_KEY>, clientKey: <GrowthBook/ClientKey>, attributes: <[String: Any]>, trackingCallback: { experiment, experimentResult in 
    }, refreshHandler: { error in
    }, backgroundSync: true)
    .initializer()
```

## Remote Evaluation

This mode brings the security benefits of a backend SDK to the front end by evaluating feature flags exclusively on a private server. Using Remote Evaluation ensures that any sensitive information within targeting rules or unused feature variations are never seen by the client. Note that Remote Evaluation should not be used in a backend context.

You must enable Remote Evaluation in your SDK Connection settings. Cloud customers are also required to self-host a GrowthBook Proxy Server or custom remote evaluation backend.

To use Remote Evaluation, add the `remoteEval: true` property to your SDK instance. A new evaluation API call will be made any time a user attribute or other dependency changes. You may optionally limit these API calls to specific attribute changes by setting the `cacheKeyAttributes` property (an array of attribute names that, when changed, trigger a new evaluation call).

```swift
var sdkInstance: GrowthBookSDK = GrowthBookBuilder(apiHost: <GrowthBook/API_KEY>, clientKey: <GrowthBook/ClientKey>, attributes: <[String: Any]>, trackingCallback: { experiment, experimentResult in 
    }, refreshHandler: { error in
    }, remoteEval: true)
    .initializer()
```

**note**

If you would like to implement Sticky Bucketing while using Remote Evaluation, you must configure your remote evaluation backend to support Sticky Bucketing. You will not need to provide a StickyBucketService instance to the client side SDK.



## Sticky Bucketing

Sticky bucketing ensures that users see the same experiment variant, even when user session, user login status, or experiment parameters change. See the [Sticky Bucketing docs](/app/sticky-bucketing) for more information. If your organization and experiment supports sticky bucketing, you must implement an instance of the `StickyBucketService` to use Sticky Bucketing. For simple bucket persistence using the browser's LocalStorage (can be polyfilled for other environments).


## License

This project uses the MIT license. The core GrowthBook app will always remain open and free, although we may add some commercial enterprise add-ons in the future.
