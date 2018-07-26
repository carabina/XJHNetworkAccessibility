#
# Be sure to run `pod lib lint XJHNetworkAccessibility.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'XJHNetworkAccessibility'
  s.version          = '0.1.0'
  s.summary          = 'A iOS WiFi and cellulardata authorization detective Manager.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = '帮助解决app的wifi或者蜂窝移动数据授权检测模块'

  s.homepage         = 'https://github.com/cocoadogs/XJHNetworkAccessibility'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '许君浩' => 'cocoadogs@163.com' }
  s.source           = { :git => 'https://github.com/许君浩/XJHNetworkAccessibility.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'

  s.source_files = 'XJHNetworkAccessibility/Classes/**/*'
  
  # s.resource_bundles = {
  #   'XJHNetworkAccessibility' => ['XJHNetworkAccessibility/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  s.dependency 'ReactiveObjC', '~> 3.1.0'
end
