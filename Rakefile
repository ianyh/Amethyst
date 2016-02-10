task :setup do
  system 'carthage bootstrap --platform OSX' or exit!(1)
  system 'pod install' or exit!(1)
end

task :test => :setup do
  system 'xctool clean build test' or exit!(1)
end

task :install => :setup do
  system 'xctool clean install' or exit!(1)
end

task :default => :test
