#!/usr/bin/env ruby
#

require "rubygems"
require "rack"
require "awesome_print"

require File.expand_path(File.dirname(__FILE__) + "/../lib/dio")

class App < Dio::Base
  # set :root, File.dirname(__FILE__)
  ap "self.root: #{self.root.inspect}"
end

class App2 < Dio::Base
  set :root, "xexe"
  ap "self2.root: #{self.root.inspect}"
end

rock = App.new
app2 = App2.new
ap "rock.root: #{rock.class.root.inspect}"
ap "app2.root: #{app2.settings.root.inspect}"
rock.roll!




