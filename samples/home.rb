class Home < Dio::Controller
  # routes :restful, :only => [ :index, :new ]

  # puts "invoking before_filter block"
  # before_filter do
  #   puts "  invoking post_action within before_filter block"
  #   # send(:post_action)
  #   puts "  done invoking post_action within before_filter block"
  # end
  # puts "done invoking before_filter block"

  def index
    @data = { :home => :index }
  end

  def new
    @data = { :home => :new }
    response.body = "home/new"
  end

  private
  def post_action
    puts "--- POST ACTION AFTER FILTER ---"
  end
end
