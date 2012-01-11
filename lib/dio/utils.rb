module Dio
  module Utils

    private
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
  end
end
    