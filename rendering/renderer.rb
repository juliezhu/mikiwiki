require 'rendering/nugget'

class Renderer

  def initialize text, page_context, username
    @raw = text
    @username = username
    @page_context = page_context
  end

  def render format
    case format
    when 'raw'                    then @raw
    when 'miki'                   then mikiml(@raw)  
    when 'png','jpg','gif','bmp','JPG','PNG','BMP','GIF', 'jpeg'  then image(@raw)      #raw is the filename path in this case
    when 'wav','wma','wave','au' then audio(@raw)  
    when 'pdf','PDF','ppt','PPT' then files(@raw)    
    when 'avi','mp3','mov','m4v','mpeg','swf','wmv','mp4', 'M4V' then video(@raw) 
    when 'json'                   then JSON.parse(@raw) # it is used in a few cases server-side. login check for example.
    else 
      return @raw     # for formats like: javscript, template, custom formats..
    end
  end

  # This should be called when a Data Page is rendered as main page
  # Since it is a data page, no Sugar or ML expansion is needed
  # No nugget expansion is needed.. there is no need to get the data file.. the data is here already

  def render_data_page_as_content_page format
    # the second parameter is the data, passed as if it were params
    render_mikinugget format, @raw, :data_page_as_content_page 
  end
  

private

  # lookup as local relative pagename, then backtrack to environment and look in bo then look in data, 
  # then apply to environment directory, then backtrack until found

  def render_mikinugget pagename, paramstxt=nil, mode=nil, format_override=nil
    target_pagename = Environment.page_lookup @page_context, pagename.strip
  
    if target_pagename 
      MikiNugget.new(@page_context, target_pagename, paramstxt, format_override, mode).render(@username)      
    else
      new_pagename = @page_context.sibling(pagename.strip).name
      return %{<a class='uncreated' title='click to create the missing page object' href='/#{new_pagename}'>#{pagename.strip}</a>}
    end    
  end

  def image url
    puts "RENDERER IMAGE !!!!!!!!"
    %{<img src='/#{url}'/>}
  end
  
  def audio url
    puts "RENDERER AUDIO !!!!!!!!"
    %{<BGSOUND src='/#{url}'/>}
  end 
  
  def video url
    puts "RENDERER VIDEO !!!!!!!!"
    %{<video><source src='/#{url}'/></video>}
  end
  
  def files url
    puts "RENDERER FILES !!!!!!!!"
    %{<object data='/#{url}' width="100%" height="100%"/>}
  end
   
  # this code extracts the SCRIPT tags from the text, applies the ML, then puts the SCRIPTs back
  # this is done to NOT do ML substitution *within* the SCRIPT tags
  
  def mikiml rawtxt
        
    scripts = []

    text_with_script_placeholders = rawtxt.gsub /(<script>(.|\n|\r)*?<\/script>)/m do 
      scripts << $1
      "$$$$$$$$"
    end

    sugaredtext = sugar( text_with_script_placeholders )
    markeduptext = ml_basic( sugaredtext )
    expanded_autonuggets = ml_autonuggets(markeduptext)
    final = ml_nuggets(expanded_autonuggets)
    
    # put back the scripts
    i=0
    fully_expanded_text = final.gsub /\$\$\$\$\$\$\$\$/m do      
      substitution = scripts[i]
      i += 1
      substitution
    end
            
    return fully_expanded_text
  end


  def ml_3stars text
    text.gsub /^\*\*\*(([a-z\xC0-\xFF]|.)*)$/ do
      "<h5>#{$1}</h5>".delete("\n").delete("\r")
    end
  end
  
  def ml_2stars text
    text.gsub /^\*\*(([a-z\xC0-\xFF]|.)*)$/ do
        "<h4>#{$1}</h4>".delete("\n").delete("\r")
    end
  end
  
  def ml_1star text
    text.gsub /^\*(([a-z\xC0-\xFF]|.)*)$/ do
       "<h3>#{$1}</h3>".delete("\n").delete("\r")
    end
  end
  
  # def ml_doubleunderscore_around text
  #   # text.gsub /__(([a-z\xC0-\xFF]|.)*)__/ do
  #   text.gsub /__(.*?)__/ do
  #      "<em>#{$1}</em>"
  #   end
  # end
  
  def ml_doublestars_around text
    #text.gsub /\*\*(([a-z\xC0-\xFF]|.)*)\*\*/ do
    text.gsub /\*\*(.*?)\*\*/ do
       "<strong>#{$1}</strong>"
    end
  end

  def ml_newline text
    text.gsub /\n/ do
       "<BR/>"
    end
  end
  
  def ml_basic text
    text1 = ml_doublestars_around(text)
    text2 = ml_3stars(text1)
    text3 = ml_2stars(text2)
    text4 = ml_1star(text3)

    #  removed because it clashes with double underscore in history URLs
    # text5 = ml_doubleunderscore_around(text4)
    
    text6 = ml_newline(text4)
        
    return text6
  end  
  
  # <<xxxxxxx>>
  # <<xxxxxxx:some data format here>>
  
  def ml_nuggets text
    text.gsub /<<(.+?)(:(.+?))?>>/m do     
      render_mikinugget $1, $3
    end
  end

  def find_hosting_folder start_page
    hosting_environment = start_page.environment
    
    if hosting_environment.nil?
      return start_page.parent
    else
      return hosting_environment.child('data')
    end
  end

  # <<xxxxxxx as formatpagename>>
  # <<box001 as toolbox>>
  # <<xxxxxxx as formatpagename:some initial data here>>
  
  def ml_autonuggets text
    # I use [^<>\s] instead of . because otherwise a nugget and an autonugget on the same line got matched together
    # as in this case: <<page001>><BR/><BR/><<page002 as miki:uhm uhm>> 
    text.gsub /<<([^<>\s]+?) as (.+?)(:(.+?))?>>/m do    
      puts "================ ml_autonuggets ===== obj:#{$1} -- format:#{$2} -- init with:#{$4}"
       
      datapage_name = $1
      formatpage_name = $2
      opt_args = $4
      
      hosting_folder = find_hosting_folder(@page_context)
      datapage = hosting_folder.child( datapage_name )

      if not datapage.exists?
        datapage.update formatpage_name, @username, (opt_args || '')
      end

      render_mikinugget datapage_name, nil,nil,formatpage_name
    end
  end

  
    
  def sugar rawtxt
    text2 = include_sugar( rawtxt )
    text3 = expand_sugar( text2 )
    text4 = link_sugar( text3 )
    
    return text4
  end
  
  # [[include:xxxxxx]]
  def include_sugar rawtxt
    rawtxt.gsub /\[\[include:(.+?)\]\]/ do 
      '<<system/bo/include:{"url":"'+$1+'"}>>'
    end
  end

  # [[expand:xxxxxx]]
  def expand_sugar rawtxt
    rawtxt.gsub /\[\[expand:(.+?)\]\]/ do 
      '<<system/bo/expand:{"url":"'+$1+'"}>>'
    end
  end

  # [[xxxxxx]]
  # [[xxxxxx|a cool name]]
  def link_sugar rawtxt
    rawtxt.gsub /\[\[((.+?)\|)?(.+?)\]\]/ do 
      if $2
        '<<system/bo/link:{"text":"'+$2+'","url":"'+$3+'"}>>'
      elsif $3
        '<<system/bo/link:{"url":"'+$3+'"}>>'
      else
        '** SYNTAX ERROR IN LINK **'
      end
    end
  end
  
end
