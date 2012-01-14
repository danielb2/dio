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
      self.class.routes :default
    end

    private

    #--------------------------------------------------------------------------
    def router
      self.class.router
    end

    #--------------------------------------------------------------------------
    def route!
      puts "route!(#{params.inspect})"
      action = router.match(request, params)
      puts "router match => #{action.inspect}"
      ap params
      __send__(action)
    end


    class << self
      attr_reader :router
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
        @router ||= begin
          router = Dio::Router.new
          self.class.instance_eval do
            [ :get, :post, :put, :delete, :any ].each do |verb|
              define_method verb do |rule|
                pattern, action = rule.flatten
                router.__send__(verb, pattern, action)
              end
            end
          end
          router
        end

        if group
          named_routes(group, scope)
        else
          yield # routes do ... end
        end
      end

      #--------------------------------------------------------------------------
      def named_routes(group, scope = {})
        case group
        when :restful
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
        when :default
          router.default :any, "/:action/?:id?" => lambda { |params| params[:action] }
          router.default :any, "/" => :index
        end
      end
    end
  end
end
