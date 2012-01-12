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
      routing_table = @rules[request.method]
      routing_table.each do |path, method|
        return method if path =~ /^\/#{action}/
      end
    end
  end
end
