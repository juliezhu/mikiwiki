require 'pony'

class MikiNotify
  
  def self.notify_by_email users, subject, body
    users.each do |user|
      puts ">>>>>>>>>>>>>>>>>>>>> SENDING EMAIL"
      Pony.mail :to => user['email'],
                :from => "contact@mikiwikiproject.com",
                :subject => subject,
                :body => body
      puts ">>>>>>>>>>>>>>>>>>>>> EMAIL HAS BEEN SENT!!!"
    end    
  end
  
end