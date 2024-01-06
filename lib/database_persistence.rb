require "pg"

class DatabasePersistence
  def initialize(logger = nil)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          elsif ENV['RACK_ENV'] == 'test'
            PG.connect(dbname: "forum_test")
          else
            PG.connect(dbname: "forum")
          end
    if ENV['RACK_ENV'] == 'test'
      sql = File.open(File.join(local_db_path, "schema.sql")).read
      @db.exec(sql)
    end

    @logger = logger unless ENV['RACK_ENV'] == 'test'
    @users = {}
    load_users_to_memory
  end

  def disconnect
    @db.close
  end

  def query(sql, *params)
    @logger&.info "#{sql} #{params}"
    @db.exec_params(sql, params)
  end

  def all_users
    sql = "SELECT * FROM users"
    result = query(sql)
    result.map do |tuple|
      {
        id: tuple["id"].to_i,
        first_name: result.first["first_name"],
        last_name: result.first["last_name"],
        username: tuple["username"],
        password: tuple["password"]
      }
    end
  end

  def load_user_credentials
    users = all_users
    credentials = {}
    users.each do |user|
      credentials[user[:username]] = user[:password]
    end
    credentials
  end

  def load_users_to_memory
    sql = "SELECT * FROM users"
    result = query(sql)
    result.each do |tuple|
      @users[tuple["id"].to_i] = {
        id: tuple["id"].to_i,
        first_name: tuple["first_name"],
        last_name: tuple["last_name"],
        username: tuple["username"]
      }
    end
  end

  def find_user_by_id(id)
    return @users[id] if @users && @users[id]

    puts "UNCACHED USER ********************************************************"
    # Looks like can remove this
    sql = "SELECT * FROM users WHERE id = $1"
    result = query(sql, id)
    @users[id] = {
      id: result.first["id"].to_i,
      first_name: result.first["first_name"],
      last_name: result.first["last_name"],
      username: result.first["username"],
    }
  end

  def find_user_by_username(username)
    sql = "SELECT * FROM users WHERE username = $1"
    result = query(sql, username)
    {
      id: result.first["id"].to_i,
      first_name: result.first["first_name"],
      last_name: result.first["last_name"],
      username: result.first["username"],
    }
  end

  def create_user(username, first_name, last_name, password)
    sql = "INSERT INTO users (username, first_name, last_name, password) VALUES ($1, $2, $3, $4)"
    query(sql, username, first_name, last_name, password)
  end

  ### HELPER METHODS ###

  def most_recent_activity_on_post_for_sort(post)
    post_created_at = Time.parse(post[:created_at])
    last_comment_activity = Time.parse(post[:last_comment_activity])
    [last_comment_activity, post_created_at].max
    # if last_comment_activity > post_created_at
    #   last_comment_activity
    # else
    #   post_created_at
    # end
  end

  def format_posts_tuple(tuple)
    {
      id: tuple["id"].to_i,
      title: tuple["title"],
      content: tuple["content"],
      user: find_user_by_id(tuple["user_id"].to_i),
      created_at: tuple["created_at"],
      last_comment_activity: tuple["last_comment_activity"],
      comment_count: tuple["comment_count"]
    }
  end

  def sort_posts_by_most_recent_activity(posts)
    posts.sort_by { |post| [most_recent_activity_on_post_for_sort(post)] }.reverse
  end

  def all_posts
    sql = <<-SQL
    SELECT p.*,
      (SELECT CASE WHEN MAX(c.created_at) IS NULL THEN to_timestamp(0) ELSE MAX(c.created_at) END
       FROM comments c WHERE c.post_id = p.id) as last_comment_activity,
      (SELECT COUNT(c.id) FROM comments c WHERE c.post_id = p.id) AS comment_count
    FROM posts p
    SQL

    result = query(sql)
    sort_posts_by_most_recent_activity(result.map(&method(:format_posts_tuple)))
  end

  def search_all_posts(query)
    sql = <<-SQL
    SELECT p.*,
      (SELECT CASE WHEN MAX(c.created_at) IS NULL THEN to_timestamp(0) ELSE MAX(c.created_at) END
       FROM comments c WHERE c.post_id = p.id) as last_comment_activity,
      (SELECT COUNT(c.id) FROM comments c WHERE c.post_id = p.id) AS comment_count
    FROM posts p
    WHERE p.title ILIKE $1 OR p.content ILIKE $1;
    SQL

    result = query(sql, "%#{query}%")
    sort_posts_by_most_recent_activity(result.map(&method(:format_posts_tuple)))
  end

  def posts_for_user(user_id)
    sql = <<-SQL
    SELECT p.*,
      (SELECT CASE WHEN MAX(c.created_at) IS NULL THEN to_timestamp(0) ELSE MAX(c.created_at) END
       FROM comments c WHERE c.post_id = p.id) as last_comment_activity,
      (SELECT COUNT(c.id) FROM comments c WHERE c.post_id = p.id) AS comment_count
    FROM posts p
    INNER JOIN users u
    ON p.user_id = u.id
    WHERE u.id = $1;
    SQL

    result = query(sql, user_id)
    sort_posts_by_most_recent_activity(result.map(&method(:format_posts_tuple)))
  end

  def user_exists?(user_id)
    sql = "SELECT * FROM users WHERE id = $1"
    result = query(sql, user_id)
    result.any?
  end

  def post_exists?(post_id)
    sql = "SELECT * FROM posts WHERE id = $1"
    result = query(sql, post_id)
    result.any?
  end

  def post_comment_combo_exists?(post_id, comment_id)
    sql = "SELECT * FROM posts INNER JOIN comments on posts.id = comments.post_id WHERE posts.id = $1 AND comments.id = $2"
    result = query(sql, post_id, comment_id)
    result.any?
  end

  def find_post_by_id(id)
    sql = "SELECT * FROM posts WHERE id = $1"
    result = query(sql, id)
    tuple = result.first
    {
      id: tuple["id"].to_i,
      title: tuple["title"],
      content: tuple["content"],
      user: find_user_by_id(tuple["user_id"].to_i),
      created_at: tuple["created_at"]
    }
  end

  # def find_num_posts
  #   sql = "SELECT COUNT(*) FROM posts"
  #   result = query(sql)
  #   result.first["count"].to_i
  # end

  # def find_num_comments_on_post(post_id)
  #   sql = "SELECT COUNT(*) FROM comments WHERE post_id = $1"
  #   result = query(sql, post_id)
  #   result.first["count"].to_i
  # end 

  def find_post_owner_username_by_post_id(id)
    sql = "SELECT username FROM users INNER JOIN posts ON users.id = posts.user_id WHERE posts.id = $1"
    result = query(sql, id)
    tuple = result.first
    tuple["username"]
  end

  def create_post(title, content, user_id)
    sql = "INSERT INTO posts (title, content, user_id) VALUES ($1, $2, $3)"
    query(sql, title, content, user_id)
  end

  def update_post(title, content, post_id)
    sql = "UPDATE posts SET title = $1, content = $2 WHERE id = $3"
    query(sql, title, content, post_id)
  end

  def delete_post(post_id)
    sql = "DELETE FROM posts WHERE id = $1"
    query(sql, post_id)
  end

  def comments_for_post(id)
    sql = "SELECT * FROM comments WHERE post_id = $1 ORDER BY created_at ASC"
    result = query(sql, id)
    result.map do |tuple|
      {
        id: tuple["id"].to_i,
        content: tuple["content"],
        user: find_user_by_id(tuple["user_id"].to_i),
        created_at: tuple["created_at"]
      }
    end
  end

  def find_comment_owner_username_by_comment_id(id)
    sql = "SELECT username FROM users INNER JOIN comments ON users.id = comments.user_id WHERE comments.id = $1"
    result = query(sql, id)
    tuple = result.first
    tuple["username"]
  end

  def find_comment_by_id(id)
    sql = "SELECT * FROM comments WHERE id = $1"
    result = query(sql, id)
    tuple = result.first
    {
      id: tuple["id"].to_i,
      content: tuple["content"],
      user: find_user_by_id(tuple["user_id"].to_i),
      created_at: tuple["created_at"]
    }
  end

  def create_comment(content, post_id, user_id)
    sql = "INSERT INTO comments (content, post_id, user_id) VALUES ($1, $2, $3)"
    query(sql, content, post_id, user_id)
  end

  def update_comment(content, comment_id)
    sql = "UPDATE comments SET content = $1 WHERE id = $2"
    query(sql, content, comment_id)
  end

  def delete_comment(comment_id)
    sql = "DELETE FROM comments WHERE id = $1"
    query(sql, comment_id)
  end
end