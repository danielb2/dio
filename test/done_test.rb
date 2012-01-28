class DoneTest < DioTest::Base
  # Test various combinations of Dio::Controller#done
  #
  # #done with single parameter:
  #   done 200
  #   done "X-key" => "value
  #   done "body text that is a string"
  #   done [ "body", "that", "responds", "to", ":each" ]
  #--------------------------------------------------------------------------
  controller %{
    class Home < Dio::Controller
      def index
        done 404
      end
    end
  } do
    response = app.get("/")
    response.code.should == "404"
    response.body.should == ""
    response["Content-Type"].should == "text/html"
  end

  controller %{
    class Home < Dio::Controller
      def index
        done "X-Key" => "value"
      end
    end
  } do
    response = app.get("/")
    response.code.should == "200"
    response.body.should == ""
    response["X-Key"].should == "value"
    response["Content-Type"].should == "text/html"
  end

  controller %{
    class Home < Dio::Controller
      def index
        done "index"
      end
    end
  } do
    response = app.get("/")
    response.code.should == "200"
    response.body.should == "index"
    response["Content-Type"].should == "text/html"
  end

  controller %{
    class Home < Dio::Controller
      def index
        done %w(hello world)
      end
    end
  } do
    response = app.get("/")
    response.code.should == "200"
    response.body.should == "helloworld"
    response["Content-Type"].should == "text/html"
  end

  # #done with two parameters:
  #   done 200, { "X-key" => "value }
  #   done "body text that is a string"
  #   done 200, [ "body", "that", "responds", "to", ":each" ]
  #--------------------------------------------------------------------------

  # #done with three parameters:
  #   done 200, { "X-key" => "value }, "body text that is a string"
  #   done 200, { "X-key" => "value }, [ "body", "that", "responds", "to", ":each" ]
  #--------------------------------------------------------------------------
end

DoneTest.new
