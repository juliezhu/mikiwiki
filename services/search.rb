
def search_pages keyword
  path = "public/pages/*"

  r_content = `grep -r -l #{keyword} #{path} | grep -v "__"  | grep -v "_metadata.txt"`.
              split("\n")
              # .
              # map{|e| e.gsub("public/pages/","")}
              
  r_files = `find -f #{path} -name "*#{keyword}*" | grep -v "__"  | grep -v "_metadata.txt"`.
             split("\n")
             # .
             # map{|e| e.gsub("public/pages/","")}

  r = r_content + r_files
  
  return r.uniq
end

# grep -r "tags:" . | grep -v "__" | grep "_metadata.txt"

