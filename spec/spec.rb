require 'minitest/spec'
require 'minitest/autorun'
Dir::glob(File.expand_path(File.dirname(__FILE__))+"/**/*.rb").each  do |f|
  require f
end

