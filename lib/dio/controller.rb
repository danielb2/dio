# Copyright (c) 2012 Michael Dvorkin
#
# Quickie is freely distributable under the terms of MIT license.
# See LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
require "json"
require "tilt"

module Dio
  class Controller
    attr_reader :request, :response, :params, :settings, :routes

    def initialize(app)
      @request, @response, @params, @settings = app.request, app.response, app.params, app.settings
      initialize_routes
    end

    # Unwind current block and return the reply back to catch(:done).
    #--------------------------------------------------------------------------
    def done(*reply)
      throw :done, reply
    end

    private

    # Initialize the routes instance by processing routing rules set up when
    # the class was loaded. Append two default routing rules at the end.
    #--------------------------------------------------------------------------
    def initialize_routes
      @routes = Dio::Router.new
      self.class.rules ||= []           # routes { ... } block is optional and if it's missing the rules are nil.
      self.class.rules.each do |rule|
        @routes.__send__(*rule)
      end
      @routes.any "/", :index
      @routes.any "/:action/?:id?.?:format?", lambda { |params| params[:action] }
      # ap @routes
    end

    #--------------------------------------------------------------------------
    def route!
      # ap self.class.hooks
      # puts "route!(#{params.inspect})"
      action = routes.match(request, params).to_sym
      # puts "router match => #{action.inspect}"
      # ap params

      invoke(:before, action) if hooks(:before).any?
      #
      # Route only to public methods.
      #
      if public_methods.include?(action.to_sym) && respond_to?(action)
        public_send(action)
        invoke(:after, action) if hooks(:after).any?
      else
        raise NotFound
      end
    end

    #--------------------------------------------------------------------------
    def hooks(before_or_after)
      self.class.hooks ? self.class.hooks[before_or_after] : {}
    end

    #--------------------------------------------------------------------------
    def invoke(before_or_after, action)
      # puts "invoke(#{before_or_after.inspect}, #{action.inspect})"
      self.class.hooks[before_or_after].each do |hook|
        next if hook[:only] && !Array(hook[:only]).include?(action)
        next if hook[:except] && Array(hook[:except]).include?(action)
        puts "invoking #{hook[:method].inspect}"
        case hook[:method]
          when Symbol, String then __send__(hook[:method])
          when Proc then hook[:method].call(self)
          else raise "Invalid #{before_or_after} hook"
        end
      end
      response.status
    end

    #--------------------------------------------------------------------------
    def find_template_for(action)
      path = "#{settings.root}/views/#{self.class.name.downcase}/#{action}.#{request.format}."
      [ :erb, :haml ].each do |engine|
        path.sub!(/\.\w*$/, ".#{engine}")
        return path, engine if File.readable?(path)
      end
      nil
    end

    #--------------------------------------------------------------------------
    class << self
      attr_accessor :rules, :hooks

      # Override public methods to automagically call render at the end.
      #--------------------------------------------------------------------------
      def method_added(action)
        # puts "instance method #{action.inspect} added"
        if public_instance_methods.include?(action) && !@adding_method
          begin
            @adding_method = true
            auto_render(action)
          ensure
            @adding_method = false
          end
        end
      end

      # Invoke the original action, then do the rendering.
      #--------------------------------------------------------------------------
      def auto_render(action)
        alias_method :"original_#{action}", action            # Stash the original action.
        remove_method action                                  # Now we can remove it.
        define_method action do                               # Redefine the action we've just removed.
          #
          # Invoke stashed action (the original one defined by user).
          #
          status = __send__ :"original_#{action}"
          return status if response.status != 200 || !response.body.empty?
          #
          # So far we support only JSON renderer. Grab all instance variables
          # except @request, @response, and @params and convert them to JSON hash.
          #
          case request.format
          when :json
            vars = instance_variables - [ :@request, :@response, :@params, :@settings, :@routes ]
            hash = Hash[ vars.map { |var| [ var.to_s[1..-1], instance_variable_get(var) ] } ]
            response.headers["Content-Type"] = "application/json"
            response.body = [ hash.to_json ]
          when :html
            path, engine = find_template_for(action)
            raise "Missing HTML template for #{self.class}##{action}" if !path || !engine
            template = Tilt[engine]
            response.body = [ template.new(path).render(self) ]
          end
        end
      end
      #
      # Routes are defined within the controller class.
      #
      # routes do
      #   verb pattern => action
      # end
      #
      # The +verb+ specifies HTTP method i.e. one of "get", "post", "put", "delete",
      # or "any". The route +pattern+ is one of the following:
      #
      #   "/hello"                # Static string.
      #   "/hello/:id"            # Required named parameters => params[:id]
      #   "/hello/*/world/*"      # Required wildcard parameters => params[:wildcard]
      #   "/hello.?:format?"      # Optional parameters => params[:format] if specified.
      #   /\/hello\/([\w+])/      # Regular expression => params[:captures]
      #
      # The +action+ is either:
      #
      #  :method                  # Public controller method to invoke.
      #  lambda { |params| ... }  # Block that accepts params and returns :method to invoke.
      #
      # Restful routes is a shortcut that defines routing rules for :index, :new,
      # :create, :show, :edit, :update, :destroy methods. For examlpe:
      #
      #   routes :restful, :except => :destroy
      #   routes :restful, :only => [ :index, :show ]
      #
      #------------------------------------------------------------------------
      def routes(*options, &block)
        # puts "routes(#{options.inspect})"
        @rules ||= begin
          self.class.instance_eval do
            [ :get, :post, :put, :delete, :any ].each do |verb|
              define_method verb do |rule|
                @rules << [ verb, *rule.flatten ]
              end
            end
          end
          []
        end

        yield if block
        if options.first == :restful
          restful_routes(*options[1..-1])
        end
      end
      #
      # Define +before+ and +after+ hook methods. The hooks get executed in the
      # order received before or after the current action. Examples:
      #
      #   before :hello, :only => :index
      #   after :cheers, :goodbye, :except => [ :new, :destroy ]
      #
      # With a block - accepts current controller instance as a parameter.
      #
      #   after :only => :index do |controller|
      #     puts controller.response.inspect
      #   end
      #
      #--------------------------------------------------------------------------
      [ :before, :after ].each do |hook, &block|
        define_method hook do |*names, &block|
          puts "#{hook}: #{names.inspect}"
          @hooks ||= { :before => [], :after => [] }
          scope = names.last.is_a?(Hash) ? names.pop : {}
          names << block if block # When invoking the hook it might be Symbol or Proc.
          names.each do |name|
            @hooks[hook] << { :method => name }.merge(scope)
          end
        end
      end
      #
      # routes :restful, :except => :delete
      # routes :restful, :only => [ :index, :new ]
      #
      #--------------------------------------------------------------------------
      def restful_routes(scope = {})
        puts "restful_routes(#{scope.inspect})"
        only = scope[:only] ? Array(scope[:only]) : [ :index, :new, :create, :show, :edit, :update, :destroy ]
        except = scope[:except] ? Array(scope[:except]) : []
        excluded = lambda { |method| !only.include?(method) || except.include?(method) }

        get    "/"     => :index   unless excluded[:index]
        get    "/new"  => :new     unless excluded[:new]
        post   "/"     => :create  unless excluded[:create]
        get    "/:id"  => :show    unless excluded[:show]
        get    "/edit" => :edit    unless excluded[:edit]
        put    "/:id"  => :update  unless excluded[:update]
        delete "/:id"  => :destroy unless excluded[:destroy]
      end
    end
  end
end
