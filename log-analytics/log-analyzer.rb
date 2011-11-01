
# 
# 
# WE CHANGED THE LOGGER... SO THIS FILE IS OUT OF DATE... WE NEED TO UPDATE THE ANALYTICS
# 
# 

def minutes m
  m*60
end

def hours h
  minutes(h*60)
end

class Entry
  # LOG ENTRIES look like this:
  # I, [2011-10-29T21:43:45.533783 #21230]  INFO -- : Sat Oct 29 21:43:45 +0200 2011|admin|ROOT|bo/_help|miki|/bo/_help|/bo/_help?nolayout=y&currentpagename=local|nolayout=y&currentpagename=local|read_no_layout|ajax|
  # Mon Apr 18 10:19:21 -0700 2011|julie|demos/iPhone_mock|demos/iPhone_mock||/demos/iPhone_mock|/demos/iPhone_mock||read|page|
  attr_accessor :timetxt, :user, :environment, :pagename, :format, :path, :fullpath, :query, :actiontype, :calltype

  def initialize fields
    @timetxt, @user, @environment, @pagename, @format, @path, @fullpath, @query, @actiontype, @calltype = *fields
  end
  
  def to_s
    [@timetxt, @user, @environment, @pagename, @format, @path, @fullpath, @query, @actiontype, @calltype].join ' | '
  end
  
  def time
    weekday, month, day, time, zone, year = @timetxt.split(' ')
    hour,min,sec = time.split(':')
    return Time.utc(year,month,day,hour,min,sec)
  end
end


class Group
  attr_accessor :entries # WARNING: It always assumes all the entries are in chronological order
  
  def initialize entries=[ ]
    @entries = entries
  end
  
  def Group.load filename
    puts "Loading #{filename} .."
    text = File.read filename
    lines = text.split("\n")

    entries = []
    lines.each do |line|
      if not line[0].chr == '#' 
        logger_header, logger_info = line.split(' -- : ')
        fields = logger_info.split('|')
        entries << Entry.new( fields )
      end
    end    
    
    puts "Parsing #{filename} done."
    
    return Group.new(entries)
  end
  
  def users
    @entries.map{|e| e.user}.uniq
  end

  def entries_by user
    Group.new( @entries.select{|e| e.user == user} )
  end
  
  def within_environment path
    Group.new( @entries.select{|e| e.environment == path} )
  end

  def not_ajax
    Group.new( @entries.reject{|e| e.calltype == 'ajax'} )
  end

  def modifying_actions
    Group.new( @entries.reject{|e| e.actiontype == 'read' or e.actiontype == 'read_no_layout'} )
  end
  
  def modifying_update
    Group.new( @entries.select{|e| e.actiontype == 'update'} )
  end

  def reading
    Group.new( @entries.select{|e| e.actiontype == 'read'} )
  end
  
  def code_pages
    Group.new(@entries.select{|e| e.format == 'javascript' or e.format == 'template'})
  end
  
  def to_s
    @entries.join "\n"
  end
  
  def size
    @entries.size
  end

  # WARNING: It always assumes you put entries in chronological order   
  def << entry
    @entries << entry
  end

  # A session is a period of time that has entries without any long time gap
  # If you have long enough gaps, then you have 2 different sessions
  def sessions_by_gap gap
    sessions = []

    sessions << Group.new() if sessions.size.zero? and not @entries.size.zero?

    for entry in @entries
      if sessions.last.size.zero?
        sessions.last << entry
      else
        if (entry.time - sessions.last.entries.last.time) > gap 
          sessions << Group.new( [ entry ] )
        else
          sessions.last << entry
        end
      end

    end
  
    return sessions
  end
  
  end


exit

g = Group.load '../data/activity.log'

# all users
puts g.users.join ','

# all of francesca's logs
puts g.entries_by('francesca').size

# all logs within the environment BlueTurtle
puts g.within_environment('BlueTurtle')

# how many direct calls did francesca do within the environment BlueTurtle?
puts g.entries_by('francesca').within_environment('BlueTurtle').not_ajax.size

# all direct modifications that francesca did to code pages within the environment BlueTurtle
puts g.entries_by('francesca').within_environment('BlueTurtle').not_ajax.modifying_actions.code_pages

# get all sessions with a max 30m gap done by francesca within the environment BlueTurtle.
# consider only direct calls and not ajax calls.. so if francesca had mikiwiki open
# with some ajax polling in the background, it should be ignored
sessions = g.entries_by('francesca').within_environment('BlueTurtle').not_ajax.sessions_by_gap( minutes(30) )

# print some stuff about all of francesca's sessions
for s in sessions
  puts "==================="
  puts "num entries #{s.size}"
  puts "start at #{s.entries.first.time}"
  puts "end at #{s.entries.last.time}"
  puts "duration minutes #{(s.entries.last.time - s.entries.first.time)/60}"
end

# check the sessions of all users
g = Group.load 'user-logs_summary.txt'
for user in g.users
 user_sessions = g.entries_by(user).not_ajax.sessions_by_gap( minutes(30) )
 puts "#{user} did #{user_sessions.size} sessions"
end





