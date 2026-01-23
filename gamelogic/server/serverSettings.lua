function server.start(settings)
    server.setTimeSetting(settings)
	server.setHunterAmount(settings)
    server.setHunterDistnaceHintTimer(settings)
    server.setHunterRingHintTimer(settings)
	server.setBulletReloadTime(settings)
    server.setEnableMaxSizeLimit (settings)
    server.setHideTime(settings)

	server.gameConfig.hunterPipebombReloadTimer = settings.hunterPipebombReloadTimer
	server.gameConfig.hunterBluetideReloadTimer = settings.hunterBluetideReloadTimer
	server.gameConfig.hiderTauntReloadTimer = settings.hiderTauntReloadTimer
	server.gameConfig.transformCooldown = settings.transformCooldown
	server.gameConfig.hunterDoubleJumpReloadTimer = settings.hunterJumpReload

	-- The gameConfig function doesnt support bools? Therefor I am converting them here
	server.gameConfig.midGameJoin = settings.midGameJoin == 1
	server.gameConfig.hidersJoinHunters = settings.hidersJoinHunters == 1
	server.gameConfig.allowFriendlyFire = settings.allowFriendlyFire == 1
	server.gameConfig.enforceGameStartHunterAmount = settings.enforceGameStartHunterAmount == 1
	server.gameConfig.randomTeams = settings.randomTeams == 1

	shared.gameConfig.transformCooldown = settings.transformCooldown


	if settings.hunterPipebombReloadTimer == -1 then
		server.gameConfig.hunterPipeBombEnabled = false
	else
		server.gameConfig.hunterPipeBombEnabled = true
	end

	if settings.hunterBluetideReloadTimer == -1 then
		server.gameConfig.bluetideEnabled = false
	else
		server.gameConfig.bluetideEnabled = true
	end


	--room has to be spawned here and not in init or the screens won't work
	server.hasPlacedHuntersInRoom = false
	if #server.game.spawnedForHunterRoom <= 0 then
		server.game.spawnedForHunterRoom = Spawn("MOD/hunter_room.xml", Transform(Vec(0,1000,0)), true)
	end

	--if GetPlayerCount() == 2 and GetPlayerName(0) == "Host" or shared.debug then server.gameConfig.hideTime = 2 end 

	countdownInit(server.gameConfig.hideTime, "hidersHiding")

	teamsStart(false)

	SetBool("level.sandbox", false, true)
	SetBool("level.unlimitedammo", false, true)
	SetBool("level.spawn", false, true)
	SetBool("level.creative", false, true)

    AutoInspect(server.gameConfig, 2," ",false)
    AutoInspect(server.mapdata, 2," ",false)
end

function server.setTimeSetting(settings)
    if settings.time == -1 then
		local baseTime = 6
		if server.mapdata.SizeMedium > 6000 then 
			baseTime = baseTime + 2
		end
		if server.mapdata.MapArea > 800 then 
			baseTime = baseTime + 2
		end
		if server.mapdata.MapArea > 1000 then 
			baseTime = baseTime + 2
		end
		if server.mapdata.MapArea > 1400 then 
			baseTime = baseTime + 2
		end
		if #server.mapdata.levels > 3 then
			baseTime = baseTime + 2
		end
        if server.mapdata.MapArea < 100 then 
            baseTime = baseTime - 2
        end
        if server.mapdata.SizeMedium == 0 then 
            baseTime = baseTime - 1
        end

		server.gameConfig.roundLength = baseTime * 60
	else
		server.gameConfig.roundLength = settings.time
	end

    DebugPrint("Round Lenght Auto Settings:" .. server.gameConfig.roundLength/60)
    server.state.time = server.gameConfig.roundLength
	shared.state.time = math.floor(server.state.time)
end

function server.setBulletReloadTime(settings)
    if settings.hunterBulletReloadTimer == -1 then

        local basetime = 5 
        if server.mapdata.SizeMedium > 4000 then 
            basetime = basetime - 1
        end
        if server.mapdata.SizeMedium > 8000 then 
            basetime = basetime - 1
        end

        if server.mapdata.SizeMedium < 1000 then 
            basetime = basetime + 1
        end
        if server.mapdata.SizeMedium < 500 then
            basetime = basetime + 1
        end
        if server.mapdata.SizeMedium < 200 then
            basetime = basetime + 1
        end
        server.gameConfig.hunterBulletReloadTimer = basetime
    else
        server.gameConfig.hunterBulletReloadTimer = settings.hunterBulletReloadTimer
    end
    DebugPrint("Bullet Reload Auto Settings:" .. server.gameConfig.hunterBulletReloadTimer)
end

function server.setHunterDistnaceHintTimer(settings)
    if settings.distanceHintTimer == -1 then
        local basetime = 45
        if server.mapdata.SizeMedium > 8000 then 
            basetime = 30
        end
        if server.mapdata.SizeMedium < 500 then
            basetime = 60
        end
        if server.mapdata.SizeMedium < 200 then
            basetime = 80
        end
        if server.mapdata.MapArea > 1200 then 
            basetime = 30
        end
        if server.mapdata.MapArea > 800 and #server.mapdata.levels >= 2 then 
            basetime = 30
        end
        if server.mapdata.MapArea > 500 and #server.mapdata.levels >= 4 then 
            basetime = 20
        end

        server.gameConfig.distanceHintTimer = basetime
        server.timers.distanceHintTimer = 15  -- First hint will be triggered in 15 seconds 
    elseif settings.distanceHintTimer == -2 then 
        server.gameConfig.distanceHintTimer = false
    else
        server.gameConfig.distanceHintTimer = settings.distanceHintTimer
        server.timers.distanceHintTimer = 15  -- First hint will be triggered in 15 seconds 
    end
    DebugPrint("Distance Hint Auto Settings:" .. server.gameConfig.distanceHintTimer)
end

function server.setHunterAmount(settings)
    -- Clamp hunters so at least one hider
    if settings.huntersStartAmount == -1 then
        local percent = 0.1
        local total = GetPlayerCount()
        if total < 7 then 
            percent = 0.1
        else
            percent = 0.16
        end

        if server.mapdata.MapArea > 800 and #server.mapdata.levels >= 2 or server.mapdata.MapArea > 1400 then
            percent = percent + 0.5
        end

        if server.mapdata.MapArea < 150 and server.mapdata.SizeMedium < 200 then
            percent = 0.1
        end
        server.gameConfig.huntersStartAmount = math.ceil(total * percent)
        DebugPrint("percent:" .. percent)
    else
        server.gameConfig.huntersStartAmount = settings.huntersStartAmount
    end
    DebugPrint("Hunter Amount Auto Settings:" .. server.gameConfig.huntersStartAmount)
end

function server.setHunterRingHintTimer(settings)
    if settings.ringHintTimer == -1 then
        local basetime = 45
        if server.mapdata.MapArea > 1000 then 
            basetime = 30
        end

        if server.mapdata.MapArea < 100 then 
            basetime = false
        end

        if server.mapdata.SizeMedium == 0 then 
            basetime = false
        end

        server.gameConfig.ringHintTimer = basetime
    elseif settings.ringHintTimer == -2 then 
        server.gameConfig.ringHintTimer = false
    else
        server.gameConfig.ringHintTimer = settings.ringHintTimer
    end
    DebugPrint("Ring Hint Auto Settings:" .. tostring(server.gameConfig.ringHintTimer))
end

function server.setEnableMaxSizeLimit(settings)
    if settings.maximumSizeLimit == -1 then
        server.gameConfig.maximumSizeLimit = true
        if server.mapdata.SizeMedium < 400 then 
            server.gameConfig.maximumSizeLimit = false 
        end
        if server.mapdata.MapArea < 100 then 
            server.gameConfig.maximumSizeLimit = false 
        end
    else
        server.gameConfig.maximumSizeLimit = settings.maximumSizeLimit == 1
    end
    DebugPrint("Maximum Size Limit:" .. tostring(server.gameConfig.maximumSizeLimit))
end

function server.setEnableMinSizeLimit(settings)
    if settings.minimumSizeLimit == -1 then
        server.gameConfig.minimumSizeLimit = true
        if server.mapdata.SizeMedium < 200 then 
            server.gameConfig.minimumSizeLimit = false 
        end
        if server.mapdata.MapArea < 70 then 
            server.gameConfig.minimumSizeLimit = false 
        end
    else
        server.gameConfig.minimumSizeLimit = settings.minimumSizeLimit == 1
    end
    DebugPrint("Minimum Size Limit:" .. server.gameConfig.minimumSizeLimit)
end

function server.setHideTime(settings)
    if settings.hideTime == -1 then
        local basetime = 45
        if server.mapdata.MapArea > 1000 then 
            basetime = basetime + 15
        end
        if #server.mapdata.levels ~= 1 then
            basetime = basetime + 15 * math.max(1, #server.mapdata.levels)
        end
        server.gameConfig.hideTime = basetime
    else
        server.gameConfig.hideTime = settings.hideTime
    end
    DebugPrint("Hide Time:" .. server.gameConfig.hideTime)
end