require 'fileutils'

class FileProxy
  attr_accessor :path, :name, :is_new

  def initialize(name, path)
    @name = File.basename(name) == name ? name : self.name = File.basename(name)
    @path = path

    if not File.exist? @path
      @is_new = true
    end

  end

  def rename new_path
    File.rename(self.path, new_path)
  end
  
  def delete
    FileUtils.rm_r self.path
  end
  
  def content= txt
    make_full_filepath_if_not_already_there(self.path)
    File.open(self.path,"w") do |file|
     file << txt
    end
  end
  
private
  def make_full_filepath_if_not_already_there thepath
    File.makedirs( File.dirname(thepath) ) 
  end
  
end

