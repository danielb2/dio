require "uri"

module Dio
  class Router
    attr_accessor :rules

    def initialize
      @rules = Hash.new { |hash, key| hash[key] = [] }
    end

    #--------------------------------------------------------------------------
    [ :get, :post, :put, :delete, :any ].each do |verb|
      define_method verb do |pattern, action|
        keys = []
        unless pattern.is_a?(Regexp)
          pattern = pattern.gsub(/:(\w+)|\*/) do  # Match all named parameters and '*'s.
            keys << ($1 || :wildcard)             # Save named parameter or :wildcard for '*' match.
            $1 ? "([^/?#]+)" : "(.+?)"            # Replace named parameter or '*' with appropriate matchers.
          end
          pattern = /^#{pattern}$/
        end
        @rules[verb] << { :pattern => pattern, :keys => keys, :action => action }
        ap '-------------------'
        ap @rules
        ap '-------------------'
      end
    end

    # Get an array of { :pattern, :keys, :action } hashes for given request
    # method, find matching pattern, update params keys, and return the action.
    #--------------------------------------------------------------------------
    def match(request, params)
      path = request.path_info.sub(/^\/\w+/, "")              # Remove controller part from the path.
      path = "/" if path.empty?                               # Remaining portion should at least be "/".
      rules = @rules[request.request_method.downcase.to_sym]  # Get the rules array for a given verb.
      rules += @rules[:any]                                   # Append the rules for any type of request.
      rules.each do |rule|
        if path =~ rule[:pattern]
          if $~.captures.any?
            captures = $~.captures.map { |c| URI.decode(c) if c }
            params.merge!(:captures => captures)
            rule[:keys].zip(captures) do |key, value|
              next unless value
              if key != :wildcard
                params[key.to_sym] = value
              else
                (params[key] ||= []) << value
              end
            end
          end
          return rule[:action]
        end
      end
      :not_found
    end
  end
end
