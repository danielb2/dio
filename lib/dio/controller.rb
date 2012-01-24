require "json"

module Dio
  class Controller
    attr_reader :request, :response, :params

    def initialize(app)
      @request, @response, @params = app.request, app.response, app.params
      set_router_rules
    end

    # Unwind current block and return the reply back to catch(:done).
    #--------------------------------------------------------------------------
    def done(*reply)
      throw :done, reply
    end

    private
    # Move routing rules cached by the class to the router instance that is
    # part of incoming request. The cache gets cleared once the transfer is
    # complete so that the next time class gets loaded its cache is empty.
    #--------------------------------------------------------------------------
    def set_router_rules
      self.class.rules ||= []
      self.class.rules.each do |rule|
        request.router.__send__(*rule)
      end
      #
      # Append two default rules.
      #
      request.router.any "/", :index
      request.router.any "/:action/?:id?.?:format?", lambda { |params| params[:action] }
      # ap request.router.rules
    ensure
      self.class.rules = []
    end

    #--------------------------------------------------------------------------
    def route!
      puts "route!(#{params.inspect})"
      action = request.router.match(request, params).to_sym
      puts "router match => #{action.inspect}"
      ap params

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
    ensure
      self.class.hooks = nil
    end

    #--------------------------------------------------------------------------
    def hooks(before_or_after)
      self.class.hooks ? self.class.hooks[before_or_after] : {}
    end

    #--------------------------------------------------------------------------
    def invoke(before_or_after, action)
      puts "invoke(#{before_or_after.inspect}, #{action.inspect})"
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
    class << self
      attr_accessor :rules, :hooks

      #--------------------------------------------------------------------------
      def method_added(method)
        puts "instance method #{method.inspect} added"
        if public_instance_methods.include?(method) && !@adding_method
          begin
            @adding_method = true
            add_json_renderer_for(method)
          ensure
            @adding_method = false
          end
        end
      end

      #--------------------------------------------------------------------------
      def add_json_renderer_for(method)
        alias_method :"original_#{method}", method            # Save the original method.
        remove_method method                                  # Now remove it.
        define_method method do                               # Redefine the method with the method we've just removed.
          status = send :"original_#{method}"                 # Invoke the saved method.
                                                              # The code we want to execute after invoking the method.
          return status unless response.status == 200 && response.body.empty?

          vars = instance_variables - [:@request, :@response, :@params]
          hash = Hash[ vars.map { |var| [ var.to_s[1..-1], instance_variable_get(var) ] } ]
          response.headers["Content-Type"] = "application/json"
          response.body = hash.to_json
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
        puts "routes(#{options.inspect})"
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
