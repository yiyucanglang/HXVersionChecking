Pod::Spec.new do |s|
  s.name             = 'HXVersionChecking'
  s.version          = '0.0.1'
  s.summary          = 'convenient version checking module'

  s.homepage         = 'https://github.com/yiyucanglang'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'dahuanxiong' => 'xinlixuezyj@163.com' }
  s.source           = { :git => 'https://github.com/yiyucanglang/HXVersionChecking.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'
  s.public_header_files = '*{h}'
  s.source_files = '*.{h,m}'
  s.dependency 'AFNetworking'
 end
