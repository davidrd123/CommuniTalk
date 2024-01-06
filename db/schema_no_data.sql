DROP TABLE if EXISTS comments;
DROP TABLE if EXISTS posts;
DROP TABLE if EXISTS users;

CREATE TABLE users (
  id serial PRIMARY KEY,
  username text NOT NULL,
  first_name text NOT NULL,
  last_name text,
  password text NOT NULL,
  created_at timestamp NOT NULL DEFAULT now()
);

CREATE TABLE posts (
  id serial PRIMARY KEY,
  title text NOT NULL,
  content text NOT NULL,
  user_id integer REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamp NOT NULL DEFAULT now()
);

CREATE TABLE comments (
  id serial PRIMARY KEY,
  content text NOT NULL,
  user_id integer REFERENCES users(id) ON DELETE CASCADE,
  post_id integer REFERENCES posts(id) ON DELETE CASCADE,
  created_at timestamp NOT NULL DEFAULT now()
);