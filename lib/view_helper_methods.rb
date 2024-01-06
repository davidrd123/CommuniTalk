helpers do
  # def h(content)
  #   Rack::Utils.escape_html(content)
  # end

  # def m(content)
  #   markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, filter_html: true)
  #   markdown.render(h(content))
  # end

  def current_user_owns_comment?(comment)
    comment[:user][:username] == session[:username]
  end

  def current_user_owns_post?(post)
    post[:user][:username] == session[:username]
  end

  def clear_after_signin_session_variables
    session.delete(:after_signin_path)
    session.delete(:after_signin_query_string)
  end

  def user_initials(user_id)
    user = @storage.find_user_by_id(user_id)
    if user[:first_name] && user[:last_name]
      "#{user[:first_name][0]}#{user.fetch(:last_name, '')[0]}"
    else
      user[:first_name][0]
    end
  end

  # def num_comments_on_post(post_id)
  #   @storage.find_num_comments_on_post(post_id)
  # end

  def latest_activity_on_post(post)
    post_created_at = Time.parse(post[:created_at])
    last_comment_activity = Time.parse(post[:last_comment_activity])
    if last_comment_activity > post_created_at
      convert_timestamp(last_comment_activity)
    else
      convert_timestamp(post_created_at)
    end
  end

  def latest_activity_on_comment(comment)
    convert_timestamp(Time.parse(comment[:created_at]))
  end

  # Convert timestamp to a human-readable amount of time ago
  # For less than 1 min -> sec, 1 hour -> min, 1 day -> hour, etc.
  def convert_timestamp(timestamp)
    time_diff = Time.now - timestamp
    if time_diff < 60
      time_diff_conv = time_diff.to_i
      "#{time_diff_conv} second#{pluralize(time_diff_conv)} ago"
    elsif time_diff < 3600
      time_diff_conv = (time_diff / 60).to_i
      "#{time_diff_conv} minute#{pluralize(time_diff_conv)} ago"
    elsif time_diff < 3600 * 24
      time_diff_conv = (time_diff / 3600).to_i
      "#{time_diff_conv} hour#{pluralize(time_diff_conv)} ago"
    elsif time_diff < 3600 * 24 * 30
      time_diff_conv = (time_diff / (3600 * 24)).to_i
      "#{time_diff_conv} day#{pluralize(time_diff_conv)} ago"
    else
      time_diff_conv = (time_diff / (3600 * 24 * 30)).to_i
      "#{time_diff_conv} month#{pluralize(time_diff_conv)} ago"
    end
  end

  def pluralize(num)
    num == 1 ? '' : 's'
  end
end