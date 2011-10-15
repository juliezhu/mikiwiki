def current_user
  session[:user]
end

def username
  current_user ? current_user['name'] : ''
end

def user_pic
  current_user ? current_user['picture'] : ''
end

def user_role
  current_user ? current_user['role'] : ''
end

def is_logged_in?
  not current_user.nil?
end

def is_admin?
  user_role == 'admin'
end

