ENV["RACK_ENV"] = "test"

require 'minitest/autorun'
require 'rack/test'
require 'minitest/reporters'
require 'pg'
require 'yaml'
require 'pry'
require 'logger'
Minitest::Reporters.use!

require_relative "../forum_app"


class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    @storage = DatabasePersistence.new
  end

  def teardown
    @storage.disconnect
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  # Viewing the homepage as a signed out user
  #  should show the sign in button and sign up link
  #  should not show "Signed in as"
  def test_view_homepage_as_signed_out_user
    get "/"
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input type="submit" value="Sign In"'
    assert_includes last_response.body, '<a id="signup" href="/users/signup">Sign Up</a>'
    refute_includes last_response.body, "Signed in as"
  end

  # Viewing the homepage as a signed in user
  #  should show the sign out button and the new post link
  def test_view_homepage_as_signed_in_user
    get "/", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input id="signout" type="submit" value="Sign Out"'
    assert_includes last_response.body, '<a href="/posts/new" class="new-post">New Post</a>'
    assert_includes last_response.body, "Signed in as admin"
    assert_includes last_response.body, "Is a 4K monitor better in 30"
  end

  # Attempting to view the first post, second page as a signed out user
  #  should redirect to the sign in page
  #  with an error message "You must be signed in to do that"
  # On signing in, the user should be redirected to the second page of the post they were trying to access
  def test_viewing_first_post_as_signed_out_user_then_sign_in
    path = "/posts/1"
    query_string = "page=2"

    full_path = path + "?" + query_string
    get full_path
    assert_equal 302, last_response.status

    # Check values stored in session
    assert_equal "You must be signed in to do that", session[:error]
    assert_equal full_path, "#{session[:after_signin_path]}?#{session[:after_signin_query_string]}"

    # Check that we're redirected to the sign in page
    assert_includes last_response.location.split("?")[0], "/users/signin"
    get last_response.location
    assert_includes last_response.body, '<input type="submit" value="Sign In"'
    assert_includes last_response.body, '<a id="signup" href="/users/signup">Sign Up</a>'

    # Sign in as admin
    post "/users/signin", { username: 'admin', password: 'whatsup' }
    assert_equal 302, last_response.status
    assert_equal "Welcome admin", session[:success]

    # Check that we're redirected to the first post, second page
    assert_includes last_response.location, full_path
    # assert_includes last_response.location.split("?")[1], query_string
    get last_response.location

    assert_includes last_response.body, "Welcome admin"
    assert_includes last_response.body, "Is a 4K monitor better in 30"

    # Check that the session variable for after sign in is cleared
    assert_nil session[:after_signin_path]
    assert_nil session[:after_signin_query_string]
  end

  # Attempting to view the new post page as a signed out user
  #  should redirect to the sign in page
  def test_viewing_new_post_as_signed_out_user
    get "/posts/new"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that", session[:error]
    assert_includes last_response.location.split('?')[0], "/users/signin"
    get last_response.location
    assert_includes last_response.body, '<input type="submit" value="Sign In"'
    assert_includes last_response.body, '<a id="signup" href="/users/signup">Sign Up</a>'
  end

  #### SIGN UP ####

  # Attempting to sign up with no username
  #  should retain the (absent) username and display an error message
  def test_signup_with_no_username
    post "/users/signup", { username: '', password: 'whatsup', password_confirmation: 'whatsup' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Username can't be blank"
    assert_includes last_response.body, 'value=""'
  end

  # Attempting to sign up with a username that is just spaces
  def test_signup_with_spaces_username
    post "/users/signup", { username: '   ', password: 'whatsup', password_confirmation: 'whatsup' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Username can't be blank"
  end

  # Attempting to sign up with a username that is too short
  #  should retain the username and display an error message
  def test_signup_with_short_username
    post "/users/signup", { username: 'ad', 
                            first_name: 'New',
                            last_name: 'User',
                            password: 'whatsup', 
                            password_confirmation: 'whatsup' 
                          }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Username must be at least 3 characters'
    assert_includes last_response.body, 'value="ad"'
  end

  # Attempting to sign up with a username that is too long
  #  should retain the username and display an error message
  def test_signup_with_long_username
    post "/users/signup", { username: 'thisusernameiswaytoolong', password: 'whatsup', password_confirmation: 'whatsup' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Username must be no longer than 20 characters'
    assert_includes last_response.body, 'value="thisusernameiswaytoolong"'
  end

  # Attempting to sign up with username that already exists
  #  should retain the username and display an error message
  def test_signup_with_existing_username
    post "/users/signup", { username: 'admin', password: 'whatsup', password_confirmation: 'whatsup' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Username is already taken'
    assert_includes last_response.body, 'value="admin"'
  end

  # Attempting to sign up with no password
  #  should retain the (absent) password and display an error message
  def test_signup_with_no_password
    post '/users/signup', { username: 'newuser',
                            first_name: 'New',
                            last_name: 'User',
                            password: '',
                            password_confirmation: ''
                          }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Password can't be blank"
    assert_includes last_response.body, 'input type="password" id="password" name="password" required'
  end

  # Attempting to sign up with a password containing only spaces
  def test_signup_with_spaces_password
    post '/users/signup', { username: 'newuser',
                            first_name: 'New',
                            last_name: 'User',
                            password: '   ',
                            password_confirmation: '   '
                          }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Password can't be blank"
  end

  # Attempting to sign up without a first name
  #  should retain the (absent) first name and display an error message
  def test_signup_without_first_name
    post '/users/signup', { username: 'newuser',
                            first_name: '',
                            last_name: 'User',
                            password: 'whatsup',
                            password_confirmation: 'whatsup'
                          }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "First name can't be blank"
    assert_includes last_response.body, 'id="first_name" value="" required'
  end

  # Attempting to sign up with a first name containing only spaces
  def test_signup_with_spaces_first_name
    post '/users/signup', { username: 'newuser',
                            first_name: '   ',
                            last_name: 'User',
                            password: 'whatsup',
                            password_confirmation: 'whatsup'
                          }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "First name can't be blank"
  end

  # Attempting to sign up with a password that is too short
  #  should blank the password and display an error message
  def test_signup_with_short_password
    post '/users/signup', { username: 'newuser', 
                            first_name: 'New',
                            last_name: 'User',
                            password: 'wh', 
                            password_confirmation: 'wh' 
                          }
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Password must be at least 3 characters'
  end

  # Attempting to sign up with a password confirmation that doesn't match the password
  #  should blank the password and display an error message
  def test_signup_with_nonmatching_password_confirmation
    post '/users/signup', { username: 'newuser', 
                            first_name: 'New',
                            last_name: 'User',
                            password: 'whatsup', 
                            password_confirmation: 'whatsup1' 
                          }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Password confirmation doesn't match password"
  end

  # Successful sign up
  def successful_signup
    post '/users/signup', { username: 'newuser',
                            first_name: 'New',
                            last_name: 'User',
                            password: 'whatsup',
                            password_confirmation: 'whatsup'
                          }
    assert_equal 302, last_response.status 
    assert_includes last_response.location, '/'
    get last_response.location
    assert_includes last_response.body, 'Welcome New User'
  end


  ### SIGN IN ###

  # Attempting to sign in with no username
  #  should retain the (absent) username and display an error message
  def test_signin_with_no_username
    post "/users/signin", { username: '', password: 'whatsup' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Username can't be blank"
    assert_includes last_response.body, 'id="username" value=""'
  end

  # Attempting to sign in with no password
  def test_signin_with_no_password
    post "/users/signin", { username: 'admin', password: '' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Password can't be blank"
  end

  # Attempting to sign in with an incorrect password
  def test_signin_with_incorrect_password
    post "/users/signin", { username: 'admin', password: 'whatsup1' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid credentials"
  end

  # Attempting to sign in with an nonexistent username
  def test_signin_with_nonexistent_username
    post "/users/signin", { username: 'nonexistent', password: 'whatsup' }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "User nonexistent doesn't exist"
  end

  # Successful sign in
  def test_successful_signin
    post "/users/signin", { username: 'admin', password: 'whatsup' }
    assert_equal 302, last_response.status
    get last_response.location
    assert_includes last_response.body, "Welcome admin"
  end

  #### SIGN OUT ####

  def test_signout
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal 302, last_response.status
    assert_equal "You have been signed out", session[:success]

    get last_response.location
    assert_includes last_response.body, "Sign In"
    assert_nil session[:username]
  end


  #### POSTS ##################################################################

  # Attempt to view an invalid page of index
  def test_view_invalid_page_0_of_index
    get "/?page=0", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That page doesn't exist", session[:error]
    assert_includes last_response.location.split('?')[0], "/"
    get last_response.location
    assert_includes last_response.body, "That page doesn't exist"
  end

  def test_view_invalid_page_100_of_index
    get "/?page=100", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That page doesn't exist", session[:error]
    assert_includes last_response.location.split('?')[0], "/"
  end

  def test_view_page_1_of_index
    get "/?page=1", {}, admin_session
    assert_equal 200, last_response.status
    assert_nil session[:error]
    assert_includes last_response.body, 'id="post-1"'
  end

  # Test viewing page 0 of post 1
  def test_view_page_0_of_post_1
    get "/posts/1?page=0", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That page doesn't exist", session[:error]
  end

  # Test viewing page 1 of post 1
  def test_view_page_1_of_post_1
    get "/posts/1?page=1", {}, admin_session
    assert_equal 200, last_response.status
    assert_nil session[:error]
  end

  # Test viewing page 100 of post 1
  def test_view_page_100_of_post_1
    get "/posts/1?page=100", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That page doesn't exist", session[:error]
  end

  # Test viewing page a of post 1
  def test_view_page_a_of_post_1
    get "/posts/1?page=a", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That page doesn't exist", session[:error]
  end

  #### VALIDATE POST ID ####
  def test_view_post_0
    get "/posts/0", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That post doesn't exist", session[:error]

    get last_response.location
    assert_includes last_response.body, "That post doesn't exist"
  end

  def test_view_post_100
    get "/posts/100", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That post doesn't exist", session[:error]

    get last_response.location
    assert_includes last_response.body, "That post doesn't exist"
  end

  def test_view_post_a
    get "/posts/a", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That post doesn't exist", session[:error]

    get last_response.location
    assert_includes last_response.body, "That post doesn't exist"
  end

  #### TEST CREATING A POST ####

  # Test creating a post with no title
  def test_create_post_with_no_title
    post "/posts/new", { post_title: "", post_content: "This is my post content" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Post title can't be blank"
  end

  # Test creating a post with spaces for title
  def test_create_post_with_spaces_for_title
    post "/posts/new", { post_title: "   ", post_content: "This is my post content" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Post title can't be blank"
  end

  # Test creating a post with a title that is too long
  def test_create_post_with_title_too_long
    post "/posts/new", { post_title: "a" * 101, post_content: "This is my post content" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Post title can't be longer than #{MAX_TITLE_LENGTH} characters"
  end

  # Test creating a post with no content
  def test_create_post_with_no_content
    post "/posts/new", { post_title: "This is my post title", post_content: "" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Post content can't be blank"
  end

  # Test creating a post with spaces for content
  def test_create_post_with_spaces_for_content
    post "/posts/new", { post_title: "This is my post title", post_content: "   " }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Post content can't be blank"
  end

  # Test creating a valid post
  def test_create_valid_post
    post "/posts/new", { post_title: "This is my post title", post_content: "This is my post content" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "Post created", session[:success]
  end

  #### TEST EDITING A POST ####

  # Can edit a post that exists and is owned by the user
  def test_edit_post_that_exists_and_is_owned_by_user
    post "/posts/1/edit", { post_title: "This is my post title lol", post_content: "This is my post content" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "Post updated", session[:success]
  end

  # Can't edit a post that doesn't exist
  def test_edit_post_that_doesnt_exist
    post "/posts/0/edit", { post_title: "This is my post title lol", post_content: "This is my post content" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "That post doesn't exist", session[:error]
  end

  # Can't view edit page for a post that doesn't exist
  def test_view_edit_post_that_doesnt_exist
    get "/posts/0/edit", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That post doesn't exist", session[:error]
  end

  # Can't edit a post that is not owned by the user
  def test_edit_post_that_is_not_owned_by_user
    post "/posts/2/edit", { post_title: "This is my post title lol", post_content: "This is my post content" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "You can only edit your own posts", session[:error]
  end

  # Can't edit a post with no title
  # Redisplay the form with the error message and previous values for title and content
  # Display the error message
  def test_edit_post_submit_with_no_title
    post "/posts/1/edit", { post_title: "", post_content: "This is my post content" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Post title can't be blank"
  end

  # Can't edit a post with spaces for title
  def test_edit_post_submit_with_spaces_for_title
    post "/posts/1/edit", { post_title: "   ", post_content: "This is my post content" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Post title can't be blank"
  end

  # Can't edit a post with spaces for content
  def test_edit_post_submit_with_spaces_for_content
    post "/posts/1/edit", { post_title: "This is my post title", post_content: "   " }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Post content can't be blank"
  end

  # Can't edit a post with no content
  # Redisplay the form with the error message and previous values for title and content
  # Display the error message
  def test_edit_post_submit_with_no_content
    post "/posts/1/edit", { post_title: "This is my post title lol", post_content: "" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Post content can't be blank"
  end


  ###### TEST DELETING A POST ####

  # Can delete a post that exists and is owned by the user
  def test_delete_post_that_exists_and_is_owned_by_user
    post "/posts/1/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "Post deleted", session[:success]
    assert_nil session[:error]
  end

  # Can't delete a post that doesn't exist
  def test_delete_post_that_doesnt_exist
    post "/posts/0/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That post doesn't exist", session[:error]
  end

  # Can't delete a post that is not owned by the user
  def test_delete_post_that_is_not_owned_by_user
    post "/posts/2/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "You can only delete your own posts", session[:error]
  end

  #### COMMENTS ###############################################################

  #### VALIDATE COMMENT ID ####
  def test_view_comment_0_post_1
    get "/posts/1/comments/0", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That comment doesn't exist", session[:error]

    assert_includes last_response.location, "/posts/1"
  end

  # Test nonexistent comment on post 1
  def test_view_comment_100_post_1
    get "/posts/1/comments/100", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That comment doesn't exist", session[:error]

    assert_includes last_response.location, "/posts/1"
  end

  # Test nonexistent noninteger comment on post 1
  def test_view_comment_a_post_1
    get "/posts/1/comments/a", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That comment doesn't exist", session[:error]

    assert_includes last_response.location, "/posts/1"
  end

  #### TEST CREATING A COMMENT ####

  # Test creating a comment for a post that doesn't exist
  def test_creating_comment_for_nonexistent_post
    post "/posts/0/comments/new", { comment_content: "This is my comment content" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "That post doesn't exist", session[:error]
  end

  # Test creating a comment with no content
  def test_creating_comment_with_no_content
    post "/posts/1/comments/new", { comment_content: "" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Comment content can't be blank"
  end

  # Test creating a valid comment
  def test_creating_valid_comment
    post "/posts/1/comments/new", { comment_content: "This is my comment content" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "Comment created", session[:success]
  end

  # Test creating a new comment on a post bumps its comment count and moves it to the top of the list
  # def test_creating_comment_bumps_comment_count
  #   post "/posts/17/comments/new", { comment_content: "This is my comment content" }, admin_session
  #   assert_equal 302, last_response.status
  #   assert_equal "Comment created", session[:success]
  #   get "/"

  #   assert_includes last_response.body, "Seventeenth Post"
  #   assert_includes last_response.body, '<td class="post-comments-count>1</td>'
  # end

  #### TEST EDITING A COMMENT ####

  ### GET ###
  # Can view edit form for a comment that exists and is owned by user
  def test_view_edit_form_for_comment_that_exists_and_is_owned_by_user
    get "/posts/1/comments/1/edit", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<textarea placeholder="Add a reply"'
  end

  # Can't view edit form for a comment that doesn't exist
  def test_view_edit_form_for_comment_that_doesnt_exist
    get "/posts/1/comments/0/edit", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That comment doesn't exist", session[:error]
  end

  # Can't view edit form for a comment that is not owned by the user
  def test_view_edit_form_for_comment_that_is_not_owned_by_user
    get "/posts/1/comments/2/edit", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "You can only edit your own comments", session[:error]
  end

  ### POST ###
  # Can edit a comment that exists and is owned by the user
  def test_edit_comment_that_exists_and_is_owned_by_user
    post "/posts/1/comments/1/edit", { comment_content: "This is my comment content" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "Comment updated", session[:success]
  end

  # Can't edit a comment that doesn't exist
  def test_edit_comment_that_doesnt_exist
    post "/posts/1/comments/0/edit", { comment_content: "This is my comment content" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "That comment doesn't exist", session[:error]
  end

  # Can't edit a comment that is not owned by the user
  def test_edit_comment_that_is_not_owned_by_user
    post "/posts/1/comments/2/edit", { comment_content: "This is my comment content" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "You can only edit your own comments", session[:error]
  end

  # Can't update a comment with no content
  def test_update_comment_with_no_content
    post "/posts/1/comments/1/edit", { comment_content: "" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Comment content can't be blank"
  end

  #### TEST DELETING A COMMENT ####
  # Can delete a comment that exists and is owned by the user
  def test_delete_comment_that_exists_and_is_owned_by_user
    post "/posts/1/comments/1/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "Comment deleted", session[:success]
    assert_nil session[:error]
  end

  # Can't delete a comment that doesn't exist
  def test_delete_comment_that_doesnt_exist
    post "/posts/1/comments/0/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That comment doesn't exist", session[:error]
  end

  # Can't delete a comment that is not owned by the user
  def test_delete_comment_that_is_not_owned_by_user
    post "/posts/1/comments/2/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "You can only delete your own comments", session[:error]
  end

  ### TEST VIEWING A USER PAGE ###
  # Can view a user page that exists
  def test_view_user_page_that_exists
    get "/users/1", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Admin User"
  end

  # Can't view a user page that doesn't exist
  def test_view_user_page_that_doesnt_exist
    get "/users/0", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "That user doesn't exist", session[:error]
  end

  # Can view second page of user profile
  def test_view_second_page_of_user_profile
    get "/users/1?page=2", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Admin User"
  end

  #### TEST SITE SEARCH ####
  # Can search for a term that returns a hit
  def test_search_for_term_that_exists_in_posts
    get "/search?query=4k", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Is a 4K monitor"
    assert_includes last_response.body, "Admin User"
    refute_includes last_response.body, "No posts found"
  end

  # Can search for a term that returns no hits
  def test_search_for_term_that_doesnt_exist_in_posts
    get "/search?query=asdf", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "No posts found matching asdf"
  end

  # Check that search results are paginated
  def test_search_results_are_paginated
    get "/search?query=post", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'href="/search?query=post&page=3"'
    get "/search?query=post&page=3", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Seventeenth Post'
  end

  # Check that adding a search query string on viewing a users page is discarded
  def test_search_query_string_is_discarded_on_user_page
    get "/users/1?query=post", {}, admin_session
    assert_equal 302, last_response.status
    get last_response.location, {}, admin_session
    assert_includes last_response.body, "You cannot search on a user profile page"
    assert_includes last_response.body, "Admin User"
  end
end