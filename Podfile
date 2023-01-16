platform :osx, '10.15'

use_frameworks!

target 'Amethyst' do
  pod 'Cartography'
  pod 'LoginServiceKit', :git => 'https://github.com/Sunnyyoung/LoginServiceKit.git'
  pod 'MASShortcut'
  pod 'RxCocoa'
  pod 'RxSwift'
  pod 'RxSwiftExt'
  pod 'Silica', git: 'https://github.com/ianyh/Silica', submodules: true
  pod 'Sparkle'
  pod 'SwiftLint'
  pod 'SwiftyBeaver'
  pod 'SwiftyJSON'
  pod 'Yams'

  target 'AmethystTests' do
    inherit! :search_paths
    pod 'Nimble', '~> 11.2.1'
    pod 'Quick', '~> 6.1.0'
  end
end
