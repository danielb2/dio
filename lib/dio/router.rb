require 'rubygems'
require 'awesome_print'

module Dio
  class Router
    attr_accessor :rules

    def initialize
      @rules = Hash.new { |hash, key| hash[key] = [] }
    end

    #--------------------------------------------------------------------------
    [ :get, :post, :put, :delete ].each do |verb|
      define_method verb do |pattern, action|
        keys = []
        unless pattern.is_a?(Regexp)
          pattern = pattern.gsub(/:(\w+)|\*/) do  # Match all named parameters and '*'s.
            keys << ($1 || :wildcard)             # Save named parameter or :wildcard for '*' match.
            $1 ? "([^/?#]+)" : "(.+?)"            # Replace named parameter or '*' with appropriate matchers.
          end
          pattern = /^#{pattern}/
        end
        @rules[verb] << { :pattern => pattern, :keys => keys, :action => action }
        ap '-------------------'
        ap @rules
        ap '-------------------'
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
