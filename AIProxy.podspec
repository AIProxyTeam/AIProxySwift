Pod::Spec.new do |s|
  s.name         = 'AIProxy'
  s.version      = '0.156.0'
  s.summary      = 'AIProxy Swift SDK for secure AI integrations'
  s.description  = 'Access OpenAI, Anthropic, and other AI providers securely without exposing API keys in your app. See https://www.aiproxy.com for more'
  s.homepage     = 'https://github.com/lzell/AIProxySwift'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Lou Zell' => 'lou@aiproxy.com' }
  s.source       = { :git => 'https://github.com/lzell/AIProxySwift.git', :tag => s.version.to_s }

  s.ios.deployment_target = '17.0'
  s.osx.deployment_target = '14.0'
  s.watchos.deployment_target = '10.0'
  s.visionos.deployment_target = '2.0'
  s.swift_version = '6.2'

  s.source_files = 'Sources/AIProxy/**/*.swift'
  s.resource_bundles = { 'AIProxy' => ['Sources/AIProxy/Resources/PrivacyInfo.xcprivacy'] }
end
