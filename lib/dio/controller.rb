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
    attr_accessor :request, :response, :params

    def initialize(app)
      @request, @response, @params = app.request, app.response, app.params
      self.class.routes(:default)
      self.class.routes(:restful) unless routes?
    end

    private

    def routes?
      !!self.class.router
    end

    def router
      puts "router: #{self.class.router.inspect}"
      self.class.router
    end

    def route!
      puts "route!(#{params.inspect})"
      action = router.match(request, params)
      puts "router match => #{action.inspect}"
      ap params
      __send__(action)
    end

    class << self
      attr_accessor :router

      # routes do
      #   verb pattern => action
      # end
      #
      # Where +pattern+ is one of the following:
      #
      #   "/hello"              # Static.
      #   "/hello/:id"          # With required named parameters.
      #   "/hello/*/world/*"    # With required wildcard parameters, params[:wildcard]
      #   "/hello.?:format?"    # With optional parameters.
      #   /\/hello\/([\w+])/    # Regular expression.
      #
      # The +action+ is either:
      #
      #  :method                # Public controller method to invoke.
      #  lambda { }             # Block that returns :method to invoke.
      #
      #--------------------------------------------------------------------------
      def routes(group = nil, scope = {}, &block)
        puts "routes(#{group.inspect}, #{scope.inspect})"
        if group
          named_routes(group, scope)
        else
          anonymous_routes(&block)
        end
      end

      #--------------------------------------------------------------------------
      def anonymous_routes(&block)
        @router ||= begin
          router = Dio::Router.new
          self.class.instance_eval do
            [ :get, :post, :put, :delete, :any ].each do |verb|
              define_method verb do |rule|
                pattern, action = rule.to_a.flatten
                router.__send__(verb, pattern, action)
              end
            end
          end
          router
        end
        yield
      end

      #--------------------------------------------------------------------------
      def named_routes(group, scope = {})
        if group == :default
          any "/:action?/?:id?" => :dynamic
        elsif group == :restful
          only   = scope[:only]   ? Array(scope[:only])   : [ :index, :new, :create, :show, :edit, :update, :destroy ]
          except = scope[:except] ? Array(scope[:except]) : []

          self.instance_eval do
            get    "/:self"      => :index   if only.include?(:index)   && !except.include?(:index)
            get    "/:self/new"  => :new     if only.include?(:new)     && !except.include?(:new)
            post   "/:self"      => :create  if only.include?(:create)  && !except.include?(:create)
            get    "/:self/:id"  => :show    if only.include?(:show)    && !except.include?(:show)
            get    "/:self/edit" => :edit    if only.include?(:edit)    && !except.include?(:edit)
            put    "/:self/:id"  => :update  if only.include?(:update)  && !except.include?(:update)
            delete "/:self/:id"  => :destroy if only.include?(:destroy) && !except.include?(:destroy)
          end
        end
      end
    end
  end
end
