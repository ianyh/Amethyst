task :setup do
  system 'git submodule update --init'
  system 'pod install'
end

task :test => :setup do
  system 'xctool clean build test'
end

task :install => :setup do
  system 'xcodebuild -workspace Amethyst.xcworkspace -scheme Amethyst clean install'
end

task :default => :test
