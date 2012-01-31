# routes do
#   verb pattern => action
# end
#
# The +verb+ specifies HTTP method i.e. one of "get", "post", "put", "delete",
# or "any". The route +pattern+ is one of the following:
#
#   "/hello"                # Static string.
#   "/hello/:id"            # Required named parameters => params[:id]
#   "/hello/*/world/*"      # Required wildcard parameters => params[:wildcard]
#   "/hello.?:format?"      # Optional parameters => params[:format] if specified.
#   /\/hello\/([\w+])/      # Regular expression => params[:captures]
#
# The +action+ is either:
#
#  :method                  # Public controller method to invoke.
#  lambda { |params| ... }  # Block that accepts params and returns :method to invoke.
#
class RoutingTest < DioTest::Base
  #
  # Default route: any "/" => :index
  #------------------------------------------------------------------------
  controller %{
    class Post < Dio::Controller
      def index
        @post = params
      end
    end
  } do
    response = app.get("/post")
    response.code.should == "200"
    response.body.should == {
      :post => {
        :controller => :post
      }
    }.to_json
    response["Content-Type"].should == "application/json"
  end
  #
  # Deafult routes: any "/:action/?:id?.?:format?" => lambda { |params| params[:action] }
  #------------------------------------------------------------------------
  controller %{
    class Post < Dio::Controller
      def edit
        @post = params
      end
    end
  } do
    response = app.get("/post/edit")                 # /:action
    response.code.should == "200"
    response.body.should == {
      :post => {
        :controller => :post,
        :captures   => [ :edit, nil, nil ],
        :action     => :edit
      }
    }.to_json
    response["Content-Type"].should == "application/json"

    response = app.get("/post/edit/42")              # /:action/:id
    response.code.should == "200"
    response.body.should == {
      :post => {
        :controller => :post,
        :captures   => [ :edit, "42", nil ],
        :action     => :edit,
        :id         => "42"
      }
    }.to_json
    response["Content-Type"].should == "application/json"
  
    response = app.get("/post/edit/42.xml")          # /:action/:id.:format
    response.code.should == "200"
    response.body.should == {
      :post => {
        :controller => :post,
        :captures   => [ :edit, "42", "xml" ],
        :action     => :edit,
        :id         => "42",
        :format     => "xml"
      }
    }.to_json
    response["Content-Type"].should == "application/json"
  end
  #
  # Static string route.
  #------------------------------------------------------------------------
  controller %{
    class Post < Dio::Controller
      routes do
        any "/ping" => :ping
      end

      def ping
        @ping = params
      end
    end
  } do
    response = app.get("/post/ping")
    response.code.should == "200"
    response.body.should == {
      :ping => {
        :controller => :post
      }
    }.to_json
    response["Content-Type"].should == "application/json"
  end
  #
  # Required named parameters.
  #------------------------------------------------------------------------
  controller %{
    class Post < Dio::Controller
      routes do
        any "/ping/:name/:tag" => :ping
      end

      def ping
        @ping = params
      end
    end
  } do
    response = app.get("/post/ping/hello/world")
    response.code.should == "200"
    response.body.should == {
      :ping => {
        :controller => :post,
        :captures   => %w[ hello world ],
        :name       => "hello",
        :tag        => "world"
      }
    }.to_json
    response["Content-Type"].should == "application/json"
    #
    # Undeclared extra parameter - route not found.
    #
    response = app.get("/post/ping/hello/world/42")
    response.code.should == "404"
    response.body.should =~ /404 - Not Found/
    response["Content-Type"].should == "text/html"
    #
    # Missing :tag parameter - fall back to default /:action/:id rule.
    #
    response = app.get("/post/ping/hello")
    response.code.should == "200"
    response.body.should == {
      :ping => {
        :controller => :post,
        :captures   => [ "ping", "hello", nil ],
        :action     => "ping",
        :id         => "hello"
      }
    }.to_json
    response["Content-Type"].should == "application/json"
    #
    # Missing :name and :tag parameters - fall back to default /:action/:id rule.
    #
    response = app.get("/post/ping")
    response.code.should == "200"
    response.body.should == {
      :ping => {
        :controller => :post,
        :captures   => [ "ping", nil, nil ],
        :action     => "ping"
      }
    }.to_json
    response["Content-Type"].should == "application/json"
  end
  #
  # Required wildcard parameters.
  #------------------------------------------------------------------------
  controller %{
    class Post < Dio::Controller
      routes do
        any "/ping/*/*/:id" => :ping
      end

      def ping
        @ping = params
      end
    end
  } do
    response = app.get("/post/ping/hello/world/42")
    response.code.should == "200"
    response.body.should == {
      :ping => {
        :controller => :post,
        :captures   => %w[ hello world 42 ],
        :wildcard   => %w[ hello world ],
        :id         => "42"
      }
    }.to_json
    response["Content-Type"].should == "application/json"
  end
end
