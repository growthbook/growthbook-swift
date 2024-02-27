Pod::Spec.new do |spec|
  spec.name                      = 'GrowthBook-IOS'
  spec.version                   =  ENV['LIB_VERSION']
  spec.homepage                  = 'https://github.com/growthbook/growthbook-swift'
  spec.documentation_url         = 'https://docs.growthbook.io'
  spec.license                   = 'https://opensource.org/licenses/MIT'
  spec.author                    = { 'KevychSolutions' => 'volodymyr.nazarkevych@kevychsolutions.com' }
  spec.summary                   = 'Powerful A/B testing SDK for Swift - iOS'
  spec.source                    = { :http => "https://github.com/growthbook/growthbook-swift/releases/download/" + ENV['LIB_VERSION'] + "/GrowthBook.xcframework.zip" }
  
  spec.vendored_frameworks       = "build/GrowthBook.xcframework"

  spec.swift_version             = ['5.0', '5.1', '5.2']
  spec.ios.deployment_target     = '12.0'
  spec.watchos.deployment_target = '5.0'
  spec.tvos.deployment_target    = '12.0'
  spec.osx.deployment_target     = '10.15'

  spec.pod_target_xcconfig       = { 'DEFINES_MODULE' => 'YES' }

end
