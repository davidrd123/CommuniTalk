## Functions for use in routes


def local_db_path
  File.join(local_base_path, "db")
end

## Check which environment we're in
def development_env?
  ENV['RACK_ENV'] == 'development'
end

def test_env?
  ENV['RACK_ENV'] == 'test'
end

def test_or_dev?
  test_env? || development_env?
end

## Cleaning input
def strip_spaces(string)
  string.nil? ? '' : string.strip
end

## User Authentication
def load_user_credentials
  @storage.load_user_credentials
end

def user_exists?(username)
  credentials = load_user_credentials
  credentials.key?(username)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials
  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def user_signed_in?
  session[:username]
end

def current_user
  @storage.find_user_by_username(session[:username]) if user_signed_in?
end

def require_signed_in_user
  return if user_signed_in?

  session[:error] = 'You must be signed in to do that'
  session[:after_signin_query_string] = request.query_string
  session[:after_signin_path] = request.path
  redirect '/users/signin'
end

## Permissions Checks for User Edit/Delete
def require_post_update_permissions(update_type)
  return if current_user_owns_post_given_post_id?(params[:post_id].to_i)

  session[:error] = "You can only #{update_type} your own posts"
  redirect "/posts/#{params[:post_id]}"
end

def require_comment_update_permissions(update_type)
  return if current_user_owns_comment?(@storage.find_comment_by_id(params[:comment_id].to_i))

  session[:error] = "You can only #{update_type} your own comments"
  redirect "/posts/#{params[:post_id]}"
end

## Validation of user/post/comment ids
#  Checking if the id is of valid form
#  Then checking if the id exists in the database
def require_valid_user_id
  user_id_error = error_for_user_id(params[:user_id])
  return unless user_id_error

  session[:error] = user_id_error
  redirect '/'
end

def require_valid_post_id
  post_id_error = error_for_post_id(params[:post_id])
  return unless post_id_error

  session[:error] = post_id_error
  redirect '/'
end

def require_valid_post_id_and_comment_id
  error = error_for_post_id_and_comment_id(params[:post_id], params[:comment_id])
  return unless error

  session[:error] = error
  redirect "/posts/#{params[:post_id]}"
end

## Validation of page numbers for single post and posts index
def require_valid_single_post_page_number(params_page, num_pages)
  error = error_for_single_post_page_number(params_page, num_pages)
  return unless error

  session[:error] = error
  redirect "/posts/#{params[:post_id]}"
end

def require_valid_posts_page_number(params_page, num_pages)
  posts_page_error = error_for_posts_page_number(params_page, num_pages)
  return unless posts_page_error

  session[:error] = posts_page_error
  # Search 
  if params[:query]
    redirect "/search?query=#{params[:query]}"
  # User profile
  elsif params[:user_id]
    redirect "/users/#{params[:user_id]}"
  # Index
  else
    redirect '/'
  end
end

## Enforce no search query on user profile page
def require_no_search_query_on_user_profile_page
  return unless params[:query]

  session[:error] = 'You cannot search on a user profile page'
  redirect "/users/#{params[:user_id]}"
end

def current_user_id
  @storage.find_user_by_username(session[:username])[:id].to_i
end

### Post & Comment utility functions

def current_user_owns_post_given_post_id?(post_id)
  current_user = session[:username]
  owner_of_post = @storage.find_post_owner_username_by_post_id(post_id)
  current_user == owner_of_post
end

def current_user_owns_comment_given_comment_id?(comment_id)
  current_user = session[:username]
  owner_of_comment = @storage.find_comment_owner_username_by_comment_id(comment_id)
  current_user == owner_of_comment
end

def current_page_from_params(params_page)
  params_page ? params_page.to_i : 1
end

def select_page(collection, current_page)
  collection.slice((current_page - 1) * MAX_ITEMS_PER_PAGE, MAX_ITEMS_PER_PAGE)
end

def num_pages(collection)
  (collection.length / MAX_ITEMS_PER_PAGE.to_f).ceil
end

### Validation functions
def error_for_post_title_or_content(title, content)
  if title.nil? || title.empty?
    "Post title can't be blank"
  elsif title.length > MAX_TITLE_LENGTH
    "Post title can't be longer than #{MAX_TITLE_LENGTH} characters"
  elsif content.nil? || content.empty?
    "Post content can't be blank"
  end
end

def error_for_comment_content(content)
  return unless content.nil? || content.empty?

  "Comment content can't be blank"
end

def error_for_signup(username, first_name, _, password, password_confirmation)
  credentials = load_user_credentials
  if username.empty?
    "Username can't be blank"
  elsif username.length < 3
    'Username must be at least 3 characters'
  elsif username.length >= 20
    'Username must be no longer than 20 characters'
  elsif credentials.key?(username)
    'Username is already taken'
  elsif first_name.empty?
    "First name can't be blank"
  elsif password.empty?
    "Password can't be blank"
  elsif password.length < 3
    'Password must be at least 3 characters'
  elsif password != password_confirmation
    "Password confirmation doesn't match password"
  end
end

def error_for_signin(username, password)
  if username.empty?
    "Username can't be blank"
  elsif password.empty?
    "Password can't be blank"
  elsif !user_exists?(username)
    "User #{username} doesn't exist"
  elsif !valid_credentials?(username, password)
    'Invalid credentials'
  end
end

def error_for_posts_page_number(params_page, num_pages)
  requested_page_number_to_i = params_page.to_i

  if  params_page.to_i.to_s != params_page   ||
      requested_page_number_to_i < 1         ||
      requested_page_number_to_i > num_pages
    "That page doesn't exist"
  end
end

def error_for_single_post_page_number(params_page, num_pages)
  requested_page_number_to_i = params_page.to_i

  if params_page.to_i.to_s != params_page   ||
     requested_page_number_to_i < 1         ||
     requested_page_number_to_i > num_pages
    "That page doesn't exist"
  end
end

def error_for_post_id(post_id)
  return unless post_id.to_i.to_s != post_id || !@storage.post_exists?(post_id.to_i)

  "That post doesn't exist"
end

def error_for_user_id(user_id)
  return unless user_id.to_i.to_s != user_id || !@storage.user_exists?(user_id.to_i)

  "That user doesn't exist"
end

def error_for_post_id_and_comment_id(post_id, comment_id)
  post_id_error = error_for_post_id(post_id)
  if post_id_error
    post_id_error
  elsif comment_id.to_i.to_s != comment_id || !@storage.post_comment_combo_exists?(post_id, comment_id)
    "That comment doesn't exist"
  end
end
