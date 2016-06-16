Pod::Spec.new do |s|
  s.name             = "SlateURLProtocol"
  s.version          = "3.4.2.1"
  s.summary          = "A custom NSURLProtocol."
  s.description      = <<-DESC
			A custom NSURLProtocol. Provide a general HTTP cache, support offline usage. 
                       DESC
  s.homepage         = "https://github.com/islate/SlateURLProtocol"
  s.license          = 'MIT'
  s.author           = { "linyize" => "linyize@gmail.com" }
  s.source           = { :git => "https://github.com/islate/SlateURLProtocol.git", :tag => s.version.to_s }
  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.source_files = 'SlateURLProtocol/*.{h,m}'
  s.dependency 'SlateReachability'
  s.dependency 'SlateUtils'
end
