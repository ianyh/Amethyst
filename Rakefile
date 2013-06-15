task :test do
  system 'xctool build test'
end

task :install do
  system 'xcodebuild -workspace Amethyst.xcworkspace -scheme Amethyst -configuration Release install'
end

task :default => :test
