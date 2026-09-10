Pod::Spec.new do |s|
  s.name             = 'flutter_bio_auth'
  s.version          = '0.1.0'
  s.summary          = 'On-device face detection, liveness, and injectable 1:1 recognition/anti-spoof for Flutter.'
  s.description      = <<-DESC
Face detection/tracking/liveness via Vision (zero bundled models).
Recognition and passive anti-spoof are injectable, model-driven, and
loaded from a developer-supplied asset path.
                       DESC
  s.homepage         = 'https://example.com/flutter_bio_auth'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'you@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
