require "json"
# Free-form routes:
#
# routes do
#   get  "/list"       => :list
#   post "/cancel/:id" => :cancel
# end
#
# Predefined :restful routes:
#
# routes :restful, :except => :delete
# routes :restful, :only => [ :index, :new ]
#
module Dio
  class Controller
    attr_reader :request, :response, :params

    def initialize(app)
      @request, @response, @params = app.request, app.response, app.params
      set_router_rules
    end

    private

    @@after_hook_is_running = false

    #--------------------------------------------------------------------------
    def self.method_added(method)
      puts "instance method #{method.inspect} added"
      if self.public_instance_methods.include?(method) && !@@after_hook_is_running
        add_json_renderer_for(method)
      end
    end

    #--------------------------------------------------------------------------
    def self.add_json_renderer_for(method)
      @@after_hook_is_running = true
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
    ensure
      @@after_hook_is_running = false
    end

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
      action = request.router.match(request, params)
      puts "router match => #{action.inspect}"
      ap params

      invoke(:before, action) if self.class.hooks[:before].any?
      if public_methods.include?(action.to_sym) && respond_to?(action)
        public_send(action) # Route only to public methods.
        invoke(:after, action) if self.class.hooks[:after].any?
      else
        raise NotFound
      end
    ensure
      self.class.hooks = nil
    end

    #--------------------------------------------------------------------------
    def invoke(before_or_after, action)
      puts "invoke(#{before_or_after.inspect}, #{action.inspect})"
      self.class.hooks[before_or_after].each do |hook|
        next if hook[:only] && !Array(hook[:only]).include?(action)
        next if hook[:except] && Array(hook[:except]).include?(action)
        puts "invoking #{hook[:method].inspect}"
        __send__(hook[:method])
      end
    end

    #--------------------------------------------------------------------------
    class << self
      attr_accessor :rules, :hooks
      #
      # routes do
      #   verb pattern => action
      # end
      #
      # Where +pattern+ is one of the following:
      #
      #   "/hello"                # Static.
      #   "/hello/:id"            # With required named parameters.
      #   "/hello/*/world/*"      # With required wildcard parameters, params[:wildcard]
      #   "/hello.?:format?"      # With optional parameters.
      #   /\/hello\/([\w+])/      # Regular expression.
      #
      # The +action+ is either:
      #
      #  :method                  # Public controller method to invoke.
      #  lambda { |params| ... }  # Block that accepts params and returns :method to invoke.
      #
      #------------------------------------------------------------------------
      def routes(group = nil, scope = {}, &block)
        puts "routes(#{group.inspect}, #{scope.inspect})"
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

        if group
          named_routes(group, scope)
        else
          yield # routes do ... end
        end
      end

      #--------------------------------------------------------------------------
      [ :before, :after ].each do |hook|
        define_method hook do |method, scope = {}|
          puts "#{hook}: #{method.inspect}"
          @hooks ||= { :before => [], :after => [] }
          @hooks[hook] << { :method => method }.merge(scope)
        end
      end

      #--------------------------------------------------------------------------
      def named_routes(group, scope = {})
        if group == :restful
          #
          # routes :restful, :except => :delete
          # routes :restful, :only => [ :index, :new ]
          #
          only   = scope[:only]   ? Array(scope[:only])   : [ :index, :new, :create, :show, :edit, :update, :destroy ]
          except = scope[:except] ? Array(scope[:except]) : []
          #
          #  Note that the routes are listed in "reverse" since the last route gets
          #  evaluated first.
          #
          delete "/:id"  => :destroy if only.include?(:destroy) && !except.include?(:destroy)
          put    "/:id"  => :update  if only.include?(:update)  && !except.include?(:update)
          get    "/edit" => :edit    if only.include?(:edit)    && !except.include?(:edit)
          get    "/:id"  => :show    if only.include?(:show)    && !except.include?(:show)
          post   "/"     => :create  if only.include?(:create)  && !except.include?(:create)
          get    "/new"  => :new     if only.include?(:new)     && !except.include?(:new)
          get    "/"     => :index   if only.include?(:index)   && !except.include?(:index)
        end
      end
    end
  end
end
