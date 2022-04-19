Pod::Spec.new do |s|
  s.name                = 'GrowthBook'
  s.version             = '1.0.0'
  s.homepage            = ""
  s.documentation_url   = ""
  s.license             = { :type => 'MIT' }
  s.author              = { "Inc." => "" }
  s.summary             = "A/B testing"
  s.source           = { :git => "", :tag => s.version }

  s.description         = <<-DESC

                          DESC

  s.swift_version       = '5.0'
  s.dependency          "SwiftyJSON", "~> 4.0"
  s.dependency          "Logging"
  s.ios.deployment_target = '11.0'
  s.watchos.deployment_target = '6.2'
  s.tvos.deployment_target = '12.0'
  s.osx.deployment_target = '10.13'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  s.source_files = 'Sources/**/*.swift'
end
