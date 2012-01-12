class Home < Dio::Controller
  # routes :restful, :only => [ :index, :new ]

  def index
    @data = { :home => :index }
  end

  def new
    @data = { :home => :new }
  end
end
