platform :osx, '10.10'

use_frameworks!

target 'Amethyst' do
  pod 'CCNLaunchAtLoginItem', '~> 0.1'
  pod 'CCNPreferencesWindowController', git: 'https://github.com/phranck/CCNPreferencesWindowController'
  pod 'MASShortcut', :git => 'https://github.com/ianyh/MASShortcut'
  pod 'RxCocoa'
  pod 'RxSwift'
  pod 'Silica', :git => 'https://github.com/ianyh/Silica'
  pod 'SwiftyJSON'
  target 'AmethystTests' do
    inherit! :search_paths
    pod 'Nimble'
    pod 'Quick'
  end
end
