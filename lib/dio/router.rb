require 'rubygems'
require 'awesome_print'

module Dio
  class Router
    attr_accessor :rules

    def initialize
      @rules ||= Hash.new { |hash, key| hash[key] = {} }
    end

    #--------------------------------------------------------------------------
    [:get, :post, :put, :delete].each do |method|
      define_method method do |key, value|
        @rules[method][key] = value
        # ap @rules
      end
    end

    #--------------------------------------------------------------------------
    def match(request, action)
      routing_table = @rules[request.request_method]
      routing_table.each do |path, method|
        # Causes undefined method `params='
        # request.params = { :controller => :test, :action => :cancel, :id => 123 }
        return method if path =~ /^\/#{action}/
      end
      nil
    end
  end
end
