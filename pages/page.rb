require 'ftools'

require 'pages/fileproxy'
require 'rendering/renderer'
require 'services/environment'
require 'services/authentication'

# TXT extension
#  
# @singlename         : bar 
# @name               : foo/bar 
# @ext                : txt 
# @fullname           : pages/foo/bar 
# @fullname_plus_base : public/pages/foo/bar 
# @filename           : foo/bar.txt 
# @full_filepath      : public/pages/foo/bar.txt 
# ???                 : pages/foo/bar.txt 
# 
# @metadata_name          : foo/bar_metadata 
# @metadata_filename      : foo/bar_metadata.txt
# @full_metadata_filepath : public/pages/foo/bar_metadata.txt

# OTHER extension
#  
# @singlename         : bar.png
# @name               : foo/bar.png 
# @ext                : png 
# @fullname           : pages/foo/bar.png 
# @fullname_plus_base : public/pages/foo/bar.png 
# @filename           : foo/bar.png 
# @full_filepath      : public/pages/foo/bar.png 
# ???                 : pages/foo/bar.png 
# 
# @metadata_name          : foo/bar.png_metadata 
# @metadata_filename      : foo/bar.png_metadata.txt
# @full_metadata_filepath : public/pages/foo/bar.png_metadata.txt


class Page

  @@resources_basedir = 'public'
  @@pages_dir         = 'pages'
  @@pages_basedir     = "#{@@resources_basedir}/#{@@pages_dir}"

  include PageAuthentication
  
  ######### CLASS ########### 
  
  def self.get name
    Page.new name
  end

  def self.root
    Page.get ''
  end

  def self.delete name
    Page.get(name).delete
  end

  def self.update name, format, username, content=nil
    Page.get(name).update format, username, content
  end

  def self.from_path p
    p2 = p["#{@@pages_basedir}/".size..-1]
    
    if p2.end_with? '.txt'
      p3 = p2[0..-('.txt'.size+1)]
    else
      p3 = p2
    end
    
    return Page.get(p3)
  end
  
  ######### INIT ########### 
  
  def initialize name
    if name =~ /(.*)\.(...)$/
      @name = "#{$1}.#{$2}"
      @ext = $2
      @filename = @name
    else
      @name = name
      @ext = 'txt'
      @filename = "#{@name}.txt"
    end

    @singlename = @name.split('/')[-1] || ''
    
    # adding tag content to the meta-date file
    @metadata_filename = "#{@name}_metadata.txt"
    @metadata_name = "#{name}_metadata"
    
    @full_filepath = "#{@@pages_basedir}/#{@filename}".squeeze('/')
    @full_metadata_filepath = "#{@@pages_basedir}/#{@metadata_filename}"

    @fullname = "#{@@pages_dir}/#{@name}".squeeze('/')
    @fullname_plus_base = "#{@@pages_basedir}/#{@name}".squeeze('/')

    @pagefile     = FileProxy.new(@name, @full_filepath)
    @pagemetadata = FileProxy.new(@metadata_name, @full_metadata_filepath)

    @pagetype = if File.directory?(@fullname_plus_base)
                  @ext = ''
                  @pagemetadata = nil
                  @full_metadata_filepath = nil
                  :directory
                elsif @ext == 'txt'  
                  :text     
                else  
                  :resource
                end
  end

  ######### ATTRIBUTES ################################################################## 

  attr_accessor :name, :fullname, :fullname_plus_base, :pagetype, 
                :ext, :filename, :full_filepath, :full_metadata_filepath,
                :singlename
  
  def name_from base_page
    if base_page.root?
      self.name
    elsif self.name.start_with? base_page.name
      self.name[(base_page.name.size+1)..-1]
    else
      self.name
    end
  end
  
  # for non-text pages, it could just read the file extension..
  def format
    metadata()['format']
  rescue
    puts "No format info found"
    return ''
  end
  
  def metadata_as_json
    JSON.dump( metadata() )
  end
  
  def metadata
    YAML.load( File.read(@pagemetadata.path) )
  rescue
    # puts "No metadata found"
    raise :no_metadata_found
  end

  def has_metadata?
    puts "$$$$$$$$$$$$ CHECKING #{@pagemetadata.path}"
    puts (not @pagemetadata.is_new)
    puts "$$$$$$$$$$$$$$$"
    
    return (not @pagemetadata.is_new)
  end
  # tags: xxxx,yyyy,zzzz
      
  def timestamp
    return self.metadata['update'].to_f    
  end
  
  ######### HTML IDs ################################################################## 

  def css_id_uniq
    "#{css_id}-#{Time.now.to_f.to_s.gsub('.','')}"
  end

private
  def css_id
    format.gsub('/','-') + '-' + fullname.gsub('/','-')
  end
public

  def format_javascript_id
    format.gsub('/','_').gsub('-','_')
  end

  def name_javascript_id
    self.name.gsub('/','_').gsub('-','_')
  end
    
  ######### Qs ################################################################## 
  
  def root?
    self.name == ''
  end

  def is_root?
    root?
  end
  
  def is_new?
    p "PAGE IS NEW? #{@pagefile.name} #{@pagefile.path}"
    @pagefile.is_new
  end

  def exist?
    not is_new?
  end

  alias exists? exist?
  
  def is_directory?  
    @pagetype == :directory
  end

  def is_resource?  
    @pagetype == :resource
  end
  
  def is_text?
    @pagetype == :text
  end
  
  def is_environment?
    is_directory? and child('environment').exist?
  end

  def is_leaf?
    not is_directory?
  end
  
  def is_content?
    ( ['raw','json','miki'].include? self.format ) or self.is_media?
  end

  def is_code?
    ['javascript','template'].include? self.format 
  end
   
  def is_media?
      ['png','jpg','gif','bmp','JPG','PNG','BMP','GIF', 'jpeg','pdf','PDF','ppt','PPT', 'wav','wma','wave','au','avi','mp3','mov','m4v','mpeg','swf','wmv','mp4', 'M4V'].include? self.format
  end
  
  def is_history_folder?
    singlename =~ /^__.*/ ? true : false   
  end
  
  def is_history_file?
    parent.is_history_folder?
  end

  def is_history?
    return is_history_folder? if is_directory?
    return is_history_file?
  end

  def has_history?
    has_history_folder?
  end

  
  ######### NAVIGATION ################################################################## 
  
  def closer_directory_name
    if self.is_directory?
      self.name
    else
      self.parentname
    end
  end
  
  def parent
    Page.get(parentname)
  end
  
  def parentname
    return self.name.split('/')[0..-2].join('/')
  end
  
  def child childname
    Page.get("#{self.name}/#{childname}")  
  end
  
  def sibling siblingname
    self.parent.child(siblingname)
  end

  def environment
    return self if is_environment?
    return nil  if root?
    # return self  if root?
    
    parent.environment
  end
  
  def get_environments username
    Environment.parent_environments(self,username)
  end
    
  ######### FILES ################################################################## 
  
  def filelist
    return all_txt_descendant.map{|a_path| Page.from_path(a_path) }
  end

  def all_firstlevel
    return all_children.map{|a_path| Page.from_path(a_path) }
  end

  private
      def all_txt_descendant
        remove_front_slash( remove_hidden_files( (Dir["#{self.fullname_plus_base}/**/*.*"].sort) ) )
      end

      def all_children
        remove_front_slash( remove_hidden_files( Dir["#{self.fullname_plus_base}/*"].sort ) )
      end

      def remove_hidden_files ary
        ary.reject{|name| name =~ /.*_metadata.txt/}.
            reject{|name| name.split('/').last =~ /^__.*/}
      end
      
      def remove_front_slash ary
        ary.map{|name| name.start_with?('/') ? name[1..-1].squeeze('/') : name.squeeze('/') }
      end
  public
  
  ######### HTML ################################################################## 
  
  def linkable_path 
    individual_paths = []

    for part in self.name.split('/')
      individual_paths << ((individual_paths.last || '') + '/' + part)
    end

    html = []
    html << "<a href='/' class='path-link home-link'>home</a>"

    for p in individual_paths
      html << "<a href='" + p + "' class='path-link sub-link'>" + p.split('/').last + "</a>"
    end

    return html.join('/')
  end

  def edit_url
    '/'+self.name + "/edit"
  end

  ######### RENDER ################################################################## 

  def render_as_code_block username
    "<PRE><CODE>#{CGI.escapeHTML(self.render(username))}</CODE></PRE>"
  end

  # This should be called when a Data Page is rendered
  def render_data_page_as_content_page username
    Renderer.new( File.read(@pagefile.path), self, username ).render_data_page_as_content_page(self.format)
  end
  
  def render username
    render_file(@pagefile,self.format, username)
  end

  def raw username
    render_file( @pagefile,'raw', username )
  end

  def json username
    render_file( @pagefile,'json', username )
  end
  
  private

    def strip_public a_path
      a_path["public/".size..-1]
    end
    
    def render_file file, format, username
      if self.is_media?
        Renderer.new( strip_public(file.path), self, username ).render(format)
      else
        Renderer.new( File.read(file.path), self, username ).render(format)
      end
    end

  public
  
  ######### ACTIONS ################################################################## 

  def rename new_name
    if is_directory?
      new_path = Page.get(new_name).fullname_plus_base
      FileProxy.new(@name, @fullname_plus_base).rename new_path
    else
      # if not is_history? and has_history_folder?
      #   history_folder().rename sibling("__#{new_name}").name
      # end
      
      new_path = Page.get(new_name).full_filepath
      @pagefile.rename new_path
      
      new_metadata_path = Page.get(new_name).full_metadata_filepath
      @pagemetadata.rename new_metadata_path
      
    end
  end
  
  def clone_from original_page
    if original_page.is_directory?
      FileUtils.cp_r original_page.fullname_plus_base, self.fullname_plus_base
    else
      # copy page
      FileUtils.cp_r original_page.full_filepath, self.full_filepath
      # copy metadata too
      FileUtils.cp_r original_page.full_metadata_filepath, self.full_metadata_filepath
    end
  self end
  
  def name_of_clone
    if is_resource? 
      # insert '-clone' before the file extension
      parts = self.name.split('.')
      "#{parts[0..-2].join('.')}-clone.#{parts[-1]}"
    else
      "#{self.name}-clone"
    end
  end
  
  def make_folder!
    File.makedirs self.fullname_plus_base
  self end

  def set_content newcontent, username
    self.update self.format, username, newcontent
  end
  
  def update format, username, content
    if has_metadata?
      previous_metadata = metadata()
    else
      previous_metadata = { }
    end
    
    add_to_history! unless is_new? or is_history?

    @pagefile.content = content if content
    
    previous_metadata['format'] = format
    previous_metadata['user'] = username
    
    update_metadata! previous_metadata
  self end
  
  def update_metadata! new_metadata
    new_metadata['update'] = Time.now
    
    @pagemetadata.content = YAML.dump(new_metadata)
  end

  def update_tags! tags
    current_metadata = metadata()
    current_metadata['tags'] = tags
    
    @pagemetadata.content = YAML.dump(current_metadata)
  end

  ######### HISTORY ################################################################## 

private
  def add_to_history!
    create_history_folder! unless has_history_folder?
    
    self.rename history_folder().child( next_version_name() ).name 
  end

  def create_history_folder!
    File.makedirs( history_folder().fullname_plus_base ) 
  end
  
  def has_history_folder?
    File.exist? history_folder().fullname_plus_base
  end

  def history_folder
    parent().child('__' + self.singlename) 
  end

  def next_version_name
    # puts "history_folder(): #{history_folder().name}"
    # puts "ALL VERSIONS alpha: #{history_folder().all_firstlevel.map{|p| p.name }.join('|')}"
    all_versions = history_folder().all_firstlevel.map{|p| p.singlename }

    # puts "ALL VERSIONS: #{all_versions.join('|')}"
    
    if all_versions.empty?
      "000001"
    else
      # puts "LAST VERSION: #{all_versions.sort.last.to_i}"
      (all_versions.sort.last.to_i + 1).to_s.rjust(6,'0')
    end
  end
  
public
  
  def delete
    # instead of deleting... historicize
    
    if is_directory?      
      self.rename sibling("__#{singlename}").name
    else 
      create_history_folder! unless has_history_folder?
      self.rename history_folder().child( next_version_name() ).name 
    end
  end

  def real_delete
    if is_directory?      
      FileProxy.new(@name, @fullname_plus_base).delete
    else 
      @pagefile.delete
      @pagemetadata.delete 
    end
  end

  def upload_resource( bytestream, username )
    File.open(self.fullname_plus_base, "wb") { |f| f.write(bytestream) }

    resource_format = is_text? ? format() : @ext

    self.update_metadata! 'format'=>resource_format, 'user'=>username
  self end

 
end

