def authenticate_page params, action
  filepath = params[:splat][0]

  context_page = Page.get( params['currentpagename'] || '' )

  lookedup_pagename = Environment.page_lookup context_page, filepath

  if lookedup_pagename.nil?
    page = authenticate! filepath, action

    return page
  else
    lookedup_page = Page.get(lookedup_pagename)

    page = authenticate! lookedup_page.name, action

    return page
  end
end

def authenticate! path, action
  # return if action == 'raw'
  redirect '/login' if not is_logged_in? 

  page = Page.get(path)

  return page if user_role == 'admin'    

  redirect '/access-denied' if not page.authorized? current_user, action
  
  return page
end

class PageAuthenticationMetadata
  def initialize metadata
    puts ">>> PageAuthenticationMetadata 1 <<<"
    @m = metadata
  end
  
  def can_write? user
    puts ">>> PageAuthenticationMetadata can_write? 1 <<<"
    return true if user['role'] == 'admin'
    return true if not readwrite_is_set? and not readonlylist_include? user
    return true if     readwrite_is_set? and     readwritelist_include? user
    return false
  end

  def can_read? user
    puts ">>> PageAuthenticationMetadata can_read? 1 <<<"
    return true if user['role'] == 'admin'
    return true if not readwrite_is_set? 
    # THE FOLLOWING ARE NOT EXACTLY CORRECT.. got changed to: return true if not readwrite_is_set?  
    # return true if not readwrite_is_set? and not readonly_is_set?
    # return true if not readwrite_is_set? and     readonly_is_set? and readonlylist_include? user
    return true if     readwrite_is_set? and not readonly_is_set? and readwritelist_include? user
    return true if     readwrite_is_set? and     readonly_is_set? and (readwritelist_include? user or readonlylist_include? user)
    return false  
  end

  def readonlylist
    @m['allow']['readonly']
  end
  
  def readwritelist
    @m['allow']['readwrite']
  end
  
  def readonly_is_set?
    not @m['allow'].nil? and not @m['allow']['readonly'].nil? and not @m['allow']['readonly'].empty?
  end

  def readwrite_is_set?
    not @m['allow'].nil? and not @m['allow']['readwrite'].nil? and not @m['allow']['readwrite'].empty?
  end

  def readonlylist_include? user
    readonlylist.include? user['name'] or readonlylist.include? user['role'] or readonlylist.include? 'all'
  end

  def readwritelist_include? user
    readwritelist.include? user['name'] or readwritelist.include? user['role']
  end
end

module PageAuthentication

  def set_permissions user, allow_readonly, allow_readwrite
    puts ">>> set_permissions 1 <<<"
    return false if not authorized? user, 'update'
    puts ">>> set_permissions 2 <<<"

    m = metadata()
    m['allow'] = {}
    m['allow']['readonly']  = allow_readonly
    m['allow']['readwrite'] = allow_readwrite
    
    @pagemetadata.content = YAML.dump( m )    
    
    puts ">>> set_permissions 3 <<<"
    return true
  end

  def authorized? user, action
    puts ">>> authorized? 1 - #{name} <<<"
    if is_environment?
      authorized_environment? user, action
    elsif is_directory?
      puts ">>> authorized? 2 - #{name} <<<"
      return true if root?
      return parent.authorized? user, action
    else
      puts ">>> authorized? 3 - #{name} <<<"
      authorized_page? user, action
    end
  end
  
      def authorized_environment? user, action
        puts ">>> authorized_environment? 1 - #{name} <<<"
        if is_write_action? action
          authorized_to_write_environment? user, action
        elsif is_read_action? action
          authorized_to_read_environment? user, action
        end    
      end

          def authorized_to_write_environment? user, action
            if child('environment').can_write? user
              return true if root?
              return parent.authorized? user, action
            end 
            return false
          end

          def authorized_to_read_environment? user, action
            puts ">>> authorized_to_read_environment? 1 - #{name} <<<"
            if child('environment').can_read? user
              puts ">>> authorized_to_read_environment? 2 - #{name} <<<"
              return true if root?
              return parent.authorized? user, action
            end 
            puts ">>> authorized_to_read_environment? 3 - #{name} <<<"
            return false
          end  
  
      def authorized_page? user, action
        puts ">>> authorized_page? 1 - #{name} <<<"
        if is_write_action? action
          authorized_to_write_page? user, action
        elsif is_read_action? action
          authorized_to_read_page? user, action
        end    
      end

          def authorized_to_read_page? user, action
            puts ">>> authorized_to_read_page? 1 - #{name} <<<"
            if can_read? user
              puts ">>> authorized_to_read_page? 2 - #{name} <<<"
              return parent.authorized? user, action
            end 
            puts ">>> authorized_to_read_page? 3 - #{name} <<<"
            return false
          end

          def authorized_to_write_page? user, action
            puts ">>> authorized_to_write_page? 1 - #{name} <<<"
            if can_write? user
              puts ">>> authorized_to_write_page? 2 - #{name} <<<"
              return parent.authorized? user, action
            end 
            puts ">>> authorized_to_write_page? 3 - #{name} <<<"
            return false
          end
  
  
  def is_write_action? action
    ['update','delete'].include? action
  end

  def is_read_action? action
    'read' == action
  end

  def can_write? user
    begin
      authentication_metadata( ).can_write? user
    rescue 
      return true
    end
  end

  def can_read? user
    begin
      puts ">>> can_read? 1 - #{name} <<<"
      authentication_metadata( ).can_read? user
    rescue 
      puts ">>> can_read? CRASH - #{name} <<<"
      return true
    end
  end
  
  def authentication_metadata
    PageAuthenticationMetadata.new( metadata() )
  end

end