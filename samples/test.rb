class Test < Dio::Controller
  # routes :restful, :except => :destroy
  # routes :restful, :only => [:index, :new]

  before :say_hi, :only => :cancel

  routes do
    get "/:action/*/:id/*" => :index
    get "/list"          => :list
    get "/cancel/:id"    => :cancel
    any "/xexe"          => :xexe

    # get    "/"      => :index
    # get    "/new"   => :new
    # post   "/"      => :create
    # get    "/:id"   => :show
    # get    "/edit"  => :edit
    # put    "/:id"   => :update
    # delete "/:id"   => :destroy
  end

  def index
    puts "test/index"
    ap params
  end

  def list
    puts "test/list"
    ap params
  end

  def cancel
    puts "test/cancel"
    ap params
  end

  def dynamic
    puts "test/dynamic"
    ap params
  end

  private
  def say_hi
    puts "HI (CANCEL ONLY)"
  end
end
