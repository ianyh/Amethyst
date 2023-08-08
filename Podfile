platform :osx, '10.15'

use_frameworks!

target 'Amethyst' do
  pod 'Cartography'
  pod 'LoginServiceKit'
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

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.15'
    end
  end
end
