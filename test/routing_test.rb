class RoutingTest < DioTest::Base
  controller %{
    class Ping < Dio::Controller
      def index
        @ping = 42
      end
    end
  } do
    response = app.get("/ping")
    response.code.should == "200"
    response.body.should == { :ping => 42 }.to_json
    response["Content-Type"].should == "application/json"
  end
end
