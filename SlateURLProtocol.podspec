Pod::Spec.new do |s|
  s.name             = "SlateURLProtocol"
  s.version          = "0.1.0"
  s.summary          = "A custom NSURLProtocol."
  s.description      = <<-DESC
			A custom NSURLProtocol. Provide a general HTTP cache, support offline usage. 
                       DESC
  s.homepage         = "https://github.com/mmslate/SlateURLProtocol"
  s.license          = 'MIT'
  s.author           = { "linyize" => "linyize@gmail.com" }
  s.source           = { :git => "https://github.com/mmslate/SlateURLProtocol.git", :tag => s.version.to_s }
  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.source_files = '*.{h,m}'
  s.dependency 'AFNetworking'
end
