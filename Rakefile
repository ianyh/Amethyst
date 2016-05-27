task :setup do
  system 'carthage bootstrap --platform OSX' or exit!(1)
  system 'rbenv install -s' or exit!(1)
  system 'gem install bundler' or exit!(1)
  system 'bundle install' or exit!(1)
  system 'bundle exec pod install' or exit!(1)
end

task :test => :setup do
  system 'xctool clean build test' or exit!(1)
end

task :install => :setup do
  system 'xctool clean install' or exit!(1)
end

task :default => :test
