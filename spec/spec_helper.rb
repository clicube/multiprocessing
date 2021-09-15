begin
  require 'simplecov'

  SimpleCov.start do
    add_filter "spec/"
  end

  pid = Process.pid
  SimpleCov.at_exit do
    SimpleCov.result.format! if Process.pid == pid
  end
rescue LoadError
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'timeout'
require 'multiprocessing'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.around(:each) do |example|
    Timeout::timeout(10) {
      example.run
    }
  end
end
