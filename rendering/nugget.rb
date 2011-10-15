#### Structure of HTML Produced by the nugget ####

# NUGGET mikinugget div ID-NUGGET
#   TRASFORMATION DEF trasformation_function div
#     FUNCTION DEF script
#   TARGET target div ID-TARGET
#   FUNCTION CALL div

# NUGGET mikinugget div ID-NUGGET
#   TRASFORMATION DEF trasformation_function div
#     TEMPLATE_TEXT template_text div ID-TEMPLATE-TEXT
#     FUNCTION DEF script
#   TARGET target div ID-TARGET
#   FUNCTION CALL div

class MikiNugget

  def initialize page_context, pagename, paramstxt='', format_override=nil, mode=nil
    @page_context = page_context
    @paramstxt = paramstxt ? paramstxt.strip.delete("\n").delete("\r") : nil #this allows multiline embedded json comments 
    @data_page_as_content_page = (mode == :data_page_as_content_page) ? 'true' : 'false'
    
    page = Page.get(pagename)
    
    @css_id_uniq = page.css_id_uniq

    p "MikiNugget.init #{page}, #{@paramstxt}, #{@css_id_uniq}"

    @formatpagename = page.format
    @modelpage = page

    if is_stateless_nugget?
      p "MikiNugget.init STATELESS MIKINUGGET"

      @javascript_function_id = page.name_javascript_id 

      if format_override
        @formatpagename = format_override
      end    
      
      @functioncodepage = @modelpage
      @modelpagename    = ''
      @nugget_state_type = 'stateless'
      
    else
      p "MikiNugget.init STATEFUL MIKINUGGET"
      
      @javascript_function_id = page.format_javascript_id 

      if format_override
        @formatpagename = Environment.page_lookup @page_context, format_override
      else
        if not ['javascript','template'].include? @formatpagename
          @formatpagename = Environment.page_lookup @page_context, page.format
        end
      end    

      @functioncodepage = Page.new(@formatpagename) 
      @modelpagename    = @modelpage.name
      @nugget_state_type = 'stateful'
    end
    
    @version = page.metadata()['update']
  end
  
  def render username
    div( 
      :class => 'mikinugget', 
      :title => "mikinugget #{@css_id_uniq}", 
      :inside => div( 
                    :class=>'trasformation_function', 
                    :inside=>trasformation_function( @functioncodepage, @javascript_function_id, username ) 
                 ) +
                 div( 
                    :class => 'target envelope',
                    :id => @css_id_uniq,
                    :pagename => @modelpage.name,
                    :formatpagename => @formatpagename,
                    :state => @nugget_state_type,
                    :data_page_as_content_page => @data_page_as_content_page
                 ) + 
                 javascript(
                    %{ executeNugget(
                        '#{username}',
                        '#{@version}',              //version
                        '#{@modelpagename}',        //datapage
                        '#{@formatpagename}',       //formatpage
                        #{@javascript_function_id}, //function
                        '##{@css_id_uniq}',         //nugget css id
                        '#{@paramstxt}',            //embedded data
                        '#{@modelpage.name}'        //codepage 
                       ); 
                    }
                 )
    )
    
  rescue Exception => e
    return "-- FAILED LOADING MIKINUGGET: #{@modelpagename} : #{e} : #{e.backtrace} --"
  end

private

  def is_stateless_nugget?
    @formatpagename == 'javascript' or @formatpagename == 'template'
  end
    
  def trasformation_function page, javascript_id, username
    case page.format
    when 'javascript' then custom_trasformation_function(page.raw(username), javascript_id)    
    when 'template'   then template_trasformation_function(page.raw(username), javascript_id, page.css_id_uniq)  
    else 
      page.raw(username) 
    end
  end

  def custom_trasformation_function page_text, javascript_id
    javascript %{ 
#{javascript_id} = function(nugget){
#{page_text}
}
    }
  end

  def template_trasformation_function page_text, javascript_id, css_id_uniq
    return div(
              :class=>'template_text', 
              :id => css_id_uniq, 
              :style => 'visibility:hidden; height:0px; width:0px; padding:0px; margin:0px; font-size: 0px;',
              :inside => CGI::escapeHTML(page_text)
           ) +
           templatescript(javascript_id, css_id_uniq)
  end
  
  def javascript txt
    %{
<script type="text/javascript">
  #{txt}
</script>
    }    
  end

  def templatescript javascript_id, css_id_uniq
    javascript( %{ 
#{javascript_id} = function(nugget){ nugget.templateExpansion('##{css_id_uniq}'); } 
    })
  end

  def div opts
    out = "\n<div"
    out += " class='#{opts[:class]}'"                    if opts[:class]
    out += " id='#{opts[:id]}'"                          if opts[:id]
    out += " pagename='#{opts[:pagename]}'"              if opts[:pagename]
    out += " formatpagename='#{opts[:formatpagename]}'"  if opts[:formatpagename]
    out += " state='#{opts[:state]}'"                    if opts[:state]
    out += " data_page_as_content_page='#{opts[:data_page_as_content_page]}'"  if opts[:data_page_as_content_page]
    out += " datapagename='#{opts[:datapagename]}'"                            if opts[:datapagename]
    out += " title='#{opts[:title]}'"                    if opts[:title]
    out += " style='#{opts[:style]}'"                    if opts[:style]
    out += ">\n"
    out += opts[:inside]                                 if opts[:inside]
    out += "\n</div>"
  end
  
end


