require "uri"

module Dio
  class Router
    attr_accessor :rules

    def initialize
      reset!
    end

    def reset!
      @rules = Hash.new { |hash, key| hash[key] = [] }
    end

    #--------------------------------------------------------------------------
    [ :get, :post, :put, :delete, :any ].each do |verb|
      define_method verb do |pattern, action|
        keys = []
        unless pattern.is_a?(Regexp)                            # Use pattern as is if it's a regular expression.
          pattern = pattern.gsub(/:(\w+)|\*/) do                # Match all named parameters and '*'s.
            keys << ($1 || :wildcard)                           # Save named parameter or :wildcard for '*' match.
            $1 ? "([^/?#]+)" : "(.+?)"                          # Replace named parameter or '*' with appropriate matchers.
          end
          pattern = /^#{pattern}$/
        end
        #
        # Prepend a new rule so it gets evaluated first.
        #
        @rules[verb].unshift(:pattern => pattern, :keys => keys, :action => action)
      end
    end

    # Append a rule to the routing rules so it gets evaluated last.
    #--------------------------------------------------------------------------
    def default(verb, rule)
      pattern, action = rule.flatten
      __send__(verb, pattern, action)
      @rules[verb] << @rules[verb].shift
    end

    # Get an array of { :pattern, :keys, :action } hashes for given request
    # method, find matching pattern, update params keys, and return the action.
    #--------------------------------------------------------------------------
    def match(request, params)
ap @rules
      verb  = request.request_method.downcase.to_sym            # "GET" => :get
      rules = @rules[verb]                                      # Get the rules for the verb starting with the last rule.
      rules += @rules[:any]                                     # Append the rules for any type of request.

      path = request.path_info.sub(/^\/\w+/, "")                # Remove controller part from the path.
      path = "/" if path.empty?                                 # Remaining portion should at least be "/".

      route = rules.detect { |rule| path =~ rule[:pattern] }    # Find matching route if any.
      return :not_found unless route                            # Return :not_found (404) if no matching route is found.
      #
      #  Update params hash if rule pattern match produced captures.
      #
      if $~.captures.any?
        captures = $~.captures.map { |c| URI.decode(c) if c }
        params.merge!(:captures => captures)
        route[:keys].zip(captures) do |key, value|
          next unless value
          if key != :wildcard
            params[key.to_sym] = value
          else
            (params[key] ||= []) << value
          end
        end
      end
      #
      #  If the matching action is a lambda then call it passing params hash
      #  as parameter. Otherwise return its value (symbol).
      #
      if route[:action].is_a?(Proc)
        route[:action].call(params) || :not_found
      else
        route[:action]
      end
    end
  end
end
