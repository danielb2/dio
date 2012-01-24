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

  class NotFound < NoMethodError
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
      @params[:controller] = $1 if @request.path =~ /\/([\w.]+)/
      @params[:controller] ||= :home
      ap @request.path
      ap @params

      reply = catch(:done) { dispatch! }
      reply = Array(reply) unless reply.is_a?(Array)
      #
      # #done with single parameter:
      #   done 200
      #   done { "X-key" => "value }
      #   done "body text that is a string"
      #   done [ "body", "that", "responds", "to", ":each" ]
      #
      # #done with two parameters:
      #   done 200, { "X-key" => "value }
      #   done "body text that is a string"
      #   done 200, [ "body", "that", "responds", "to", ":each" ]
      #
      # #done with three parameters:
      #   done 200, { "X-key" => "value }, "body text that is a string"
      #   done 200, { "X-key" => "value }, [ "body", "that", "responds", "to", ":each" ]
      #
      status?(reply[0]) or headers?(reply[0]) or body?(reply[0]) if reply.size > 0
                           headers?(reply[1]) or body?(reply[1]) if reply.size > 1
                                                 body?(reply[2]) if reply.size > 2

   ap [ response.status, response.headers, response.body ]
      [ response.status, response.headers, response.body ]
    end

    #--------------------------------------------------------------------------
    def dispatch!
      if static?
        serve_static
      else
        controller = load_controller
        controller.__send__(:route!)
        # ap response.status
        # ap response.headers
        # ap response.body
      end
    rescue Exception => e
      salvage!(e)
    end

    #--------------------------------------------------------------------------
    def salvage!(e)
      ap e
      ap e.backtrace
      headers :content_type => "text/html"
      if NotFound === e
        status 404
        body "<h1>#{response.status} - Not Found</h1><p>The requested URL #{request.path} was not found on this server."
      else
        status = 500 unless status && status.between?(400, 599)
        body = "<h1>#{status} - #{e.class}: #{e.message}</h1>"
        if status >= 500 # Show backtrace for server errros.
          body += "<pre>" << e.backtrace.join("\n  ") << "</pre>"
        end
      end
    end

    # Load controller file and create an instance of controller class.
    #--------------------------------------------------------------------------
    def load_controller
      controller_file_name = "#{settings.root}/#{@params[:controller]}.rb"
      # TODO: track mktime and use require if the file hasn't changed.
      puts "Loading #{controller_file_name}"
      load controller_file_name
      constantize(@params[:controller]).new(self)     # TODO: handle missing class.
    rescue LoadError
      raise NotFound
    end

    #--------------------------------------------------------------------------
    def serve_static
      headers[:content_disposition] = 'inline'
      file = Rack::File.new("")                   # Root is empty, path is full file spec.
      file.path = environment["dio.static_file"]
      status, headers, body =
        if file.method(:serving).arity == 0
          file.serving                            # Older Rack doesn't accept a parameter.
        else
          file.serving(environment)
        end
    rescue Errno::ENOENT
      raise NotFound
    end

    # Run the Dio app as a self-hosted server using Thin.
    #--------------------------------------------------------------------------
    def roll!(options = {})
      thin = Rack::Handler.get("thin")
      thin.run self, :Host => HOST, :Port => PORT do |server|
        $stderr.puts "== Dio is up on #{PORT} using Thin"
        [ :INT, :TERM ].each { |signal| trap(signal) { quit!(server) } }
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

    # Use Thin's hard #stop!
    #--------------------------------------------------------------------------
    def quit!(server)
      server.stop!
      $stderr.puts "\n== Dio is done"
    end

    # Default settings.
    #--------------------------------------------------------------------------
    set :root, nil  # The actual value is set when the App < Dio::Base
  end
end
