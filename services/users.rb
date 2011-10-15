class MikiUsers
  
  def self.get_users_by_name user_names,current_user_name 
    user_names.map{|name| get_user_by_name(name,current_user_name)}
  end

  def self.get_user_by_name user_name,current_user_name 
    Page.get("users/#{user_name}").json(current_user_name)
  end
  
end

