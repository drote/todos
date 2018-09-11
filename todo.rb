require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

# Returns an error message if list name is invalid. Return nil otherwise.
def error_for_list_name(name, old_name = '')
  if session[:lists].any? { |list| list[:name] == name && (name != old_name) }
    'The list name must be unique.'
  elsif !name.size.between?(1, 100)
    'The list name must be between 1-100 characters.'
  end
end

# Returns an error message if todo name is invalid. Return nil otherwise.
def error_for_todo(name)
  'Todo must be between 1-100 characters.' unless name.size.between?(1, 100)
end

# Returns the list object and the list number.
def get_list_and_list_num(list_param)
  list_number = list_param.to_i
  list = session[:lists][list_number]
  [list, list_number]
end

# Return the todo object and the todo number.
def get_todo_and_todo_num(list, todo_param)
  todo_number = todo_param.to_i
  todo = list[:todos][todo_number]
  [todo, todo_number]
end

def list_done?(list)
  remaining_todos_count(list).zero? && todos_count(list) > 0
end

helpers do
  def list_class(list)
    'complete' if list_done?(list)
  end

  def todo_class(todo)
    'complete' if todo[:completed]
  end

  def remaining_todos_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def todos_count(list)
    list[:todos].size
  end

  def each_list_sorted_with_index(lists)
    lists.sort_by { |list| list_done?(list) ? 1 : 0 }.each do |list|
      yield(list, session[:lists].index(list))
    end
  end

  def each_todo_sorted_with_index(todos)
    todos.sort_by { |todo| todo[:completed] ? 1 : 0 }.each do |todo|
      yield(todo, todos.index(todo))
    end
  end
end

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View all lists
get '/lists' do
  @lists = session[:lists]
  erb :lists
end

# Render new list form
get '/lists/new' do
  erb :new_list
end

get '/lists/:list_number' do
  @list, @list_number = get_list_and_list_num(params[:list_number])
  erb :list_page
end

get '/lists/:list_number/edit' do
  @list, @list_number = get_list_and_list_num(params[:list_number])
  erb :edit_list
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Update existing todo list
post '/lists/:list_number' do
  list, list_number = get_list_and_list_num(params[:list_number])
  list_name = params[:list_name].strip
  old_name = session[:lists][list_number][:name]
  error = error_for_list_name(list_name, old_name)

  if error
    session[:error] = error
    erb :edit_list
  else
    list[:name] = list_name
    unless list_name == old_name
      session[:success] = 'The list name been changed.'
    end

    redirect "/lists/#{list_number}"
  end
end

# Delete list
post '/lists/:list_number/delete' do
  _, list_number = get_list_and_list_num(params[:list_number])
  list_name = session[:lists].delete_at(list_number)[:name]
  session[:success] = "#{list_name} has been succesfuly deleted"

  redirect '/lists'
end

# Add new todo item
post '/lists/:list_number/todos' do
  list, list_number = get_list_and_list_num(params[:list_number])
  todo_text = params[:todo].strip
  error = error_for_todo(todo_text)

  if error
    session[:error] = error
    erb :list_page
  else
    list[:todos] << { name: todo_text, completed: false }
    session[:success] = 'Todo added succesfuly'

    redirect "/lists/#{list_number}"
  end
end

# Remove a todo item
post '/lists/:list_number/todos/:todo_number/delete' do
  list, list_number = get_list_and_list_num(params[:list_number])
  _, todo_number = get_todo_and_todo_num(list, params[:todo_number])

  list[:todos].delete_at(todo_number)
  session[:success] = 'Todo has been removed succesfuly'

  redirect "/lists/#{list_number}"
end

post '/lists/:list_number/todos/:todo_number/mark' do
  list, list_number = get_list_and_list_num(params[:list_number])
  todo, = get_todo_and_todo_num(list, params[:todo_number])

  todo[:completed] = (params[:completed] == 'true')
  session[:success] = 'Todo has been updated.'

  redirect "/lists/#{list_number}"
end

post '/lists/:list_number/complete_all' do
  list, list_number = get_list_and_list_num(params[:list_number])

  list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = 'All todos have been completed.'

  redirect "/lists/#{list_number}"
end
