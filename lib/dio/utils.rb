module Dio
  module Utils

    private

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
    