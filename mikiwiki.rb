%w(rubygems sinatra erb yaml json cgi date time).each do |lib|
  require lib
end

require 'utils'
require 'pages/page'
require 'session'
require 'services/users'
require 'services/notification'
require 'services/authentication'
require 'services/environment'
require 'services/search'
 
enable :static
enable :sessions

$LOGGING = true # for the logger in utils.rb


# REMOVE THIS TO A MODULE
post "/energypush" do
  
  logfilepath = 'public/pages/data/energy.txt'
  
  log_txt = JSON.dump({
    'Amp' => params['Amp'] ,
    'Watt' => params['Watt']  
  })
      
   File.open(logfilepath,"w") do |file|
     file << log_txt
    end   
          
end


# remember if sidebar was open or closed

get '/close-sidebar' do
  session[:sidebar] = 'closed'
end

get '/open-sidebar' do
  session[:sidebar] = 'open'
end


presence_tracker = [ ] # each entry is [username, page, time]

get '/ping' do
  puts '********************** PING **********************' 

  new_entry = [username, params[:page], Time.now ]
  
  # replace old time for same user+page combination
  presence_tracker.delete_if {|e| e[0] == new_entry[0] and e[1] == new_entry[1] } 
  # delete all entries older than 10 seconds
  presence_tracker.delete_if {|e| (Time.now - e[2]) > 10 }

  presence_tracker << new_entry
  p presence_tracker
  return ''
end

# returns people online by default
get '/activity' do
  # delete all entries older than 10 seconds
  presence_tracker.delete_if {|e| (Time.now - e[2]) > 10 }
  
  people = presence_tracker.map{|e| e[0]}.uniq.sort
  people_and_pages = people.map{|p| [p, presence_tracker.select{|e| e[0] == p }.map{|e| e[1]} ]}
  return JSON.dump( people_and_pages )    
end

get '/notify' do
  puts '********************** SEND NOTIFICATION OF CHANGES!!! **********************' 
  puts "SEND TO #{params[:to]} via #{params[:mode]}: #{params[:body]}"  
  puts
  
  users = MikiUsers.get_users_by_name( params[:to], username() )
  
  if params[:mode] == 'email'
    MikiNotify.notify_by_email users, 'mikiwiki notification', params[:body]
  else
    puts "************ MODES DIFFERENT FROM EMAIL NOT SUPPORTED YET **********"
  end
  
  return ''
end

get '/authorize' do
  page = Page.get(params[:page])
  log username(), request, params, page, 'set_permissions', 'ajax'
  
  if page.set_permissions current_user, params[:readonly], params[:readwrite]
    return JSON.dump(['OK - set permissions'])
  else
    return JSON.dump( ['DENIED - setting permissions'] )
  end
end

get '/favicon.ico' do
end

# ===========================================================================

get '/register_mikiwiki' do
  erb :register_mikiwiki
end

post '/register_mikiwiki' do
    
    page_txt = JSON.dump({
      'email' => params[:email], 
      'name' => params[:name] ,
      'picture' => params[:url], 
      'role'    => 'user'
    })

    Page.get("users/#{params[:name]}").update 'bo/profile', username(), page_txt
    
    private_page_txt = JSON.dump({
      'password'     => params[:password], 
      'role'         => 'user'
    })
       
    Page.get("users/private/#{params[:name]}").update 'bo/profile', username(), private_page_txt

    redirect '/'

end

# ==========================================================================================

get '/login' do
  erb :login
end

get '/logout' do
  log username(), request, params, Page.root, 'logout'
  
  session[:user] = nil
  redirect '/login'
end

post '/login' do
  private_page = Page.get("users/private/#{params[:name]}")
  page = Page.get("users/#{params[:name]}")
  
  if not page.is_new? and not private_page.is_new?
    private_profile = private_page.json(username())
    profile = page.json(username())
    
    if private_profile['password'] == params[:password] and private_profile['password'] != ''
      log username(), request, params, page, 'login_ok'
      session[:user] = profile
      session[:user]['role'] = private_profile['role']
      redirect '/'
    end
  end

  log username(), request, params, page, 'login_failed'

  redirect '/login'
end

get '/search' do
  @page = Page.get('')

  found = search_pages(params[:keyword])

  log username(), request, params, @page, 'search'
  
  @pages = found.map{|a_path| Page.from_path(a_path) }
  
  puts "******** directory ***********"
  @pages.each do |page|
    puts page.name
  end
  
  @environments = @page.get_environments(username()) || []
  
  erb :directory
end

get '/' do
  authenticate! '/', 'read'

  @page  = Page.root
  @pages = Page.root.all_firstlevel 

  log username(), request, params, @page, 'read'
  
  puts "******** directory ***********"
  @pages.each do |page|
    puts page.name
  end
  
  @environments = @page.get_environments(username()) || []
  
  erb :directory
end

get '/access-denied' do
  erb :accessdenied
end

# authenticate! filepath, 'read'
# we need special access for the scripts..

get '/*/delete' do
  @page = authenticate_page params, 'delete'
  log username(), request, params, @page, 'delete'
  
  @page.delete
  redirect "/#{@page.parent.name}?changed=deleted&oldname=#{@page.name}"
end

get '/*/edit' do
  @page = authenticate_page params, 'update'

  if params[:clone]
    @original = Page.get( params[:clone] )

    log username(), request, params, @original, 'clone'
    
    if @original.is_directory?
      puts "CLONING DIRECTORY #{@page.name} FROM #{@original.name}"
      @page.clone_from( @original )
      redirect "/#{@page.name}"

    elsif @original.is_resource?
      puts "CLONING FILE #{@page.name} FROM  #{@original.name}"
      @page.clone_from @original
      redirect "/#{@page.name}"
      
    else
      puts "CLONING FILE #{@page.name} FROM  #{@original.name}"
      clone = Page.get( params[:clone] )
      @pagebody = clone.raw(username())
      @pageformat = clone.format
    end
    
  elsif params[:rename]
    @original = Page.get( params[:rename] )
    
    if @original.is_directory?
      log username(), request, params, @original, 'update_rename'
      puts "RENAMING DIRECTORY #{@original.name} TO #{@page.name}"
      @original.rename @page.name
      redirect "/#{@page.name}"
    else
      return "RENAMING FILES SHOULD NOT BE DONE FROM HERE"
    end
    
  elsif @page.is_new?
    log username(), request, params, @page, 'want_to_create'
    
    if params[:body]
      @pagebody = CGI::unescape( params[:body] ) 
      @pageformat = 'miki'
    else
      @pagebody = ''
      @pageformat = ''
    end
  else
    log username(), request, params, @page, 'edit'
    
    @pagebody = @page.raw(username())
    @pageformat = @page.format
  end

  @environments = @page.get_environments(username()) || []
  
  erb :edit
end


post '/*/edit' do
  @page = authenticate_page params, 'update'
  oldname = @page.name
    
  if params[:title] != @page.name
    if @page.is_resource?
      log username(), request, params, @page, 'update_rename'
      @page.rename params[:title]  
    else
      log username(), request, params, @page, 'update_rename'
      @page.rename params[:title]  
      
      # why did i do this stuff here... ?
      # @page.real_delete if not @page.name == params[:title]
      # @page = Page.update params[:title], params[:format], username(), params[:body]
    end
    
    redirect "/#{params[:title]}?changed=renamed&oldname=#{oldname}"
  else
    log username(), request, params, @page, 'update'
    @page.update params[:format], username(), params[:body]
    redirect "/#{@page.name}?changed=saved"
  end  
end

post '/*/edit_and_continue' do
  @page = authenticate_page params, 'update'
  oldname = @page.name
    
  if params[:title] != @page.name
    if @page.is_resource?
      log username(), request, params, @page, 'update_rename'
      @page.rename params[:title]  
      return "Title changed"      
    else
      log username(), request, params, @page, 'update_rename'
      @page.real_delete if not @page.name == params[:title]
      @page = Page.update params[:title], params[:format], username(), params[:body]
      return "Saved changes and new title"      
    end
  else
    log username(), request, params, @page, 'update'
    @page.update params[:format], username(), params[:body]
    return "Saved changes"      
  end  
end

post '/*/savetags' do
  @page = authenticate_page params, 'update'
  
  @page.update_tags! params[:tags]
  
  return "Saved tags to metadata"
end

post '/*/realtime-action' do
  @page = authenticate_page params, 'update'

  command = JSON.parse(params['data'])

  page_raw_data = @page.raw(username())

  if page_raw_data.strip == ''
    pagedata = { }
  else
    pagedata = JSON.parse( page_raw_data )
  end
  
  if command['action'] == 'create' or command['action'] == 'update'
    pagedata[command['item']['id']] = command['item']
    pagedata[command['item']['id']]['update'] = {'time' => Time.now.to_f, 'username' => username()}
    
    @page.set_content JSON.dump( pagedata ), username()    
    
    puts "%%%%%%%%%%%%% realtime-action %%%%%%%%%%%%%%%%"
    puts @page.timestamp
    puts "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
    
    return @page.timestamp.to_s
    
  elsif command['action'] == 'delete'
    pagedata.delete command['item']['id']
    @page.set_content JSON.dump( pagedata ), username()

    return @page.timestamp.to_s
  end

  return ''
end

post '/*/realtime-synch' do
  @page = authenticate_page params, 'read'

  puts "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
  puts "REALTIME SYNCH"
  puts params.inspect

  pagedata = JSON.parse( @page.raw(username()) )
  page_timestamp = @page.timestamp

  puts "CLIENT TIMESTAMP #{params[:timestamp]}"
  puts "SERVER TIMESTAMP #{page_timestamp.to_f}"
  puts "DIFFERENCE #{(page_timestamp.to_f - params[:timestamp].to_f)}"
  puts "SHOULD UPDATE CLIENT!" if params[:timestamp].nil? or ( (page_timestamp.to_f - params[:timestamp].to_f)  > 0.001)
  puts "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
  
  if params[:timestamp].nil? or ( (page_timestamp.to_f - params[:timestamp].to_f)  > 0.001)
    log username(), request, params, @page, 'read_synch','ajax'
    puts "SERVER SENDS UPDATE"
    return JSON.dump({
      'data' => pagedata,
      'version' => page_timestamp.to_s 
    })  
  else
    return ''
  end
end


post '/*/append' do
  @page = authenticate_page params, 'update'
  log username(), request, params, @page, 'update', 'ajax'

  page_raw_data = @page.raw(username())
  
  if page_raw_data.strip == ''
    pagedata = [ ]
  else
    pagedata = JSON.parse( page_raw_data )
  end
  
  newdata  = JSON.parse( params[:data] )
  
  pagedata << newdata

  @page.set_content JSON.dump( pagedata ), username()
  
  pagedata =  JSON.parse( @page.raw(username()) )
  page_timestamp = @page.metadata['update'].to_f

  return JSON.dump({
    'data' => pagedata,
    'version' => page_timestamp.to_s
  })
end

post '/*/synchronize' do
  @page = authenticate_page params, 'read'

  pagedata = JSON.parse( @page.raw(username()) )
  page_timestamp = @page.metadata['update'].to_f

  if params[:timestamp].nil? or ( (page_timestamp.to_f - params[:timestamp].to_f)  > 0.00001)
    log username(), request, params, @page, 'read_synch','ajax'
    
    return JSON.dump({
      'data' => pagedata,
      'version' => page_timestamp.to_s 
    })  
  else
    return ''
  end
end

post '*/upload' do
    @page = authenticate_page params, 'update'
    log username(), request, params, @page, 'create_upload'
    
    if not params[:file] && (tmpfile = params[:file][:tempfile]) && (name = params[:file][:filename])
      @error = "No file selected"
      redirect "/#{@page.name}"    
    end

    new_page = @page.child(name)

    new_page.upload_resource( tmpfile.read, username() )
    
    redirect "#{new_page.name}"    
end

post '/explode' do
  contextname = CGI::unescape(params[:context])
  pagecontext = Page.get( contextname )

  log username(), request, params, pagecontext, 'read_embedded', 'ajax'
  
  Renderer.new( params[:body], pagecontext, username() ).render('miki') 
end

get '/*' do
  @page = authenticate_page params, 'read'
    
  if params[:lookup] == 'y'
    return @page.name
  end

  puts "*** PAGE LOAD REQUEST FOR #{@page.name}"
  
  if @page.is_directory?
    log username(), request, params, @page, 'read'
    
    @pages = @page.all_firstlevel 
    
    if params[:listsubpages] == 'y'
      all_files = @pages.map do |page|
        {
          "name" => page.name,
          "shortname" => page.singlename,
          "info" => ( page.is_directory? ? nil : page.metadata() ),
          "is_folder" => page.is_directory?,
          "is_environment" => page.is_environment?,
          "has_history" => page.has_history?
        }
      end
      
      all_files_sorted = all_files.sort_by{|page| page["shortname"]}

      return JSON.dump(all_files_sorted)
      
    else

      puts "******** directory ***********"
      @pages.each do |page|
        puts page.name
      end

      @environments = @page.get_environments(username()) || []

      erb :directory
    end
    
  elsif @page.is_new?
    log username(), request, params, @page, 'want_to_create'
    
    if params[:nolayout] == 'y' # we are handling an ajax call here
      return %{<a class='uncreated' title='click to create the missing page to include' href='/#{@page.name}'>#{@page.name}</a>}
    elsif params[:makefolder] == 'y'
      @page.make_folder!
      redirect "/#{@page.name}"
    else
      redirect "/#{@page.name}/edit"
    end
    
  elsif params[:metadata] == 'y'
      return @page.metadata_as_json

  elsif params[:nolayout] == 'y'
      log username(), request, params, @page, 'read_no_layout', 'ajax'

      if @page.is_content?
        return @page.raw(username())
      elsif @page.is_code?
        return @page.render_as_code_block(username())
      else # it is a data page
        # I expected the following to work, but it didn't: return @page.render_data_page_as_content_page(username())
        return @page.raw(username())
      end

  elsif params[:raw] == 'y'
      log username(), request, params, @page, 'read_no_layout_raw', 'ajax'
      return @page.raw(username())
      
  else # just a normal page
      log username(), request, params, @page, 'read'

      if @page.is_content?
        @pagecontent = @page.render(username())
        
      elsif @page.is_code?
        @pagecontent = "<em>*** CODE OF BEHAVIOR USING FORMAT #{@page.format} ***</em>" + "<br/><br/>"
        @pagecontent += @page.render_as_code_block(username())
        
      else # it is a data page
        @pagecontent = "<em>*** PREVIEW OF DATA USING FORMAT <a class='formatlink' href='/#{@page.format}'>/#{@page.format}</a> ***</em>" + "<br/><br/>"
        @pagecontent += @page.render_data_page_as_content_page(username())
        @pagecontent += "<br/><br/><hr/><br/><br/>"
        @pagecontent += "<em>*** RAW DATA ***</em>" + "<br/><br/>"
        @pagecontent += @page.render(username())
        
      end

      @environments = @page.get_environments(username()) || []
      
      erb :page
  end
    
end

__END__


@@ layout
<html>
  <head>
    <title>MikiWiki</title>
    <link rel="stylesheet" type="text/css" href="/css/mikiwiki.css" />
    <link href="/javascript/jquery-ui-1.8.6.custom.css" rel="stylesheet" type="text/css"/>
		<link rel="stylesheet" href="/css/examples.css" type="text/css" media="screen" charset="utf-8" />
		
    <script type="text/javascript" src="/javascript/json2.js"></script>  
    <script type="text/javascript" src="/javascript/jquery-1.4.2.min.js"></script>  

    <script type="text/javascript" src="/javascript/jquery-ui.min.js"></script>  
    <script type="text/javascript" src="/javascript/raphael-min.js"></script>   

    <script type="text/javascript" src="/javascript/jquery.confirm-1.3.js"></script>  
   
    <script src='/javascript/jquery.ba-dotimeout.min.js' type="text/javascript"></script>
    
    <script src='/javascript/head.min.js' type="text/javascript"></script>
    

    <script src='/javascript/jquery.parsequery.js' type="text/javascript"></script>
    <script src='/javascript/g.raphael-min.js' type="text/javascript"></script>   

    <script type='text/javascript' src='https://www.google.com/jsapi'></script>

    <script src='/javascript/utilities.js' type="text/javascript"></script>

    <script src="/javascript/jquery.typing-0.2.0.min_.js" type="text/javascript"></script>
    
    <script src="/javascript/jquery.event.drag-2.0.min.js"></script>
    <script src="/javascript/jquery.event.drop-2.0.min.js"></script>
        
    <script type="text/javascript" src="/javascript/mikiwiki.js"></script>  
    
    <!-- google search image -->
    <script type="text/javascript" src="/javascript/jquery.atteeeeention.min.js"></script>  
      
    <!-- js editor -->
    <script src="/js/codemirror.js" type="text/javascript"></script>
    <script src="/js/mirrorframe.js" type="text/javascript"></script>
    
    <!-- cleditor -->
    <link rel="stylesheet" href="/css/jquery.cleditor.css" type="text/css" media="screen" charset="utf-8" />
    <script src="/javascript/jquery.cleditor.js" type="text/javascript"></script>   
    <script src="/javascript/jquery.cleditor.icon.min.js" type="text/javascript"></script>
    <script src="/javascript/jquery.cleditor.table.min.js" type="text/javascript"></script>
    <script src="/javascript/jquery.cleditor.bo.js" type="text/javascript"></script>
    
  </head>
  <body>

    <div class="container_12">
      <div class="header">
        <% if is_logged_in? %>
          <div class="grid_12">
            <div class="grid_9 alpha path-navigation">
              <%= @page ? @page.linkable_path : 'NO PAGE ERROR' %>
            </div>  
            <div class="grid_3 omega">
              <div id='logout'>
                logged in as <strong><%= username %></strong> <img id="profile_pix" src='<%= user_pic %>' style='width: 20px; height: 20px;' /> | <a href='/logout'>sign off</a>
              </div>
            </div>
          </div>

          <div class="clear"></div>
      
          <div class='grid_12' id='metacontrols'>
            <a id='toggle-mikinuggets' href='#'>toggle mikinuggets</a>
          </div>

          <script type="text/javascript">
            $("#toggle-mikinuggets").click(function(){
              $('body').toggleClass('visible-mikinuggets');
            });      
          </script>

     
        <% end %>
      
      </div>
    
      <div class="clear"></div>
    
      <%= @error %>

      <%= yield %>
      
      <script type="text/javascript">
        $('.delete-link').confirm();
      </script>

      <script type="text/javascript">
        $("#form-clone").hide();

        $("#form-clone input").val( "<%= @page ? @page.name : '' %>-clone");

        $('#clone-link').click(function() {
          $("#clone-link").hide();
          $("#form-clone").show();
          return true;
        });

        $('#make-clone').click(function() {
          window.location.href = '/' + $("#form-clone input").val() + '/edit?clone=<%=@page ? CGI::escape( @page.name ) : nil %>';
          return true;
        });
      </script>
      
      <script type="text/javascript">
        $("#search-button").click(function(){
          window.location.href = "/search?keyword="+$('#search_tag').val();
          return true;
        });
      </script>
      
</body>
</html> 

@@ login
<div class="content grid_12">
  <div class="grid_11 push_1">
        
      <div id='login_title'>Login</div>
      <form id="login_form" action='/login' method='post'>
        username </br>
        <input type='text' id='name' name='name' /> </br>
        password </br>
        <input type='password' id='password' name='password' /> </br></br>
        <input type='submit' id='submit' value='Sign in' /> 
      </form>
  
  </div>

  <!-- new icon info -->
 <div id="intro" class="grid_11 push_1">
    <div class="grid_5">
       <li><img class='login_icon' src="/siteImages/sites.png"><h4>Create your own evironments</h4>
         <p>MikiWiki allows you to create your own environment, use your own language and more</p>
      </li>
    </div>
    <div class="grid_5">    
     <li><img  class='login_icon' src="/siteImages/group.png"><h4>Collaborate and Communicate with Others</h4>
       <p>MikiWiki comes with a set of handy nuggets for communication and coordination</p>
    </li>
    </div>
  </div>  

  <div id="intro" class="grid_11 push_1">
    <div class="grid_5">   
     <li><img  class='login_icon' src="/siteImages/ideas.png"><h4>Share and Organize your Creative Ideas</h4>
       <p>You can create your own Post-its, multi-media notes or sketch your brillant ideas and share them with your teammates</p> 
      </li>    
    </div>

    <div class="grid_5">
     <li><img class='login_icon'  src="/siteImages/rank.png"><h4>Tinker nuggets</h4>
       <p>Nuggets are ready-made objects, which make collaboration more fun and exploratory</p> 
    </li>
    </div>
  </div>  
  
  <div id="intro" class="grid_11 push_1">

    <div class="grid_5">   
     <li><img class='login_icon'  src="/siteImages/code.png"><h4>API for Advanced Users</h4>
      <p>Nuggets are executable JavaScript, which can be tinkered and tailored. We also provide an API for advanced users to create their own nuggets</p>
     </li>
    </div>
 
    <div class="grid_5">    
     <li><img class='login_icon' src="/siteImages/library.png"><h4>Design along the way</h4>
       <p>MikiWiki can be evolved along your collaboration. You can tailor it at any point, and the more you use it the more effiecient it will be...</p> 
    </li>     
    </div>
 </div>
  
</div>

@@ register_mikiwiki
<div class="content grid_12">
      
    <div class="grid_11 push_1">
      <div id='login_title'>Register MikiWiki</div>

      <form id="login_form" method="post" action="/register_mikiwiki">

        username </br>
        <input type='text' id='name' name='name' /> </br>
        password </br>
        <input type='password' id='password' name='password' /> </br>
        confirm password </br>
        <input type='password' id='confirm_password' name='password2' /> </br>
        email </br>
        <input type='text' id='email' name='email' /> </br>
        profile imageURL </br>
        <input type='text' id='pic' name='url' /> </br></br>     
        <input id='submit' class="submit" type="submit" value="Register"/>
      
      </form>
  </div>
  
  <div id="intro" class="grid_11 push_1">
     <div class="grid_5">
        <li><img class='login_icon' src="/siteImages/sites.png"><h4>Create your own evironments</h4>
          <p>MikiWiki allows you to create your own environment, use your own language, own CSS and more</p>
       </li>
     </div>
     <div class="grid_5">    
      <li><img  class='login_icon' src="/siteImages/group.png"><h4>Collaborate and Communicate with Others</h4>
        <p>MikiWiki comes with a set of handy nuggets for communication and coordination, which are crucial for collaboration</p>
     </li>
     </div>
   </div>  

   <div id="intro" class="grid_11 push_1">
      <div class="grid_5">   
       <li><img  class='login_icon' src="/siteImages/ideas.png"><h4>Share and Organize your Creative Ideas</h4>
         <p>You can create your own Post-its, multi-media notes or sketch your brillant ideas and share them with your teammates</p> 
        </li>    
      </div>

      <div class="grid_5">
       <li><img class='login_icon'  src="/siteImages/rank.png"><h4>Tinker nuggets</h4>
         <p>Nuggets are ready-made objects, which make collaboration more fun and exploratory</p> 
      </li>
      </div>
    </div>  

    <div id="intro" class="grid_11 push_1">

      <div class="grid_5">   
       <li><img class='login_icon'  src="/siteImages/code.png"><h4>API for Advanced Users</h4>
        <p>Nuggets are executable JavaScript, which can be tinkered and tailored. We also provide an API for advanced users to create their own nuggets</p>
       </li>
      </div>

      <div class="grid_5">    
       <li><img class='login_icon' src="/siteImages/library.png"><h4>Design along the way</h4>
         <p>MikiWiki can be evolved along your collaboration. You can tailor it at any point, and the more you use it the more effiecient it will be...</p> 
      </li>     
      </div>
   </div>
  
</div>

@@ accessdenied
<div class="content grid_12">

<h1>Access denied</h1>

You don't have the authorization to access this resource
</div>

@@ directory
<div class="content grid_12">
 <div id="wrapper">   

        <ul class='controls'> 
            
            <li><a href="/"><img id="home" src="/siteImages/home.png">Home</a></li>
            
            <li>
              <a id='create-folder' href="#"><img id="add" src="/siteImages/add.png">Create folder</a>
              <span id='folder-name'>
                folder-name:
                <input type='text' size=20 />
                <a href='#' id='make-folder'>create</a>
              </span>
            </li>
            
            <li>
              <a id='create-page' href="#"><img id="create" src="/siteImages/create_doc.png">Create page</a>
              <span id='page-name'>
                page-name:
                <input type='text' size=20 />
                <a href='#' id='make-page'>create</a>
              </span>
            </li>    
                 
            <script type="text/javascript">
              $("#page-name").hide();

              $("#page-name input").val( "<%= @page.root? ? 'NEW-PAGE' : @page.child('NEW-PAGE').name %>");

              $('#create-page').click(function() {
                $("#create-page").hide();
                $("#page-name").show();
                return true;
              });

              $('#make-page').click(function() {
                window.location.href = '/' + $("#page-name input").val();
                return true;
              });

            </script>
            
            <% if not @page.root? %>
              <% if is_admin? %>
                <li><a class='delete-link' href="/<%= @page.name %>/delete"><img id="delete" src="/siteImages/action_delete.png">Delete</a></li>
              <% end %>
            
              <li>
                <a id='rename-link' href="#"><img id="rename" src="/siteImages/rename_doc.png">Rename</a>
                <span id='form-rename'>
                  new name:
                  <input type='text' size=20 />
                  <a href='#' id='make-rename'>rename</a>
                </span>
              </li>
            
              <li>
                <a id='clone-link' href="#"><img id="clone" src="/siteImages/clone.png">Clone</a>
                <span id='form-clone'>
                  clone name:
                  <input type='text' size=20 />
                  <a href='#' id='make-clone'>make clone</a>
                </span>
              </li> 
            <% end %>
            
            <li>            
              <a id='search-button' href="#"><img id="search" src="/siteImages/search.png">Search</a>
              <span>
                <input type='text' id="search_tag" size=20 />
              </span>             
            </li>
            
            <li>
              <span id="upload_icon"><img src="/siteImages/upload.png"><b>Upload image</b></span>
              <form id="choose_pix" action='<%= @page.root? ? '/upload' : "/#{@page.closer_directory_name}/upload" %>' enctype='multipart/form-data' method='post'>
                <input name='file' type='file' /><br/>
                <input type='submit' value='Upload' />
              </form>
            </li>
              
          </ul>

        <div class='pagebody directory envelope' id='<%= @page.css_id_uniq %>' pagename='<%= @page.name %>' formatpagename='directory'>
          <ul class='<%= @pages.size < 7 ? 'veryshort' : @pages.size < 17 ? 'short' : @pages.size < 26 ? 'medium' : 'long'  %>'>
           <% @pages.each do |page| %>
             <li id="content_sign">
               <% if page.is_directory? %>
                 <% if page.is_environment? %>
                   <img id="web_icon_folder" src="/siteImages/env.png" />
                 <% else %>
                   <img id="web_icon_folder" src="/siteImages/folder.png" />
                 <% end %>
               <% else %>
                 <img id="web_icon_doc" src="/siteImages/document.png" />
               <% end %>
               <a href="/<%= page.name %>"><%= page.name_from(@page) %></a>
             </li>

           <% end %>
           </ul>
          
          <%= erb :environment_box, :layout => false %>
          
        </div> 
           
  </div>
</div>

<script type="text/javascript">
  $("#choose_pix").hide();
  $("#upload_icon").click(function(){
    $( "#choose_pix" ).toggle('slow');
  })        
</script>
  
<script type="text/javascript">

//create a folder

    $("#folder-name").hide();

    $("#folder-name input").val( "<%= @page.root? ? 'NEW-FOLDER' :@page.child('NEW-FOLDER').name %>");

    $('#create-folder').click(function() {
      $("#create-folder").hide();
      $("#folder-name").show();
      return true;
    });

    $('#make-folder').click(function() {
      window.location.href = '/' + $("#folder-name input").val() + '?makefolder=y';
      return true;
    });
  
  
//rename  
  
  $("#form-rename").hide();

  $("#form-rename input").val( "<%= @page ? @page.name : '' %>");

  $('#rename-link').click(function() {
    $("#rename-link").hide();
    $("#form-rename").show();
    return true;
  });

  $('#make-rename').click(function() {
    window.location.href = '/' + $("#form-rename input").val() + '/edit?rename=<%=CGI::escape @page.name %>';
    return true;
  });
</script>


@@ environment_box
<div id="sidebar_box" class='environments grid_3 push_12'>
  <div id="toggle_env">
    <% for env in @environments||[] %>
      <div class='env_embed envelope' id='env-<%= env[:name] %>' pagename='<%= env[:name] == '' ? "environment" : "#{env[:name]}/environment" %>' formatpagename='<%= env[:format] %>'>
        <%= env[:rendered] %>
      </div>
    <% end %>
  </div>
  <div class='envcontrols'>
    <div id='env_path'>
      <%= @environments && @environments.map{|env| "<a href='#{env[:edit_url]}' class='environment-link'>#{env[:label]}</a>" }.join(' | ') %><br/>
    </div>
    <h2 class="active_env"><a href="#">Active Environments</a></h2>
  </div>
</div>

<script type="text/javascript">
  function closeSidebar(){
    $(".active_env").addClass('active');
    $( "#toggle_env" ).hide('slow');
  }

  function openSidebar(){
    $(".active_env").removeClass('active');
    $( "#toggle_env" ).show('slow');
  }

</script>

<% if session[:sidebar] == 'closed'%>
  <script type="text/javascript">
    $( "#toggle_env" ).hide();
    closeSidebar();
  </script>
<% else%>
  <script type="text/javascript">
    $( "#toggle_env" ).show();
    openSidebar();
  </script>
<% end %>

<script type="text/javascript">
  $( "#toggle_env" ).scrollTop = $( "#toggle_env" ).scrollHeight;             

  $(".active_env").click(function(){
    if ( $(".active_env").hasClass('active') ) {
      $.ajax({ url: '/open-sidebar',success: function(){} });
      openSidebar();
    }else{
      $.ajax({ url: '/close-sidebar',success: function(){} });
      closeSidebar();
    }
  }); 
</script>

@@ page
<div class="content grid_12">
  <div id="wrapper">
      <ul class='controls'>
        <li><a href="/"><img id="home" src="/siteImages/home.png">Home</a></li>
        <li><a href="/<%= @page.name %>/edit">Edit<img id="edit" src="/siteImages/edit_doc.png"></a></li>
        <li><a class='delete-link' href="/<%= @page.name %>/delete"><img id="delete" src="/siteImages/action_delete.png">Delete</a></li>
        <li>
          <a id='clone-link' href="#"><img id="clone" src="/siteImages/clone.png">Clone</a>
          <span id='form-clone'>
            clone name:
            <input type='text' size=20 />
            <a href='#' id='make-clone'>make clone</a>
          </span>
        </li>
        <li>            
          <a id='search-button' href="#"><img id="search" src="/siteImages/search.png">Search</a>
          <span>
            <input type='text' id="search_tag" size=20 />
          </span>             
        </li>
      </ul>

      <div class='pagebody leaf envelope', id='<%= @page.css_id_uniq %>', pagename='<%= @page.name %>', formatpagename='<%= @page.format %>'>  
        <%= @pagecontent %>
        
        <%= erb :environment_box,  :layout => false %>
        
      </div>
      
  </div>
</div>

@@ edit
<div class="content grid_12">
  <div id="wrapper">
    <form method="POST">
      Page name <input type="text" name="title" value="<%= @page.name %>" id="title" />
      <% if not @page.is_resource? %>
        Format <input type="text" name="format" value="<%= @pageformat == '' ? 'miki' : @pageformat %>" id="format" />
      <% end %>
      <input type="submit" name="Save" value="Save" id="Save" class='button'/>      
      <br/>
      <br/>
      <% if not @page.is_resource? %>
        <textarea id="code" name="body" rows="20" cols="100"><%= @pagebody %></textarea>
        <br/>
        <br/>
      <% end %>
      <input type="submit" name="Save" value="Save" id="Save" class='button'/>      
      <a href="/<%= @page.name %>">Discard changes</a>
    </form>

    <% if @page.is_resource? %>
      <br/>
       <%= @page.render(username()) %>
      <br/>
      <br/>
    <% end %>
  </div>
  <%= erb :environment_box, :layout => false %>
</div>

<script type="text/javascript">

  var currentEditor = null;
  var richEditor = null;
  var codeEditor = null;

  function removeCodeEditor(){
    codeEditor.toTextArea();
    codeEditor = null;
    $('.CodeMirror-wrapping').remove();
    
    displayDefaultTextArea();
  }

  function removeRichEditor(){
    richEditor.disable(true);
    richEditor = null;
    $(".cleditorMain").replaceWith( $(".cleditorMain textarea") );
    
    displayDefaultTextArea();
  }
  
  function displayDefaultTextArea(){
    $("#code").
      css({
        'display':'block',
        'visibility':'visible'
      }).
      removeAttr('disabled');  
  }
  
  function setRichEditor(){
    if (codeEditor) removeCodeEditor();
    
    richEditor = $("#code").cleditor({
      width:"100%", 
      height:500,
      updateTextArea: function(html){
        return html.replace(new RegExp("&lt;&lt;", "g"),"<<")
                   .replace(new RegExp("&gt;&gt;", "g"),">>")
                   .replace(new RegExp("&lt;script&gt;", "gi"),"<s"+"cript>")
                   .replace(new RegExp("&lt;/script&gt;", "gi"),"</s"+"cript>");
      },
      updateFrame: function(html){
        return html.replace(new RegExp("<<", "g"),"&lt;&lt;")
                   .replace(new RegExp(">>", "g"),"&gt;&gt;")
                   .replace(new RegExp("<s"+"cript>", "gi"),"&lt;script&gt;")
                   .replace(new RegExp("</s"+"cript>", "gi"),"&lt;/script&gt;");
      }  
    })[0];
    
    currentEditor = "RICH EDITOR";
  }

  function setCodeEditor(){    
    if (richEditor) removeRichEditor();
    
    codeEditor = CodeMirror.fromTextArea('code',{
      height: "450px",
      parserfile: ["tokenizejavascript.js", "parsejavascript.js"],
      stylesheet: "/css/jscolors.css",
      lineNumbers: true,
      path: "/js/"
    });    
    
    currentEditor = "CODE EDITOR";
  }

  if ( $('#format').val() == 'miki' ) {
    setRichEditor();
  }else{
    setCodeEditor();
  }  
  
  $('#format').keyup(function(){
    if ( $('#format').val() == 'miki' && currentEditor != "RICH EDITOR"){
      $.doTimeout( 200, function(){ 
        // this delay (or an alert) is necessary to avoid interferences with the rich text editor
        setRichEditor();
			  return false;
			});
    } else if ( $('#format').val() != 'miki' && currentEditor == "RICH EDITOR"){
      setCodeEditor();
    }
  });
      
</script>


@@ experiment

scope is <%= session.inspect %> <br/><br/><br/>
current_user is <%= current_user.inspect %> <br/><br/><br/>

