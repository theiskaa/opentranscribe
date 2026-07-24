Pod::Spec.new do |s|
  s.name             = 'liquid'
  s.version          = '0.1.0'
  s.summary          = 'Native iOS LiquidGlass components for Flutter.'
  s.description      = <<-DESC
Native platform views that render LiquidGlass controls (toggle, tab bar, popup menu) for Flutter apps.
DESC
  s.homepage         = 'https://example.com/liquid'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Red Money' => 'dev@red.money' }
  s.source           = { :path => '.' }
  s.source_files     = 'liquid/Sources/liquid/**/*'
  s.dependency       'Flutter'
  s.platform         = :ios, '14.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
