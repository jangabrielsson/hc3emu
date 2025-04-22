_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=MyQA_LL
--%%proxy=Foo
--%%type=com.fibaro.binarySwitch  
--%%state=LL.db
--%%debug=db:true


function QuickApp:onInit()
  self.store = setmetatable({},{
    __index = function(t,key) return self:internalStorageGet(key) end,
    __newindex = function(t,key,val)
      if val == nil then self:internalStorageRemove(key)
      else self:internalStorageSet(key,val) end
    end
  })

  if self.store.first_time == nil then   ----       ~=
    --if 0 == 0 then
    -------
    
    -------
    self.store.Heat_val = 20
    self.store.Eco_val = 20
    self.store.Vac_val = 20
    
    -------
    self.store.mode_select_var_trigger = "off"
    self.store.profile_selected_trigger = nil
    
    self.store.tempdevice_select_trigger = nil
    self.store.Select_tempdevice_list_trigger = nil
    -------
    self.store.device_energy = ""
    self.store.device_energy_hour = ""
    self.store.device_energy_lasthour = ""
    self.store.device_energy_daily = ""
    self.store.device_energy_lastday = ""
    self.store.device_energy_weekly = ""
    self.store.device_energy_monthly = ""
    self.store.device_energy_lastmonth = ""
    self.store.device_energy_year = ""
    self.store.first_time_energy = true
    -------
    self.store.Price_status = true
    self.store.Price_val = 0
    self.store.Power_status = true
    self.store.Power_val = 0
    
    -------
    
    self.store.kbc_val_max = "0.0001"
    self.store.cpp_val_max = "0.0001"
    self.store.kb_val_max = "0.0001"
    -------
    self.store.first_time = "First time Installation is Done"
    print(self.store.first_time)
  end---if self.store.first_time == nil then 
end