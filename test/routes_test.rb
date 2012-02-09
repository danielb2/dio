# Copyright (c) 2012 Michael Dvorkin
#
# Quickie is freely distributable under the terms of MIT license.
# See LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
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
class RoutesTest < DioTest::Base
  app.set :default_format, :json
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
    response.json?.should == true
    response.body.should == {
      :post => {
        :controller => :post
      }
    }.to_json
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
    response.json?.should == true
    response.body.should == {
      :post => {
        :controller => :post,
        :captures   => [ :edit, nil, nil ],
        :action     => :edit
      }
    }.to_json

    response = app.get("/post/edit/42")              # /:action/:id
    response.code.should == "200"
    response.json?.should == true
    response.body.should == {
      :post => {
        :controller => :post,
        :captures   => [ :edit, "42", nil ],
        :action     => :edit,
        :id         => "42"
      }
    }.to_json
  
    response = app.get("/post/edit/42.json")          # /:action/:id.:format
    response.code.should == "200"
    response.json?.should == true
    response.body.should == {
      :post => {
        :controller => :post,
        :captures   => [ :edit, "42", "json" ],
        :action     => :edit,
        :id         => "42",
        :format     => "json"
      }
    }.to_json
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
    response.json?.should == true
    response.body.should == {
      :ping => {
        :controller => :post
      }
    }.to_json
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
    response.json?.should == true
    response.body.should == {
      :ping => {
        :controller => :post,
        :captures   => %w[ hello world ],
        :name       => "hello",
        :tag        => "world"
      }
    }.to_json
    #
    # Undeclared extra parameter - route not found.
    #
    response = app.get("/post/ping/hello/world/42")
    response.code.should == "404"
    response.html?.should == true
    response.body.should =~ /404 - Not Found/
    #
    # Missing :tag parameter - fall back to default /:action/:id rule.
    #
    response = app.get("/post/ping/hello")
    response.code.should == "200"
    response.json?.should == true
    response.body.should == {
      :ping => {
        :controller => :post,
        :captures   => [ "ping", "hello", nil ],
        :action     => "ping",
        :id         => "hello"
      }
    }.to_json
    #
    # Missing :name and :tag parameters - fall back to default /:action/:id rule.
    #
    response = app.get("/post/ping")
    response.code.should == "200"
    response.json?.should == true
    response.body.should == {
      :ping => {
        :controller => :post,
        :captures   => [ "ping", nil, nil ],
        :action     => "ping"
      }
    }.to_json
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
    response.json?.should == true
    response.body.should == {
      :ping => {
        :controller => :post,
        :captures   => %w[ hello world 42 ],
        :wildcard   => %w[ hello world ],
        :id         => "42"
      }
    }.to_json
    #
    # Missing wildcard items - fall back to default /:action/:id rule.
    #
    response = app.get("/post/ping")
    response.code.should == "200"
    response.json?.should == true
    response.body.should == {
      :ping => {
        :controller => :post,
        :captures   => [ "ping", nil, nil ],
        :action     => "ping"
      }
    }.to_json
  end
  #
  # Optional parameters.
  #------------------------------------------------------------------------
  controller %{
    class Post < Dio::Controller
      routes do
        any "/ping/:id/:name?.?:ext?" => :ping
      end

      def ping
        @ping = params
      end
    end
  } do
    response = app.get("/post/ping/42/restart.txt")
    response.code.should == "200"
    response.json?.should == false
    response.body.should == ""
    #
    # Missing optional parameter.
    #
    response = app.get("/post/ping/42/restart")
    response.code.should == "200"
    response.json?.should == true
    response.body.should == {
      :ping => {
        :controller => :post,
        :captures   => [ "42", "restart", nil ],
        :id         => "42",
        :name       => "restart"
      }
    }.to_json
  end
end
