local events = {}
function events.CentralSceneEvent(id,keyId,keyAttribute)
  return {type='CentralSceneEvent',data={id=id,keyId=keyId,keyAttribute=keyAttribute}}
end
function events.AlarmPartitionArmedEvent(partitionId)
  return {type='AlarmPartitionArmedEvent', data={partitionId=partitionId}}
end
function events.AlarmPartitionBreachedEvent(partitionId)
  return {type='AlarmPartitionBreachedEvent', data={partitionId=partitionId}}
end
function events.HomeArmStateChangedEvent(partitionId)
  return {type='HomeArmStateChangedEvent', data={partitionId=partitionId}}
end
function events.HomeBreachedEvent()
  return {type='HomeBreachedEvent', data={}}
end
function events.WeatherChangedEvent(change,newValue)
  return {type='WeatherChangedEvent', data={change=change,newValue=newValue}}
end
function events.GlobalVariableChangedEvent(variableName,newValue,oldValue)
  return {type='GlobalVariableChangedEvent', data={variableName=variableName,oldValue=oldValue,newValue=newValue}}
end
function events.GlobalVariableAddedEvent(variableName,value)
  return {type='GlobalVariableAddedEvent', data={variableName=variableName,value=value}}
end
function events.GlobalVariableRemovedEvent(variableName)
  return {type='GlobalVariableRemovedEvent', data={variableName=variableName}}
end
function events.SceneActivationEvent(id,sceneId)
  return {type='SceneActivationEvent', data={id=id,sceneId=sceneId}}
end
function events.AccessControlEvent(id)
  return {type='AccessControlEvent', data={id=id}}
end
function events.CustomEvent(name,userDescription)
  return {type='CustomEvent', data={name=name,userDescription=userDescription}}
end
function events.PluginChangedViewEvent(deviceId,propertyName,newValue)
  return {type='PluginChangedViewEvent', data={deviceId=deviceId,propertyName=propertyName,newValue=newValue}}
end
function events.WizardStepStateChangedEvent()
  return {type='WizardStepStateChangedEvent', data={}}
end
function events.UpdateReadyEvent(isReady)
  return {type='UpdateReadyEvent', data={isReady=isReady}}
end
function events.DevicePropertyUpdatedEvent(id,property,newValue)
  return {type='DevicePropertyUpdatedEvent', data={id=id,property=property,newValue=newValue}}
end
function events.DeviceRemovedEvent(id)
  return {type='DeviceRemovedEvent', data={id=id}}
end
function events.DeviceChangedRoomEvent(id)
  return {type='DeviceChangedRoomEvent', data={id=id}}
end
function events.DeviceCreatedEvent(id)
  return {type='DeviceCreatedEvent', data={id=id}}
end
function events.DeviceModifiedEvent(id)
  return {type='DeviceModifiedEvent', data={id=id}}
end
function events.PluginProcessCrashedEvent(id,error)
  return {type='PluginProcessCrashedEvent', data={id=id,error=error}}
end
function events.SceneStartedEvent(id)
  return {type='SceneStartedEvent', data={id=id}}
end
function events.SceneFinishedEvent(id)
  return {type='SceneFinishedEvent', data={id=id}}
end
function events.SceneRunningInstancesEvent(id)
  return {type='SceneRunningInstancesEvent', data={id=id}}
end
function events.SceneRemovedEvent(id)
  return {type='SceneRemovedEvent', data={id=id}}
end
function events.SceneModifiedEvent(id)
  return {type='SceneModifiedEvent', data={id=id}}
end
function events.SceneCreatedEvent(id)
  return {type='SceneCreatedEvent', data={id=id}}
end
function events.OnlineStatusUpdatedEvent()
  return {type='OnlineStatusUpdatedEvent', data={}}
end
function events.ActiveProfileChangedEvent()
  return {type='ActiveProfileChangedEvent', data={}}
end
function events.ClimateZoneChangedEvent()
  return {type='ClimateZoneChangedEvent', data={}}
end
function events.ClimateZoneSetpointChangedEvent()
  return {type='ClimateZoneSetpointChangedEvent', data={}}
end
function events.ClimateZoneTemperatureChangedEvent()
  return {type='ClimateZoneTemperatureChangedEvent', data={}}
end
function events.NotificationCreatedEvent(id)
  return {type='NotificationCreatedEvent', data={id=id}}
end
function events.NotificationRemovedEvent(id)
  return {type='NotificationRemovedEvent', data={id=id}}
end
function events.NotificationUpdatedEvent(id)
  return {type='NotificationUpdatedEvent', data={id=id}}
end
function events.RoomCreatedEvent(id)
  return {type='RoomCreatedEvent', data={id=id}}
end
function events.RoomRemovedEvent(id)
  return {type='RoomRemovedEvent', data={id=id}}
end
function events.RoomModifiedEvent(id)
  return {type='RoomModifiedEvent', data={id=id}}
end
function events.CustomEventCreatedEvent(name)
  return {type='CustomEventCreatedEvent', data={name=name}}
end
function events.CustomEventRemovedEvent(name)
  return {type='CustomEventRemovedEvent', data={name=name}}
end
function events.CustomEventModifiedEvent(name)
  return {type='CustomEventModifiedEvent', data={name=name}}
end
function events.SectionCreatedEvent(id)
  return {type='SectionCreatedEvent', data={id=id}}
end
function events.SectionRemovedEvent(id)
  return {type='SectionRemovedEvent', data={id=id}}
end
function events.SectionModifiedEvent(id)
  return {type='SectionModifiedEvent', data={id=id}}
end
function events.QuickAppFilesChangedEvent()
  return {type='QuickAppFilesChangedEvent', data={}}
end
function events.ZwaveDeviceParametersChangedEvent()
  return {type='ZwaveDeviceParametersChangedEvent', data={}}
end
function events.ZwaveNodeAddedEvent()
  return {type='ZwaveNodeAddedEvent', data={}}
end
function events.ZwaveNodeWokeUpEvent()
  return {type='ZwaveNodeWokeUpEvent', data={}}
end
function events.ZwaveNodeWentToSleepEvent()
  return {type='ZwaveNodeWentToSleepEvent', data={}}
end
function events.RefreshRequiredEvent()
  return {type='RefreshRequiredEvent', data={}}
end
function events.DeviceFirmwareUpdateEvent()
  return {type='DeviceFirmwareUpdateEvent', data={}}
end
function events.GeofenceEvent()
  return {type='GeofenceEvent', data={}}
end
function events.DeviceActionRanEvent(id,actionName)
  return {type='DeviceActionRanEvent', data={id=id,actionName=actionName}}
end
function events.PowerMetricsChangedEvent(consumptionPower,productionPower)
  return {type='PowerMetricsChangedEvent', data={consumptionPower=consumptionPower,productionPower=productionPower}}
end
function events.DeviceNotificationState()
  return {type='DeviceNotificationState', data={}}
end
function events.DeviceInterfacesUpdatedEvent(id)
  return {type='DeviceInterfacesUpdatedEvent', data={id=id}}
end
function events.EntitiesAmountChangedEvent()
  return {type='EntitiesAmountChangedEvent', data={}}
end
function events.ActiveTariffChangedEvent(newTariff)
  return {type='ActiveTariffChangedEvent', data={newTariff=newTariff}}
end
function events.UserModifiedEvent(id)
  return {type='UserModifiedEvent', data={id=id}}
end
function events.SprinklerSequenceStartedEvent(sequenceId)
  return {type='SprinklerSequenceStartedEvent', data={sequenceId=sequenceId}}
end
function events.SprinklerSequenceFinishedEvent(sequenceId)
  return {type='SprinklerSequenceFinishedEvent', data={sequenceId=sequenceId}}
end
function events.DeviceGroupActionRanEvent(actionName)
  return {type='DeviceGroupActionRanEvent', data={actionName=actionName}}
end
-- end of events

return events