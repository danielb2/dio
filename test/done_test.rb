# Copyright (c) 2012 Michael Dvorkin
#
# Quickie is freely distributable under the terms of MIT license.
# See LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
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
    response.html?.should == true
    response.body.should == ""
  end

  controller %{
    class Home < Dio::Controller
      def index
        done "X-Dio" => "rocks"
      end
    end
  } do
    response = app.get("/")
    response.code.should == "200"
    response.html?.should == true
    response.body.should == ""
    response["X-Dio"].should == "rocks"
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
    response.html?.should == true
    response.body.should == "index"
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
    response.html?.should == true
    response.body.should == "helloworld"
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
