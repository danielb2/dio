class Test < Dio::Controller
  # routes :restful, :except => :destroy
  # routes :restful, :only => [:index, :new]

  routes do
    get "/list"            => :list
    post "/cancel/:id"     => :cancel
    # get    "/:self"      => :index
    # get    "/:self/new"  => :new
    # post   "/:self"      => :create
    # get    "/:self/:id"  => :show
    # get    "/:self/edit" => :edit
    # put    "/:self/:id"  => :update
    # delete "/:self/:id"  => :destroy
  end

  def list
    puts "test/list"
  end

  def cancel
    puts "test/cancel"
  end
end
