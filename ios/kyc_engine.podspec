Pod::Spec.new do |s|
  s.name             = 'kyc_engine'
  s.version          = '0.1.0'
  s.summary          = 'Headless face liveness verification engine for Flutter.'
  s.description      = 'Face detection, anti-spoofing, liveness challenges and liveness video recording.'
  s.homepage         = 'https://github.com/RoqquPay/kyc-flutter-sdk'
  s.license          = { :file => '../LICENSE' }
  s.authors          = 'RoqquPay'
  s.source           = { :path => '.' }
  s.source_files     = 'kyc_engine/Sources/kyc_engine/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.frameworks       = 'AVFoundation', 'CoreMedia', 'VideoToolbox'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
