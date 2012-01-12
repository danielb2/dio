require 'rubygems'
require 'awesome_print'

module Dio
  class Router
    attr_accessor :rules

    def initialize
      @rules ||= Hash.new { |hash, key| hash[key] = {} }
    end

    [:get, :post, :put, :delete].each do |method|
      define_method method do |key, value|
        @rules[method][key] = value
        # ap @rules
      end
    end

    def match(request, action)
      nil
    end
  end
end

# class TestController < Dio::Controller
#   # routes :restful, :except => :destroy
#   routes :restful, :only => [:index, :new]
# 
#   routes do
#     get "/list"            => :list
#     post "/cancel/:id"     => :cancel
#     # get    "/:self"      => :index
#     # get    "/:self/new"  => :new
#     # post   "/:self"      => :create
#     # get    "/:self/:id"  => :show
#     # get    "/:self/edit" => :edit
#     # put    "/:self/:id"  => :update
#     # delete "/:self/:id"  => :destroy
#   end
# end
