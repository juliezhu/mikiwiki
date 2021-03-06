def search_pages keyword
  path = "public/pages/*"

  r_content = `grep -r -l #{keyword} #{path} | grep -v "__"  | grep -v "_metadata.txt"`.
              split("\n")

  r_files = `find -f #{path} -name "*#{keyword}*" | grep -v "__"  | grep -v "_metadata.txt"`.
             split("\n")

  r_tags = search_tags keyword

  r = r_tags + r_files + r_content 
  
  return r.uniq
end


def search_tags keyword
  path = "public/pages/*"

  r_tags = `grep -r -l "tags:.*#{keyword.strip}.*" #{path} | grep -v "__" | grep "_metadata.txt"`.
           split("\n").map{|filename| filename.gsub('_metadata','') }

  return r_tags.uniq
end


