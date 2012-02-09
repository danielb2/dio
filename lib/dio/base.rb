# Copyright (c) 2012 Michael Dvorkin
#
# Quickie is freely distributable under the terms of MIT license.
# See LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
require "rubygems"
require "rack"
require "awesome_print"

module Dio
  class Request < Rack::Request
    attr_reader :router, :format

    def initialize(env, settings)
      @format = mime_format(env) || settings.default_format
      super(env)
    end

    private
    def mime_format(env)
      ext = File.extname(env["PATH_INFO"])
      if Rack::Mime::MIME_TYPES.include?(ext)
        ext[1..-1].to_sym
      end
    end
  end

  class Response < Rack::Response
  end

  class NotFound < NoMethodError
  end

  class Base
    include Dio::Helpers

    attr_accessor :environment, :request, :response, :params

    #--------------------------------------------------------------------------
    def initialize
      @controllers = {}
    end

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
      @environment, @request, @response = env, Request.new(env, settings), Response.new
      @params = universal_nested_hash(@request.params)
      @params[:controller] = @request.path[/\/([\w.]+)/, 1] || :home

      # ap @request.path
      # ap @params

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
      #   done 200, "body text that is a string"
      #   done 200, [ "body", "that", "responds", "to", ":each" ]
      #
      # #done with three parameters:
      #   done 200, { "X-key" => "value }, "body text that is a string"
      #   done 200, { "X-key" => "value }, [ "body", "that", "responds", "to", ":each" ]
      #
      status?(reply[0]) or headers?(reply[0]) or body?(reply[0]) if reply.size > 0
                           headers?(reply[1]) or body?(reply[1]) if reply.size > 1
                                                 body?(reply[2]) if reply.size > 2

## ap [ response.status, response.headers, response.body ]
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
      # ap e
      # ap e.backtrace
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

    # Load controller file and create an instance of controller class. The way
    # it works is as follows:
    #
    # If controller file hasn't been loaded before then:
    #   - require controller file
    #   - update controllers cache
    # Else if controller file has changed then:
    #   - remove controller class
    #   - reload controller file
    #   - update controllers cache
    # Else:
    #   - do nothing (controller has been loaded and hasn't changed since)
    #
    #--------------------------------------------------------------------------
    def load_controller
      controller_file = "#{settings.root}/#{@params[:controller]}.rb"
      last_updated_at = File.mtime(controller_file)
      #
      # Check controllers cache to see whether the controller file name entry
      # is empty, stale, or up-to-date.
      #
      if !@controllers.key?(controller_file)                  # Empty.
        require controller_file
        @controllers[controller_file] = last_updated_at
      elsif last_updated_at > @controllers[controller_file]   # Stale.
        Object.__send__(:remove_const, @params[:controller].capitalize.to_sym)  # TODO: capitalize => CamelCase
        load controller_file
        @controllers[controller_file] = last_updated_at
      end
      #
      # Now that the controller file has been loaded create a new instance of
      # the controller class.
      #
      # TODO: handle missing class name.
      #
      constantize(@params[:controller]).new(self)
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
      thin.run self, :Host => settings.host, :Port => settings.port do |server|
        $stderr.puts "== Dio is up on #{settings.port} using Thin"
        [ :INT, :TERM ].each { |signal| trap(signal) { quit!(server) } }
        server.threaded = true if server.respond_to? :threaded=
        yield server if block_given?
      end
    rescue Errno::EADDRINUSE => e
      $stderr.puts "== Someone is already up on #{settings.port}!"
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
    set :host, 'localhost'
    set :port, 3131
    set :root, nil  # The actual value is set when the App < Dio::Base
    set :default_format, :html
  end
end
