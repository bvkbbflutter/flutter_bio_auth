Pod::Spec.new do |s|
  s.name             = 'flutter_bio_auth'
  s.version          = '0.2.1'
  s.summary          = 'On-device face intelligence, 1:1 face recognition, liveness, and delivery compliance for Flutter.'
  s.description      = <<-DESC
Modular on-device AI face intelligence, 1:1 face recognition, active liveness,
facial expressions, and delivery partner compliance for Flutter.
                       DESC
  s.homepage         = 'https://github.com/bvkbbflutter/flutter_bio_auth'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'you@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
