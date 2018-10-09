require 'pg'

class DatabasePersistence

  def initialize(logger)
    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: 'todos')
    end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def all_lists
    sql = 'SELECT * FROM lists'
    result = query(sql)

    result.map do |tuple|
      list_id = tuple['id'].to_i
      todos = find_todos_for_list(list_id)

      { id: list_id,
        name: tuple['name'],
        todos: todos }
    end
  end

  def find_list(id)
    sql = 'SELECT * FROM LISTS WHERE id = $1'
    result = query(sql, id)

    tuple = result.first

    list_id = tuple['id'].to_i
    todos = find_todos_for_list(list_id)

    { id: list_id,
      name: tuple['name'],
      todos: todos }
  end

  def delete_list(id)
    sql = 'DELETE FROM lists WHERE id = $1'
    query(sql, id)
  end

  def create_new_list(list_name)
    sql = 'INSERT INTO lists (name) VALUES ($1)'
    query(sql, list_name)
  end

  def update_list_name(id, new_name)
    sql = 'UPDATE lists SET name = $1 WHERE id = $2'
    query(sql, new_name, id)
  end

  def add_todo_item(list_id, todo_text)
    sql = 'INSERT INTO todos (name, list_id) VALUES ($1, $2)'
    query(sql, todo_text, list_id)
  end

  def delete_todo_item(list_id, todo_id)
    sql = 'DELETE FROM todos WHERE id = $1 AND list_id = $2'
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, status)
    sql = 'UPDATE todos SET completed = $1 WHERE id = $2 AND list_id = $3'
    query(sql, status, todo_id, list_id)
  end

  def mark_all_todos_as_completed(list_id)
    sql = 'UPDATE todos SET completed = true WHERE list_id = $1'
    query(sql, list_id)
  end

  private

  def find_todos_for_list(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1"
    results = query(sql, list_id)
  
    results.map do |tuple|
      { id: tuple['id'].to_i,
        name: tuple['name'],
        completed: tuple['completed'] == 't' }
    end
  end
end