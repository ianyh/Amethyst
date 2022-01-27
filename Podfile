platform :osx, '10.12'

use_frameworks!

target 'Amethyst' do
  pod 'Cartography'
  pod 'LoginServiceKit', :git => 'https://github.com/Sunnyyoung/LoginServiceKit.git'
  pod 'MASShortcut'
  pod 'RxCocoa'
  pod 'RxSwift'
  pod 'RxSwiftExt'
  pod 'Silica', git: 'https://github.com/ianyh/Silica', submodules: true
  pod 'SwiftLint'
  pod 'SwiftyBeaver'
  pod 'SwiftyJSON'

  target 'AmethystTests' do
    inherit! :search_paths
    pod 'Nimble', '~> 9.0.1'
    pod 'Quick', '~> 4.0.0'
  end
end
