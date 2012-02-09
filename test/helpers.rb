# Copyright (c) 2012 Michael Dvorkin
#
# Quickie is freely distributable under the terms of MIT license.
# See LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
require "net/http"
require "rack"
require "rack/lint"
require "thin"

module Net                                                        #
  class HTTPResponse                                              # Add convenience methods to response.
    %w(html js json txt xml gif png mp3 wav).each do |ext|        #
      define_method :"#{ext}?" do                                 # def json?
        self["Content-Type"] == Rack::Mime.mime_type(".#{ext}")   #   self["Content-Type"] == "application/json"
      end                                                         # end
    end                                                           #
  end
end

class DioTest
  class TestApp < Dio::Base
    def get(path, headers = {})
      # uri = URI.parse("http://0.0.0.0:3131#{path}")
      # Net::HTTP.get_response(uri)
      Net::HTTP.start("0.0.0.0", 3131) do |http|
        request = Net::HTTP::Get.new(path, headers)
        http.request(request)
      end   
    end 

    def post(path, form_data = {}, headers = {})
      Net::HTTP.start("0.0.0.0", 3131) do |http|
        request = Net::HTTP::Post.new(path, headers)
        request.form_data = form_data
        http.request(request)
      end
    end

    def set(key, value)
      settings.set(key, value)
    end
  end

  class Runner
    def self.start!(application, host = "0.0.0.0", port = 3131)
      dio = application.new

      Thread.new do
        Thin::Logging.silent = true
        Rack::Handler::Thin.run(Rack::Lint.new(dio), :Host => host, :Port => port) do |s|
          @server = s
        end 
      end 
      Thread.pass until @server && @server.running?

      dio
    end

    def self.stop!
      @server.stop if @server && @server.running?
    end
  end

  class Base
    @@app = Runner.start!(TestApp)

    def self.app
      @@app
    end
    #
    # Reset timestamps in the controller cache to make sure newly
    # created controller file gets properly loaded.
    #
    def self.expire_controllers_cache
      cache = @@app.instance_variable_get(:@controllers)
      unless cache.empty?
        cache.each do |file, mtime|
          cache[file] = mtime - 3600
        end
        @@app.instance_variable_set(:@controllers, cache)
      end
    end

    def self.controller(contents, &block)
      controller = contents[/class\s+(\w+)\s*<\s*Dio/, 1]
      raise "Invalid controller class" unless controller
      expire_controllers_cache
      begin
        file = File.expand_path(File.dirname(__FILE__)) << "/#{controller.downcase}.rb"
        File.open(file, "w") { |f| f.write(contents) }
        yield
      ensure
        File.unlink(file)
      end
    end
  end
end

at_exit { DioTest::Runner.stop! }
