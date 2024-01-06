# CommuniTalk

This application provides a forum for users to make posts and to comment on each other's posts.

## Installation

Unzip the archive, change into the root directory and run the following command to make the shell files executable:

```bash
chmod +x *.sh
```

(alternately the shell files can be run without making them executable via `sh <filename>.sh` )

## Configuration

The application can be installed on a POSIX-compliant system (Linux, Mac OS X, etc.) by running `./setup/setup.sh forum`, which will `bundle install` the necessary gems, create the `forum` PostgreSQL database, and then seed the database with some sample data.

**NOTE**: If you wanted to configure the application to start with no users, comments, or posts, you could run `./setup/setup_empty.sh forum` instead.

## Running tests

To set up the database for testing, run `./setup/setup.sh forum_test`. This will create a `forum_test` PostgreSQL database, and seed it with some sample data.

Then tests can be run with `./test.sh`.

## Running the Application

- The application can be run with `./run.sh` (or `bundle exec ruby forum_app.rb`)
- The application runs on port `8889` and listens on all interfaces.
- All users have the password `whatsup`, the recommended user is `admin`.
- Navigate back to the home page by clicking the "Online Forum" link at the top-left of the page.

# Design Choices

## Navigate to Home

The homepage can be reached by clicking on a simple "Online Forum" link in the upper left corner of the page. This could be styled better in the future.

## Signed in As / Sign Out

The current user who is signed in + a "Sign Out" button is displayed in the lower left corner of the page. In the future, this could be moved into the upper right corner of the page.

## Sign Up

The 'signup' page is displayed if the user is not logged in and clicks the "Sign Up" button on the index page where they are prompted to sign in. Currently this page will display errors if the user tries to use an existing username, their username is too short or too long, etc., but it would be better to have these guidelines displayed on the page.

## Update Permissions

The application only allows users to update or delete their own posts and comments, so the "edit" and "delete" buttons appear only on posts or comments where the current user has that permission. Admin functionality was not implemented.

## Sorting

### Posts

The posts are sorted in descending order by: last comment time, or if there are no comments, the time the post was created. This allows the most recent posts to be displayed first.

### Comments

The comments are sorted in ascending order by the time they were created. This allows the reader to follow the chronological order of the comments, which makes sense if people are replying to previous comments.

## Replying to a Post

On a post page, the user can click "Reply" on the post or any of the comments and this will scroll the page down to the reply form. I kept the reply form integrated with the post page instead of having a separate page for it so that the user could still scroll up and reference what they were replying to.


## User Pages

I added a user page which allows one to view the posts the user has made, this is viewable at `/users/:user_id`. Comments the user has made do not appear here, that would perhaps be something to add in the future.

## N+1 queries

I was having issues with the application making two queries per user per post when loading the index page. This is because (1) the index page loads all of the posts which contain a nested user object that is looked up, and (2) for each post it fetches the user who made the post to extract their initials and display with the post title. So `DatabasePersistence#find_user_by_id` was being called twice for each post and this was initiating a `SELECT * FROM users WHERE id = ?` query for each post. 

I dealt with this by caching the users in a `@users` hash, which is a hash mapping user id to user hash objects, and then looking up the user in the hash when needed.

Similarly when retrieving all posts, I used a `COUNT` subquery to count the number of comments for each post and stored that as a value in the `comment_count` field of the post hash.

## Search

Search as implemented only searches the title and body of the posts. It does not search the comments. 

# Future Work

## Admin User Functionality

I have a user with id 1 and username admin, but currently there's no functionality implemented for this user to have admin privileges. In theory the admin should have an interface where the edit or delete buttons are present for all posts and comments.

## Markdown Support in Posts and Comments

I had wanted to allow the users of the application to enter markdown text for their posts and comments, but I decided to go with plain text. This is because of the requirement to not use any additional Rubygems if they provide the application-specific requirements.

Right now I'm using `Rack::Utils.escape_html` to escape any user input by default when I'm outputting with `<%=` in my erb view templates (since I set `:erb` to `{:escape_html => true}` in the `configure` block). If I could use an additional gem instead of `escape_html` I would have layered the `sanitize` gem on top of markdown to html output (through the `Redcarpet` gem), because that would allow me to whitelist the html tags which would come out of the markdown parser and to still meet the requirement of preventing JavaScript injection.

## Post and Comment Likes

It would have been nice to have given users the ability to like posts and comments, but this would have required setting up a many-to-many relationship between posts, comments and the users who liked them, and ensuring only one like per user per post or comment. This seemed to exceed the requirements of the project and to introduce excessive complexity.