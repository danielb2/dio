class Home < Dio::Controller
  # routes :restful, :only => [ :index, :new ]

  # puts "invoking before_filter block"
  # before_filter do
  #   puts "  invoking post_action within before_filter block"
  #   # send(:post_action)
  #   puts "  done invoking post_action within before_filter block"
  # end
  # puts "done invoking before_filter block"

  before :say_hello, :only => :index
  after :say_good_bye, :except => :index

  def index
    @data = { :home => :index }
  end

  def new
    @data = { :home => :new }
    response.body = "home/new"
  end

  def err
    puts "HAND-RAISING ERROR..."
    undefined_local_variable
  end

  private
  def say_hello
    puts "-> Hello"
  end

  def say_good_bye
    puts "-> Good Bye"
  end

  def post_action
    puts "--- POST ACTION AFTER FILTER ---"
  end
end
