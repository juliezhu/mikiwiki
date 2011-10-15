
######### ENVIRONMENTS ################################################################## 
# 
# env( page(name) ) => [name, url, content]
# 
# env(x): 
#   x.is_root?      ==> ['HOME','/',x.local_envfile.raw ]
#   x.has_env_file? ==> return env( x.parent ) + [x.local_envfile]
#              else ==> return env( x.parent )
# 
# 

class Environment
  
  
  # THIS IS NOT USED RIGHT NOW... IT IS JUST SOME NOTES
  def lookup_page
    lookup_local
    e = local_environment
    loop do
      e.lookup_bo
      e.lookup_data
      e.lookup_local
      e = e.parent_environment
    end
  end
  
  def self.find_closest_enveloping_environment start_page
    
  end

  def self.page_lookup context_page, pagename
    puts "LOOKUP #{pagename} IN #{context_page.name}"
    sibling = context_page.sibling(pagename)
    return adjust(sibling.name) if sibling.exist?
    
    puts "LOOKUP #{pagename} IN #{context_page.name} - NOT sibling"

    if context_page.environment
      codebo = context_page.environment.child('bo').child(pagename)
      return adjust(codebo.name) if codebo.exist?
      puts "LOOKUP #{pagename} IN #{context_page.name} - NOT codebo"

      databo = context_page.environment.child('data').child(pagename)  
      return adjust(databo.name) if databo.exist?
      puts "LOOKUP #{pagename} IN #{context_page.name} - NOT databo"
      
      envroot = context_page.environment.child(pagename)
      return adjust(envroot.name) if envroot.exist?
      puts "LOOKUP #{pagename} IN #{context_page.name} - NOT envroot"
      
      if not context_page.environment.root? 
        enveloping_environment = context_page.environment.parent.environment
        return adjust(page_lookup enveloping_environment, pagename) if enveloping_environment
        puts "LOOKUP #{pagename} IN #{context_page.name} - NOT in recursion"
      end
      
    end
    puts "LOOKUP #{pagename} IN #{context_page.name} - NOT in environment"
    
    absolutepage = Page.get(pagename)
    return adjust(absolutepage.name) if absolutepage.exist?
    puts "LOOKUP #{pagename} IN #{context_page.name} - NOT absolute"

    systempage = Page.root.child('system').child('bo').child(pagename)
    return adjust(systempage.name) if systempage.exist?
    puts "LOOKUP #{pagename} IN #{context_page.name} - NOT system"

    return nil
  end

  def self.adjust txt
    return txt[1..-1]  if txt and txt[0].chr == '/'
    return txt
  end
      
  def self.parent_environments page, username
    if page.root?
      return [ ] if not page.is_environment?
        
      local_environment = Page.get('environment')

      return [{
                :edit_url => local_environment.edit_url,
                :name => local_environment.parent.name,
                :format => (local_environment.is_new? ? nil : local_environment.format),
                :label => 'HOME',
                :content => (local_environment.is_new? ? nil : local_environment.raw(username)),
                :rendered => local_environment.render(username)
             }]

    else
      all_environments = page.parent.get_environments(username)

      local_environment = page.sibling('environment')      

      if not local_environment.is_new?
        
        all_environments += [{
                              :edit_url => local_environment.edit_url,
                              :name => local_environment.parent.name,
                              :format => (local_environment.is_new? ? nil : local_environment.format),
                              :label => local_environment.parent.singlename,
                              :content => local_environment.raw(username),
                              :rendered => local_environment.render(username)
                            }]
      end

      if page.is_directory?
        local_environment = page.child('environment')      

        if not local_environment.is_new?
          all_environments += [{
                                :edit_url => local_environment.edit_url,
                                :name => local_environment.parent.name,
                                :format => (local_environment.is_new? ? nil : local_environment.format),
                                :label => local_environment.parent.singlename,
                                :content => local_environment.raw(username),
                                :rendered => local_environment.render(username)
                              }]
        end
      end

      envs = all_environments.uniq_by{|e| e[:name]}.compact.reject{|e| e[:label].empty?}

      return envs
    end
  end
  
end
