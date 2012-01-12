class Test < Dio::Controller
  # routes :restful, :except => :destroy
  # routes :restful, :only => [:index, :new]

  routes do
    get "/index"           => :index
    get "/list"            => :list
    post "/cancel/:id"     => :cancel
    post "/restore/:id"    => :restore
    # get    "/:self"      => :index
    # get    "/:self/new"  => :new
    # post   "/:self"      => :create
    # get    "/:self/:id"  => :show
    # get    "/:self/edit" => :edit
    # put    "/:self/:id"  => :update
    # delete "/:self/:id"  => :destroy
  end

  def index
    puts "test/index"
  end

  def list
    puts "test/list"
  end

  def cancel
    puts "test/cancel"
  end

  def restore
    puts "test/restore"
  end
end
