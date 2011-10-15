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


# ary = [
#   {:name=>'john',:surname=>'locke'},
#   {:name=>'marta',:surname=>'locke'},
#   {:name=>'simon',:surname=>'stewart'},
#   {:name=>'emma',:surname=>'locke'},
#   {:name=>'marta',:surname=>'locke'}
# ]
# p ary
# p ary.uniq
# p ary.uniq_by{|e| e[:surname]}
