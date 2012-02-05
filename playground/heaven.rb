class Heaven < Dio::Controller
  # routes :restful, :except => :destroy
  routes :restful, :except => [ :index, :new ] do
    get "/:action/*/:id/*" => :index
    get "/list"            => :list
    get "/cancel/:id"      => :cancel
    get "/hi"              => :hi
  end

  after :only => :index do |controller|
    puts "--- BYE (INDEX ONLY) ---"
    puts controller.response.inspect
  end

  before :earn, :only => :hi

  # routes do
  #   get "/:action/*/:id/*" => :index
  #   get "/list"          => :list
  #   get "/cancel/:id"    => :cancel
  #   any "/xexe"          => :xexe
  # 
  #   # get    "/"      => :index
  #   # get    "/new"   => :new
  #   # post   "/"      => :create
  #   # get    "/:id"   => :show
  #   # get    "/edit"  => :edit
  #   # put    "/:id"   => :update
  #   # delete "/:id"   => :destroy
  # end

  def index
    puts "test/index"
    ap params
    done 404
  end

  def list
    puts "test/list"
    ap params
    done 200, "test/list"
  end

  def cancel
    puts "test/cancel"
    ap params
    done "test/cancel"
  end

  def hi
    @name = ("a".."z").to_a.shuffle[0,8].join.capitalize
  end

  def dynamic
    puts "test/dynamic"
    ap params
    done 404, { "Content-Type" => "text/txt" }, "test/dynamic"
  end

  def dynamiq
    puts "test/dynamic"
    ap params
    done 404, { "Content-Type" => "text/json" }
  end

  private
  def earn
    puts "earh (/hi only)"
    @rand = rand(1_000_000)
  end
end
