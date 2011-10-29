require 'logger'  

class Array
  def uniq_by(&blk)
    transforms = []
    self.select do |el|
      should_keep = !transforms.include?(t=blk[el])
      transforms << t
      should_keep
    end
  end
end


def log username, request, params, page, action, is_ajax=nil

  return if not $MIKI_LOGGER

  datetime = Time.now
  user = username

  if page.environment
    environment = page.environment.name
    environment = "ROOT" if environment == '' 
  else
    environment = "ROOT"
  end
  
  pagename = page.name
  format = page.format # SHOULD create special format if it is a directory!
  path = request.path_info
  fullpath = request.fullpath

  if fullpath.include? '?'
    query = fullpath.split('?')[1..-1].join
  else
    query = ''
  end

  action_type = action
  call_type = is_ajax ? 'ajax' : 'page'

  $MIKI_LOGGER.info "#{datetime}|#{user}|#{environment}|#{pagename}|#{format}|#{path}|#{fullpath}|#{query}|#{action_type}|#{call_type}|"
end
