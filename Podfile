platform :osx, '10.12'

use_frameworks!

target 'Amethyst' do
  pod 'Cartography'
  pod 'Log'
  pod 'LoginServiceKit', :git => 'https://github.com/Clipy/LoginServiceKit.git'
  pod 'MASShortcut', git: 'https://github.com/ianyh/MASShortcut'
  pod 'RxCocoa'
  pod 'RxSwift'
  pod 'RxSwiftExt'
  pod 'Silica', git: 'https://github.com/ianyh/Silica'
  pod 'Sparkle'
  pod 'SwiftyJSON', '~> 3.1'

  target 'AmethystTests' do
    inherit! :search_paths
    pod 'Nimble'
    pod 'Quick'
  end
end
