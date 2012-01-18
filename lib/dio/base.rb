#!/usr/bin/env ruby
#

require "rubygems"
require "rack"
require "awesome_print"

module Dio
  HOST = 'localhost'
  PORT = 3131

  class Request < Rack::Request
    attr_reader :router

    def initialize(env)
      @router = Dio::Router.new
      super(env)
    end
  end

  class Response < Rack::Response
  end

  class Base
    include Dio::Helpers

    attr_accessor :environment, :request, :response, :params

    # Set configuration value. All we do is define two accessor methods that
    # return the requested value (as is and boolean).
    #--------------------------------------------------------------------------
    def self.set(key, value)
      self.singleton_class.class_eval do
        define_method key, lambda { value }
        define_method "#{key}?", lambda { !!value }
      end
    end

    # Make settings available through app.settings.key instead of app.class.key
    #--------------------------------------------------------------------------
    def settings
      self.class
    end

    #--------------------------------------------------------------------------
    def call(env)
      @environment, @request, @response = env, Request.new(env), Response.new
      @params = universal_nested_hash(@request.params)
      @params[:controller] = $1 if @request.path =~ /\/(\w+)/
      @params[:controller] ||= :home
      ap @request.path
      ap @params
      dispatch!
    end

    #--------------------------------------------------------------------------
    def dispatch!
      controller = load_controller
      controller.__send__(:route!)
      ap response.status
      ap response.headers
      ap response.body

      [ response.status, response.headers, response.body ]
      # [ 200, { "Content-Type" => "text/html" }, [ "<pre>Hello World</pre>" ]]
    end

    # Load controller file and create an instance of controller class. Note
    # that in development mode controller file gets reloaded with each request
    # whereas in production it gets required once.
    #--------------------------------------------------------------------------
    def load_controller
      controller_file_name = "#{settings.root}/#{@params[:controller]}.rb"
      if settings.mode == :development
        puts "LOADING #{controller_file_name}"
        load controller_file_name
      else
        puts "REQUIRING #{controller_file_name}"
        require controller_file_name
      end
      constantize(@params[:controller]).new(self)     # TODO: handle missing class.
    end

    # Run the Dio app as a self-hosted server using Thin, Mongrel or WEBrick.
    #--------------------------------------------------------------------------
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

    # Set application's root directory by fetching the Ruby file where
    # App < Dio::Base, and getting its full path. The application can override
    # this value, for example:
    #
    #   class App < Dio::Base
    #     set :root, "~/app"
    #   end
    #
    #--------------------------------------------------------------------------
    def self.inherited(subclass)
      subclass_file_name = caller(1).first.split(':').first
      subclass.set :root, File.expand_path(File.dirname(subclass_file_name))
      super
    end

    #--------------------------------------------------------------------------
    def detect_rack_handler
      %w[ thin puma mongrel webrick ].each do |server_name|
        begin
          return Rack::Handler.get(server_name.to_s)
        rescue LoadError
        rescue NameError
        end
      end
      fail "Server handler (thin, puma, mongrel, webrick) not found."
    end

    #--------------------------------------------------------------------------
    def quit!(server, handler_name)
      # Use Thin's hard #stop! if available, otherwise just #stop.
      server.respond_to?(:stop!) ? server.stop! : server.stop
      $stderr.puts "\n== Dio is done"
    end

    # Default settings.
    #--------------------------------------------------------------------------
    set :root, nil  # The actual value is set when the App < Dio::Base
    set :mode, :development
  end
end
