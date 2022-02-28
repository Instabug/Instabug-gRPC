Pod::Spec.new do |s|
  s.name             = "Instabug-gRPC-ObjC"
  s.version          = "0.1.0"
  s.summary          = "Capturing gRPC requests for iOS"
  s.homepage         = "http://instabug.com"
  s.license          = {
      :type => 'Commercial',
      :text => <<-LICENSE
                Copyright (C) 2014 Instabug
                Permission is hereby granted to use this framework as is, modification are not allowed.
                All rights reserved.
        
        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
        THE SOFTWARE.
      LICENSE
    }
  s.author           = { "Instabug" => "contactus@instabug.com" }
  s.platform         = :ios, '10.0'
  s.source           = { :git => "https://github.com/Instabug/Instabug-gRPC.git", :tag => "#{s.version}" }

  s.source_files = 'Instabug-grpc-objc/**/*.{h,m,swift}'
  s.requires_arc     = true
  s.dependency 'Instabug', '>= 10.11.8'
  s.dependency 'gRPC'
end
