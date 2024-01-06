require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'pry'
require 'pg'
require 'yaml'
require 'bcrypt'
require 'redcarpet'
require 'time'
require 'puma'

require_relative 'lib/database_persistence'
require_relative 'lib/view_helper_methods'
require_relative 'lib/route_helper_methods'

MAX_ITEMS_PER_PAGE = 5
MAX_TITLE_LENGTH = 100

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :server, :puma
  set :port, 8888
  set :erb, escape_html: true
  set :bind, '0.0.0.0'
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'lib/database_persistence.rb'
  also_reload 'lib/view_helper_methods.rb'
  also_reload 'lib/route_helper_methods.rb'
end

before do
  @storage = DatabasePersistence.new(logger)
end

after do
  @storage.disconnect
end

def local_base_path
  File.expand_path(__dir__)
end

#### ROUTES ####

## Index Page ##

get '/' do
  if user_signed_in?
    @all_posts = @storage.all_posts
    @num_pages = num_pages(@all_posts)

    require_valid_posts_page_number(params[:page], @num_pages) if params[:page]

    @curr_page = current_page_from_params(params[:page])
    @posts = select_page(@all_posts, @curr_page)
    erb :index
  else
    erb :signin
  end
end

## Search ##

# View search results
get '/search' do
  require_signed_in_user

  query = strip_spaces(params[:query])
  @all_posts = @storage.search_all_posts(query)
  @num_pages = num_pages(@all_posts)

  require_valid_posts_page_number(params[:page], @num_pages) if params[:page]

  session[:error] = "No posts found matching #{query}" if @all_posts.empty?

  @curr_page = current_page_from_params(params[:page])
  @posts = select_page(@all_posts, @curr_page)

  erb :index
end

#### POSTS ####

# Display new post form
get '/posts/new' do
  require_signed_in_user
  erb :new_post
end

# Create new post
post '/posts/new' do
  require_signed_in_user

  @content = strip_spaces(params[:post_content])
  @title = strip_spaces(params[:post_title])

  # validate input
  error = error_for_post_title_or_content(@title, @content)
  if error
    session[:error] = error
    status 422
    erb :new_post
  else
    user_id = current_user_id
    @storage.create_post(params[:post_title], params[:post_content], user_id)
    session[:success] = 'Post created'
    redirect '/'
  end
end

# View a single post
get '/posts/:post_id' do
  require_signed_in_user
  # Check that post_id is an integer and that the post exists
  require_valid_post_id

  post_id = params[:post_id].to_i
  @post = @storage.find_post_by_id(post_id)

  @all_comments = @storage.comments_for_post(post_id)
  @num_pages = num_pages(@all_comments)

  require_valid_single_post_page_number(params[:page], @num_pages) if params[:page]

  @curr_page = current_page_from_params(params[:page])
  @comments = select_page(@all_comments, @curr_page)

  erb :post
end

# Display edit post
get '/posts/:post_id/edit' do
  require_signed_in_user
  require_valid_post_id
  require_post_update_permissions('edit')

  post_id = params[:post_id].to_i

  @post = @storage.find_post_by_id(post_id)
  @comments = @storage.comments_for_post(post_id)

  erb :edit_post
end

# Update post content
post '/posts/:post_id/edit' do
  require_signed_in_user
  require_valid_post_id
  require_post_update_permissions('edit')

  post_id = params[:post_id].to_i
  @post = @storage.find_post_by_id(post_id)

  post_title = strip_spaces(params[:post_title])
  post_content = strip_spaces(params[:post_content])
  error = error_for_post_title_or_content(post_title, post_content)
  if error
    session[:error] = error
    status 422
    erb :edit_post
  else
    @storage.update_post(post_title, post_content, post_id)
    session[:success] = "Post updated"
    redirect "/posts/#{post_id}"
  end
end

# Delete post
post '/posts/:post_id/delete' do
  require_signed_in_user
  require_valid_post_id
  require_post_update_permissions('delete')

  post_id = params[:post_id].to_i
  @storage.delete_post(post_id)
  session[:success] = "Post deleted"
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    '/'
  else
    redirect '/'
  end
end

#### COMMENTS ####

# View a single comment
get '/posts/:post_id/comments/:comment_id' do
  require_signed_in_user
  require_valid_post_id_and_comment_id

  comment_id = params[:comment_id].to_i
  post_id = params[:post_id].to_i

  @comment = @storage.find_comment_by_id(comment_id)
  @post = @storage.find_post_by_id(post_id)

  erb :view_comment
end

# Create a new comment
post '/posts/:post_id/comments/new' do
  require_signed_in_user
  require_valid_post_id

  post_id = params[:post_id].to_i
  comment_content = strip_spaces(params[:comment_content])

  error = error_for_comment_content(comment_content)
  if error
    session[:error] = error
    status 422

    # All this to retain the original comment content
    @post = @storage.find_post_by_id(post_id)
    @all_comments = @storage.comments_for_post(post_id)
    @curr_page = current_page_from_params(params[:page])
    @comments = select_page(@all_comments, @curr_page)
    @num_pages = num_pages(@all_comments)

    erb :post
    # redirect "/posts/#{post_id}"
  else
    user_id = current_user_id
    @storage.create_comment(comment_content, post_id, user_id)
    session[:success] = "Comment created"
    redirect "/posts/#{post_id}"
  end
end

# Display edit comment
get '/posts/:post_id/comments/:comment_id/edit' do
  require_signed_in_user
  require_valid_post_id_and_comment_id
  require_comment_update_permissions('edit')

  comment_id = params[:comment_id].to_i
  post_id = params[:post_id].to_i
  @post = @storage.find_post_by_id(post_id)
  @comment = @storage.find_comment_by_id(comment_id)

  erb :edit_comment
end

# Update comment content
post '/posts/:post_id/comments/:comment_id/edit' do
  require_signed_in_user
  require_valid_post_id_and_comment_id
  require_comment_update_permissions('edit')

  comment_id = params[:comment_id].to_i
  post_id = params[:post_id].to_i
  @post = @storage.find_post_by_id(post_id)
  @comment = @storage.find_comment_by_id(comment_id)

  comment_content = strip_spaces(params[:comment_content])
  error = error_for_comment_content(comment_content)
  if error
    session[:error] = error
    status 422
    logger.info("error: #{error}")
    # Why does testing indicate a 302 redirect is happening here?
    erb :edit_comment
  else
    @storage.update_comment(comment_content, comment_id)
    session[:success] = "Comment updated"
    redirect "/posts/#{post_id}"
  end
end

# Delete comment
post '/posts/:post_id/comments/:comment_id/delete' do
  require_signed_in_user
  require_valid_post_id_and_comment_id
  require_comment_update_permissions('delete')

  comment_id = params[:comment_id].to_i
  post_id = params[:post_id].to_i
  @post = @storage.find_post_by_id(post_id)
  @comment = @storage.find_comment_by_id(comment_id)

  # Check user delete permission:
  if current_user_owns_comment_given_comment_id?(comment_id)
    @storage.delete_comment(comment_id)
    session[:success] = "Comment deleted"
    if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
      "/posts/#{post_id}"
    else
      redirect "/posts/#{post_id}"
    end
  else
    session[:error] = "You do not have permission to delete this comment"
    erb :post
  end
end

#### SIGNIN/SIGNOUT ####

# Display signin page
get '/users/signin' do
  erb :signin, layout: :layout_signin
end

# Handle signin request
post '/users/signin' do
  username = params[:username]
  password = params[:password]

  error = error_for_signin(username, password)
  if error
    @username = username
    session[:error] = error
    status 422
    erb :signin, layout: :layout_signin
  else
    session[:username] = username
    session[:success] = "Welcome #{username}"

    if session.key?(:after_signin_path)
      redirect to(session[:after_signin_path] + "?#{session[:after_signin_query_string]}")
    else
      redirect '/'
    end
  end
end

# Handle signout request
post '/users/signout' do
  session.delete(:username)
  session[:success] = "You have been signed out"
  redirect '/'
end

# Display signup page
get '/users/signup' do
  erb :signup
end

# Handle signup request
post '/users/signup' do
  username = strip_spaces(params[:username])
  first_name = strip_spaces(params[:first_name])
  last_name = strip_spaces(params[:last_name])
  password = strip_spaces(params[:password])
  password_confirmation = strip_spaces(params[:password_confirmation])

  error = error_for_signup( username,
                            first_name,
                            last_name,
                            password,
                            password_confirmation)

  if error
    session[:error] = error
    status 422
    @username = username
    @first_name = first_name
    @last_name = last_name
    erb :signup
  else
    encrypted_password = BCrypt::Password.create(password)
    @storage.create_user(username, first_name, last_name, encrypted_password)
    session[:username] = username
    session[:success] = "Welcome #{username}"
    redirect '/'
  end
end

#### USERS ####

# Display user profile
get '/users/:user_id' do
  require_signed_in_user
  # validate user_id
  require_valid_user_id
  require_no_search_query_on_user_profile_page

  @user_id = params[:user_id].to_i
  @all_posts = @storage.posts_for_user(@user_id)
  @num_pages = num_pages(@all_posts)
  # Validate page number
  require_valid_posts_page_number(params[:page], @num_pages) if params[:page]

  @user = @storage.find_user_by_id(@user_id)
  @curr_page = current_page_from_params(params[:page])
  @posts = select_page(@all_posts, @curr_page)

  erb :user
end
