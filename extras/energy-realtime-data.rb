
post "/energypush" do
  
  log_txt = JSON.dump({
    'Amp' => params['Amp'] ,
    'Watt' => params['Watt']  
  })
      
  energypage_path = 'public/pages/data/energy.txt'
  File.open(energypage_path,"w") do |file|
    file << log_txt
  end   
          
end
