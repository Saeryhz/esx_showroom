ESX	= nil
local PlayerData = {}
local CurrentAction = nil
local CurrentActionData = {}
local HasAlreadyEnteredMarker = false
local LastZone = nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end

	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(10)
	end

	PlayerData = ESX.GetPlayerData()
end)

AddEventHandler('esx_showroom:hasEnteredMarker', function(zone)
	CurrentAction     = 'get_vehicle_out'
	CurrentActionMsg  = _U('get_vehicle_out')
	CurrentActionData = {zone = zone}
end)

AddEventHandler('esx_showroom:hasExitedMarker', function(zone)
	CurrentAction = nil
	ESX.UI.Menu.CloseAll()
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	PlayerData.job = job
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(10)
		if PlayerData.job ~= nil and PlayerData.job.name == 'cardealer' then		
			local coords = GetEntityCoords(GetPlayerPed(-1))

			for k,v in pairs(Config.Zones) do
				for i = 1, #v.Pos, 1 do
					if(Config.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos[i].x, v.Pos[i].y, v.Pos[i].z, true) < Config.DrawDistance) then
						DrawMarker(Config.Type, v.Pos[i].x, v.Pos[i].y, v.Pos[i].z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.Size.x, Config.Size.y, Config.Size.z, Config.Color.r, Config.Color.g, Config.Color.b, 150, false, true, 2, true, false, false, false)
					end
				end
			end
			
			if(Config.Type ~= -1 and GetDistanceBetweenCoords(coords, Config.VehicleDeleter[1].x, Config.VehicleDeleter[1].y, Config.VehicleDeleter[1].z, true) < Config.DrawDistance) then
				DrawMarker(Config.Type, Config.VehicleDeleter[1].x, Config.VehicleDeleter[1].y, Config.VehicleDeleter[1].z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.Size.x, Config.Size.y, Config.Size.z, 200, 0, 0, 150, false, true, 2, true, false, false, false)
				local dist = Vdist(coords.x, coords.y, coords.z, Config.VehicleDeleter[1].x, Config.VehicleDeleter[1].y, Config.VehicleDeleter[1].z)
				if dist <= 1.5 then
					DrawTxt(_U('delete_vehicles'))
					if IsControlJustPressed(1,51) then 
						DeleteShowroomVehicles()
					end
				end
			end
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(10)
		if PlayerData.job ~= nil and PlayerData.job.name == 'cardealer' then
			local coords      = GetEntityCoords(GetPlayerPed(-1))
			local isInMarker  = false
			local currentZone = nil

			for k,v in pairs(Config.Zones) do
				for i = 1, #v.Pos, 1 do
					if(GetDistanceBetweenCoords(coords, v.Pos[i].x, v.Pos[i].y, v.Pos[i].z, true) < Config.Size.x) then
						isInMarker  = true
						currentZone = k
						LastZone    = k
					end
				end
			end
			if isInMarker and not HasAlreadyEnteredMarker then
				HasAlreadyEnteredMarker = true
				TriggerEvent('esx_showroom:hasEnteredMarker', currentZone)
			end
			if not isInMarker and HasAlreadyEnteredMarker then
				HasAlreadyEnteredMarker = false
				TriggerEvent('esx_showroom:hasExitedMarker', LastZone)
			end
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(10)
		if CurrentAction ~= nil then

			SetTextComponentFormat('STRING')
			AddTextComponentString(CurrentActionMsg)
			DisplayHelpTextFromStringLabel(0, 0, 1, -1)

			if IsControlJustReleased(0, 38) or (IsControlJustReleased(0, 175) and not IsInputDisabled(0)) then
				if CurrentAction == 'get_vehicle_out' then
					PutVehicleInShowroom()		
				end
				CurrentAction = nil	
			end
		else
			Citizen.Wait(500)
		end
	end
end)

function PutVehicleInShowroom()
	local vehicleModel = nil
	for k,v in pairs(Config.Zones) do
		for i = 1, #v.Pos, 1 do
			if(LastZone == k) then
				if v.Pos[i].isAvailable then
					if not DoesEntityExist(GetClosestVehicle(v.Pos[i].x + 2.5, v.Pos[i].y - 0.2, v.Pos[i].z, 1.5, 0, 70)) then
							ESX.TriggerServerCallback('esx_showroom:getCars', function(cars)
								local elements = {}			
								for i=1, #cars, 1 do
									table.insert(elements, {label = cars[i].name, value = cars[i].model})
								end
								
								ESX.UI.Menu.CloseAll()							
								ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'showroom', {
									title    = _U('menu_title'),
									align    = 'top-left',
									elements = elements
								}, function(data, menu)
									menu.close()
									
									vehicleModel = data.current.value
									RequestModel(vehicleModel)
									while not HasModelLoaded(vehicleModel) do
										Citizen.Wait(10)
									end

									local vehicle = CreateVehicle(vehicleModel, v.Pos[i].x + 2.5, v.Pos[i].y - 0.2, v.Pos[i].z,  v.Pos[i].h, true, true)
									local id = NetworkGetNetworkIdFromEntity(vehicle)
									SetVehicleNumberPlateText(vehicle, 'Araziz')
									SetEntityAsMissionEntity(vehicle, true)
									SetVehicleOnGroundProperly(vehicle)
									SetVehicleHasBeenOwnedByPlayer(vehicle, true)
									SetNetworkIdCanMigrate(id, true)
									SetVehRadioStation(vehicle, "OFF")
									SetVehicleDirtLevel(vehicle, 0.0)
									FreezeEntityPosition(vehicle, true)
									v.Pos[i].isAvailable = false									
								end, function(data, menu)
									menu.close()
								end)
							end)
					else
						ESX.ShowAdvancedNotification('Showroom', false, _U('vehicle_blocking'), 'CHAR_CARSITE2', 1, false, true, 140)
					end
				else
					local vehicleToDelete = GetClosestVehicle(v.Pos[i].x + 2.5, v.Pos[i].y - 0.2, v.Pos[i].z, 1.5, 0, 70)
					if DoesEntityExist(vehicleToDelete) then
						DeleteVehicle(vehicleToDelete)
						v.Pos[i].isAvailable = true
					end			
				end
			end
		end
	end
end

function DeleteShowroomVehicles()
	for k,v in pairs(Config.Zones) do
		for i = 1, #v.Pos, 1 do
			local vehicleToDelete = GetClosestVehicle(v.Pos[i].x + 2.5, v.Pos[i].y - 0.2, v.Pos[i].z, 1.5, 0, 70)
			if DoesEntityExist(vehicleToDelete) then
				DeleteVehicle(vehicleToDelete)
				v.Pos[i].isAvailable = true	
			end	
		end
	end
	ESX.ShowAdvancedNotification('Showroom', false, _U('vehicles_deleted'), 'CHAR_CARSITE2', 1, false, true, 140)
end

function DrawTxt(text)
	SetTextComponentFormat('STRING')
	AddTextComponentString(text)
	DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end