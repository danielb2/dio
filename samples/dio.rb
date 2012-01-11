#!/usr/bin/env ruby
#

require "rubygems"
require "rack"
require "awesome_print"

module Dio
  HOST = 'localhost'
  PORT = 3131

  class Request < Rack::Request
  end

  class Response < Rack::Response
  end

  class Base
    def call(env)
      @env      = env
      @request  = Request.new(env)
      @response = Response.new
      ap @response
      ap @request.params
      ap @request.path
      controller, action = @request.path.sub(/^\//, '').split('/')
      controller ||= :default
      action ||= :index
      load File.expand_path(File.dirname(__FILE__)) + "/#{controller}.rb"

      klass = constantize(controller).new
      ap klass
      klass.send(action)

      [ 200, { "Content-Type" => "text/html" }, [ "<pre>Hello World</pre>" ]]
    end

    # Run the Dio app as a self-hosted server using Thin, Mongrel or WEBrick.
    def roll!(options = {})
      handler = detect_rack_handler
      handler_name = handler.name.gsub(/.*::/, '')
      handler.run self, :Host => HOST, :Port => PORT do |server|
        $stderr.puts "== Dio is up on #{PORT} using #{handler_name}"
        [:INT, :TERM].each { |sig| trap(sig) { quit!(server, handler_name) } }
        server.threaded = true if server.respond_to? :threaded=
        yield server if block_given?
      end
    rescue Errno::EADDRINUSE => e
      $stderr.puts "== Someone is already up on #{PORT}!"
    end

    private
    def detect_rack_handler
      %w[ thin mongrel webrick ].each do |server_name|
        begin
          return Rack::Handler.get(server_name.to_s)
        rescue LoadError
        rescue NameError
        end
      end
      fail "Server handler (thin, mongrel, webrick) not found."
    end

    def quit!(server, handler_name)
      # Use Thin's hard #stop! if available, otherwise just #stop.
      server.respond_to?(:stop!) ? server.stop! : server.stop
      $stderr.puts "\n== Dio is done"
    end

    def constantize(str)
      camel_cased = str.to_s.downcase.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
      names = camel_cased.split('::')
      names.shift if names.empty? || names[0].empty?

      constant = Object
      names.each do |name|
        constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
      end
      constant
    end
  end
end

class App < Dio::Base
end

rock = App.new
rock.roll!




