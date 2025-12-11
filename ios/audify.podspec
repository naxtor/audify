#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint audify.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'audify'
  s.version          = '0.0.1'
  s.summary          = 'High-performance audio visualizer for Flutter with trap/dubstep style visualizations.'
  s.description      = <<-DESC
High-performance audio visualizer package for Flutter focusing on trap/dubstep style visualizations. 
Features circular spectrum, bar spectrum, and waveform displays with real-time FFT processing.
                       DESC
  s.homepage         = 'https://pub.dev/packages/audify'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Nabil Faris' => 'hello@nabilfaris.id' }
  s.source           = { :path => '.' }
  s.source_files = 'audify/Sources/audify/**/*.swift'
  s.resource_bundles = {'audify_privacy' => ['audify/Sources/audify/PrivacyInfo.xcprivacy']}
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  
  # Required frameworks for audio processing
  s.frameworks = 'AVFoundation', 'Accelerate'
end
