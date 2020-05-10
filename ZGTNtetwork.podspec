#
# Be sure to run `pod lib lint ZGTNtetwork.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ZGTNtetwork'
  s.version          = '0.1.0'
  s.summary          = '大部分源码参考自YTKNetwork，只是做了一些小部分的修改，比如使用NSURLSession、以及大量使用内存缓存。'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/kidzss/ZGTNtetwork'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'kidzss' => 'gangtao.zhou@ymm56.com' }
  s.source           = { :git => 'https://github.com/kidzss/ZGTNtetwork.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'ZGTNtetwork/Classes/**/*'
  
  s.requires_arc  = true

  s.dependency "AFNetworking"
  
  s.dependency "YYModel"

  # s.resource_bundles = {
  #   'ZGTNtetwork' => ['ZGTNtetwork/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
