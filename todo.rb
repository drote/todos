require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'
require_relative 'database_persistence'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
  
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_persistence.rb'
end

before do
  @storage = DatabasePersistence.new(logger)
end

# Returns an error message if list name is invalid. Return nil otherwise.
def error_for_list_name(name, old_name = '')
  if @storage.all_lists.any? { |list| list[:name] == name && (name != old_name) }
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
def fetch_list(id)
  list = @storage.find_list(id)
  return list if list

  session[:error] = "The specified list could not be found"
  redirect '/lists'
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

  def lists_sorted(lists)
    lists.sort_by { |list| list_done?(list) ? 1 : 0 }
  end

  def todos_sorted(todos)
    todos.sort_by { |todo| todo[:completed] ? 1 : 0 }
  end
end


get '/' do
  redirect '/lists'
end

# View all lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists
end

# Render new list form
get '/lists/new' do
  erb :new_list
end

get '/lists/:list_id' do
  @list = fetch_list(params[:list_id].to_i)
  erb :list_page
end

get '/lists/:list_id/edit' do
  @list = fetch_list(params[:list_id].to_i)
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
    @storage.create_new_list(list_name)
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Update existing todo list
post '/lists/:list_id' do
  list_id = params[:list_id].to_i
  @list = fetch_list(list_id)
  new_name = params[:list_name].strip
  old_name = @list[:name]
  error = error_for_list_name(new_name, old_name)

  if error
    session[:error] = error
    erb :edit_list
  else
    @storage.update_list_name(list_id, new_name)

    unless new_name == old_name
      session[:success] = 'The list name been changed.'
    end

    redirect "/lists/#{list_id}"
  end
end

# Delete list
post '/lists/:list_id/delete' do
  list_id = params[:list_id].to_i
  list = fetch_list(list_id)
  deleted_list_name = list[:name]

  @storage.delete_list(list_id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    '/lists'
  else
    session[:success] = "#{deleted_list_name} has been succesfuly deleted"
    redirect '/lists'
  end
end

# Add new todo item
post '/lists/:list_id/todos' do
  list_id = params[:list_id].to_i
  @list = fetch_list(list_id)

  todo_text = params[:todo].strip
  error = error_for_todo(todo_text)

  if error
    session[:error] = error
    erb :list_page
  else
    @storage.add_todo_item(list_id, todo_text)
    session[:success] = 'Todo added succesfuly'

    redirect "/lists/#{list_id}"
  end
end

# Remove a todo item
post '/lists/:list_id/todos/:todo_id/delete' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i

  @storage.delete_todo_item(list_id, todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = 'Todo has been removed succesfuly'
    redirect "/lists/#{list_id}"
  end
end

post '/lists/:list_id/todos/:todo_id/mark' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'

  @storage.update_todo_status(list_id, todo_id, is_completed)

  session[:success] = 'Todo has been updated.'
  redirect "/lists/#{list_id}"
end

post '/lists/:list_id/complete_all' do
  list_id = params[:list_id].to_i

  @storage.mark_all_todos_as_completed(list_id)

  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{list_id}"
end
