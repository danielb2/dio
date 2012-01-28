root = File.expand_path("../..", __FILE__)
$:.unshift "#{root}/lib"

ENV["RACK_ENV"] = "test"

require "quickie"
require "json"
require "dio"
require "awesome_print"
require "#{root}/test/quickie_helpers"

Dir["#{root}/test/*_test.rb"].each do |file|
  require file unless file.end_with? __FILE__
end
