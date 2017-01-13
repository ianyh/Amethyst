platform :osx, '10.12'

use_frameworks!

target 'Amethyst' do
  pod 'Fabric'
  pod 'Crashlytics'

  pod 'CCNLaunchAtLoginItem', '~> 0.1'
  pod 'CCNPreferencesWindowController-ObjC'
  pod 'Log'
  pod 'MASShortcut', :git => 'https://github.com/ianyh/MASShortcut'
  pod 'RxCocoa'
  pod 'RxSwift'
  pod 'Silica', :git => 'https://github.com/ianyh/Silica', :commit => 'a73415cd79ccee6e7c3dcb87ecf5d9889a6d85d2'
  pod 'SwiftyJSON'
  target 'AmethystTests' do
    inherit! :search_paths
    pod 'Nimble'
    pod 'Quick'
  end
end
