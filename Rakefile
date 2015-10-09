task :setup do
  system 'carthage update'
  system 'pod install'
end

task :test => :setup do
  system 'xctool clean build test'
end

task :install => :setup do
  system 'xctool clean install'
end

task :default => :test
