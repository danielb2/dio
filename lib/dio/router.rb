require 'rubygems'
require 'awesome_print'

module Dio
  class Router
    # attr_reader :routing_rules

    def initialize
      @@rules ||= Hash.new { |hash, key| hash[key] = {} }
    end

    [:get, :post, :put, :delete].each do |method|
      define_method method do |key, value|
        @@rules[method][key] = value
        ap @@rules
      end
    end
  end
end

# routes :restful, :except => :delete
# routes :restful, :only => [:index, :new]
#
module Dio
  class Controller

    def self.routes(group = nil, scope = {}, &block)
      @router ||= begin
        router = Dio::Router.new
        self.class.instance_eval do
          [ :get, :post, :put, :delete ].each do |method|
            define_method method do |rule|
              key, value = rule.to_a.flatten
              name = self.name.sub("Controller", "").downcase
              router.__send__(method, key.sub(":self", name), value)
            end
          end
        end
      end

      yield if block_given?

      if group == :restful
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

    private
    def self.named(group, *args)
      puts "named: #{group}, #{args.inspect}"
    end

    def self.anonymous(&block)

      yield if block_given?
    end
  end
end

class TestController < Dio::Controller
  # routes :restful, :except => :destroy
  routes :restful, :only => [:index, :new]

  routes do
    get "/list"            => :list
    post "/cancel/:id"     => :cancel
    # get    "/:self"      => :index
    # get    "/:self/new"  => :new
    # post   "/:self"      => :create
    # get    "/:self/:id"  => :show
    # get    "/:self/edit" => :edit
    # put    "/:self/:id"  => :update
    # delete "/:self/:id"  => :destroy
  end
end
