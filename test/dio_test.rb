# Copyright (c) 2012 Michael Dvorkin
#
# Quickie is freely distributable under the terms of MIT license.
# See LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
root = File.expand_path("../..", __FILE__)
$:.unshift "#{root}/lib"

ENV["RACK_ENV"] = "test"

require "quickie"
require "json"
require "dio"
require "awesome_print"
require "#{root}/test/helpers"

Dir["#{root}/test/*_test.rb"].each do |file|
  require file unless file.end_with? __FILE__
end
