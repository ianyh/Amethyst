platform :osx, '10.12'

use_frameworks!

target 'Amethyst' do
  pod 'Cartography'
  pod 'LoginServiceKit', :git => 'https://github.com/Clipy/LoginServiceKit.git'
  pod 'MASShortcut'
  pod 'RxCocoa', '= 4.3.1'
  pod 'RxSwift', '= 4.3.1'
  pod 'RxSwiftExt', '= 3.3.0'
  pod 'Silica', git: 'https://github.com/ianyh/Silica', submodules: true
  pod 'Sparkle'
  pod 'SwiftyBeaver'
  pod 'SwiftyJSON', '~> 3.1'

  target 'AmethystTests' do
    inherit! :search_paths
    pod 'Nimble'
    pod 'Quick'
  end
end
