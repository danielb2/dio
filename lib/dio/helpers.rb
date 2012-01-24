module Dio
  module Helpers

    [ :status, :headers, :body ].each do |method|
      define_method method do |*value|                        # def status(*value)
        __send__(:"#{method}?", *value) unless value.empty?   #  status?(*value) unless value.empty?
        response.__send__(method)                             #  response.status
      end                                                     # end
    end

    private

    #--------------------------------------------------------------------------
    def status?(*value)
      return !!response.status if value.empty?

      return false unless value.first.is_a?(Fixnum)
      response.status = value.first
      true
    end

    #--------------------------------------------------------------------------
    def headers?(*value)
      return !!response.headers if value.empty?

      return false unless value.first.is_a?(Hash)
      if value.first.empty?
        response.headers.clear
      else
        value.first.each do |key, value|
          key = key.to_s.split('_').each { |x| x[0] = x[0].upcase }.join('-')
          response.headers[key] = value
        end
      end
      true
    end

    #--------------------------------------------------------------------------
    def body?(*value)
      return !!response.body if value.empty?

      if value.first.is_a?(String) || value.first.respond_to?(:each)
        response.body = *value.flatten
        true
      elsif value.first.is_a?(Proc)
        # TODO: define :each
        true
      else
        false
      end
    end

    #--------------------------------------------------------------------------
    def static?
      if request.get? || request.head?
        public_directory = File.expand_path(File.join(settings.root, "public"))
        static = File.expand_path(public_directory + URI.unescape(request.path_info))
        if File.file?(static) && File.readable?(static)
          environment["dio.static_file"] = static
        end
      end
      !!environment["dio.static_file"]
    end

    #--------------------------------------------------------------------------
    def constantize(str)
      camel_cased = str.to_s.downcase.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
      names = camel_cased.split('::')
      names.shift if names.empty? || names[0].empty?

      constant = Object
      names.each do |name|
        constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
      end
      constant
    end

    #--------------------------------------------------------------------------
    def universal_hash
      Hash.new { |hash, key| hash[key.to_s] if key.is_a?(Symbol) }
    end


    #--------------------------------------------------------------------------
    def universal_nested_hash(params)
      params = universal_hash.merge(params)
      params.each do |key, value|
        params[key] = universal_params(value) if value.is_a?(Hash)
      end
    end
  end
end
    