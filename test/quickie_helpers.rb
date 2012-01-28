require "net/http"
require "rack"
require "rack/lint"
require "thin"

class DioTest
  class TestApp < Dio::Base
    def get(path, headers = {})
      # uri = URI.parse("http://0.0.0.0:3131#{path}")
      # Net::HTTP.get_response(uri)
      Net::HTTP.start("0.0.0.0", 3131) do |http|
        request = Net::HTTP::Get.new(path, headers)
        http.request(request)
      end   
    end 

    def post(path, form_data = {}, headers = {})
      Net::HTTP.start("0.0.0.0", 3131) do |http|
        request = Net::HTTP::Post.new(path, headers)
        request.form_data = form_data
        http.request(request)
      end
    end
  end

  class Runner
    def self.start!(application, host = "0.0.0.0", port = 3131)
      dio = application.new

      Thread.new do
        Thin::Logging.silent = true
        Rack::Handler::Thin.run(Rack::Lint.new(dio), :Host => host, :Port => port) do |s|
          @server = s
        end 
      end 
      Thread.pass until @server && @server.running?

      dio
    end

    def self.stop!
      @server.stop if @server && @server.running?
    end
  end

  class Base
    @@app = Runner.start!(TestApp)

    def self.app
      @@app
    end

    def self.controller(contents, &block)
      controller = contents.match(/class\s+(\w+)\s*<\s*Dio/)[1]
      raise "Invalid controller class" unless controller
      begin
        file = File.expand_path(File.dirname(__FILE__)) << "/#{controller.downcase}.rb"
        File.open(file, "w") { |f| f.write(contents) }
        yield
      ensure
        File.unlink(file)
      end
    end
  end
end

at_exit { DioTest::Runner.stop! }
