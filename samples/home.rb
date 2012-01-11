class Home < Dio::Controller
  routes :restful, :only => :index

  def index
    @data = { :home => :index }
  end
end
