Pod::Spec.new do |spec|
  spec.name                      = 'GrowthBook-IOS'
  spec.version                   = '1.0.13'
  spec.homepage                  = "https://github.com/growthbook/growthbook-swift"
  spec.documentation_url         = "https://docs.growthbook.io"
  spec.license                   = 'https://opensource.org/licenses/MIT'
  spec.author                    = { "KevychSolutions Inc." => "volodymyr.nazarkevych@kevychsolutions.com" }
  spec.summary                   = 'Powerful A/B testing SDK for Swift - iOS'
  spec.source                    = { :http => "https://github.com/growthbook/growthbook-swift/releases/download/1.0.13/GrowthBook.xcframework.zip" }
  
  spec.vendored_frameworks      = "GrowthBook.xcframework"

  spec.swift_version             = '5.0'
  spec.ios.deployment_target     = '12.0'
  spec.watchos.deployment_target = '5.0'
  spec.tvos.deployment_target    = '12.0'
  spec.osx.deployment_target     = '10.15'

  spec.pod_target_xcconfig       = { 'DEFINES_MODULE' => 'YES' }

  spec.pod_target_xcconfig       = {'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'}
  spec.user_target_xcconfig      = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

end
