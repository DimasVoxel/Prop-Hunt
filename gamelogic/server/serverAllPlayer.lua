function server.playersTick(dt)
	server.noHunterSituation(dt)
	server.handleHints(dt)
end

function server.handleHints(dt)
	if helperIsHuntersReleased() and server.gameConfig.hints then
		server.timers.hunterHintTimer = server.timers.hunterHintTimer - dt

		-- We trigger a hint if hint timer gets to 0, and during the last 30 seconds we force one last hint.
		if server.timers.hunterHintTimer < 0 or server.state.time < 30 and server.state.triggerLastHint == false then
			if server.state.time < 30 then
				-- We make sure that the last hint wont get spammed
				server.state.triggerLastHint = true
			end

			server.timers.hunterHintTimer = server.lobbySettings.hunterHinttimer
			for id in Players() do 
				if helperIsPlayerHunter(id) then 
					server.TriggerHint(id, 1)
				elseif helperIsPlayerHider(id) then
					server.TriggerHint(id, 2)
				end
			end

            server.circleHint()
		end
	end
end

function server.noHunterSituation()
	if #teamsGetTeamPlayers(2) == 0 and teamsIsSetup() then
		local id = teamsGetTeamPlayers(1)[#teamsGetTeamPlayers(1)] -- TODO: Change this to chose a random hider instead

		eventlogPostMessage({id, "Was moved to Hunter because all hunters left"  })
		Delete(shared.players.hiders[id].propBody)
		Delete(shared.players.hiders[id].propBackupShape)
		shared.players.hiders[id] = {}

		teamsAssignToTeam(id, 2)
		if helperIsHuntersReleased() then
			spawnRespawnPlayer(id)
		else
			local hunter_room_spawn = FindLocation("hunter_spawn_waiting", true)
			local spawn_transform = GetLocationTransform(hunter_room_spawn)
			if IsHandleValid(hunter_room_spawn) then
				-- room spawned, place all hunters there (other case is handled in serverHunter.lua)
				SetPlayerTransform(spawn_transform, id)
				SetPlayerVelocity(Vec(0, 0, 0), id)
			end
		end

		SetPlayerParam("healthRegeneration", true, id)
		SetPlayerParam("collisionMask", 255, id)
		SetPlayerParam("walkingSpeed", 1, id)
	end
end

function server.circleHint()
    local timeLeft = server.state.time
    local hiders = teamsGetTeamPlayers(1)

    -- Only trigger in the last 3 minutes
    if timeLeft > 180 then
        return
    end

    -- Determine diameter
    local diameter
    if #hiders == 1 and timeLeft <= 60 then
        diameter = 25 + #teamsGetTeamPlayers(2) * 2 
    elseif timeLeft > 120 then      -- between 3 and 2 minutes left
        diameter = 60
    elseif timeLeft > 60 then       -- between 2 and 1 minutes left
        diameter = 35
    else                            -- last minute
        diameter = 25
    end

    -- Reset the circle hint table
    shared.hint.circleHint = {}

    -- Add a transform for each hider
    for _, hiderId in ipairs(hiders) do
        local hiderTransform = nil
        if shared.players.hiders[hiderId] then
            local propBody = shared.players.hiders[hiderId].propBody or -1
            if propBody ~= -1 then
                hiderTransform = GetBodyTransform(propBody)
            else
                hiderTransform = GetPlayerTransform(hiderId)
            end
        end

		if hiderTransform then

			local maxOffset = diameter * 0.5
            -- Random offset so that the hider isnt centered. 
            -- This is technically a hack since it doesnt do a true circluar random 
            -- But this works for now
			local offsetX = (math.random() - math.random() - math.random()) * (maxOffset / 1.5) * 0.8 
			local offsetZ = (math.random() - math.random() - math.random()) * (maxOffset / 1.5) * 0.8


			local hintPos = {
                hiderTransform.pos[1] + offsetX,
                hiderTransform.pos[2] + 40 + math.random(-5,5), -- Technically you could figure out where someone is by estimating the height of the hint
                hiderTransform.pos[3] + offsetZ
            }

            local hintTransform = Transform(hintPos, QuatEuler(90,0,0)) --Rotate the circle to be level with floor
            shared.hint.circleHint[#shared.hint.circleHint + 1] = {}
			shared.hint.circleHint[#shared.hint.circleHint].transform = hintTransform
			shared.hint.circleHint[#shared.hint.circleHint].diameter = diameter
			shared.hint.circleHint[#shared.hint.circleHint].playerid = hiderId
			shared.hint.circleHint[#shared.hint.circleHint].timer = 29
		end
    end
end


function server.TriggerHint(id, teamId)
	local closestPlayer, closestDist, closestTransform = server.GetClosestPlayer(id, teamId)
    if closestTransform == nil then return end

	if not closestPlayer or not closestDist or closestDist == math.huge then
		return
	end

	if not closestPlayer or not closestDist then
		return
	end

	local TEAM_HIDERS = 1
	local TEAM_HUNTERS = 2

	local hiders = #teamsGetTeamPlayers(TEAM_HIDERS)
	local hunters = #teamsGetTeamPlayers(TEAM_HUNTERS)

    -- Tried to balance the hints
    local function CanShowDetailedHint()
		local remainingTime = server.lobbySettings.roundLength - server.state.time

		if hiders == 1 then
			return remainingTime <= 120
		end

		if hunters >= 5 then
			return server.state.time >= 300
		end

		if hunters == 1 and hiders > 1 then
			return remainingTime <= 180
		end

		if hunters == 2 and hiders >= 2 then
			return remainingTime <= 120
		end

		return true
	end

    -- Hints are less accurate in the first half of the round
	local function GetShownDistance(dist)
		if server.state.time < server.lobbySettings.roundLength * 0.5 then
			return math.floor(dist / 5) * 5
		end
		return math.floor(dist * 10) / 10
	end


	local myTeam = teamsGetTeamId(id)
	local targetName = (myTeam == TEAM_HUNTERS) and "hider" or "hunter"

	local shownDist = GetShownDistance(closestDist)

	local message 
    -- If the player is right on top of the hider it would say "1 Meter away" instantly giving away the location
    -- I decided to limit the distance to 5 meters as its still enough to be confused if there are enough props around
	if targetName == "hider" and closestDist <= 5 then
		message = "The hider is very close"
	else
		message =
			"The closest " .. targetName .. " is " .. shownDist .. " meters away"
	end


	local showDetail = closestTransform and CanShowDetailedHint() and closestDist < 30

	-- Last hider gets no vertical detail
	if hiders == 1 and myTeam == TEAM_HIDERS then
		showDetail = false
	end

	if showDetail then
		local myPos = GetPlayerTransform(id).pos[2]

		if closestTransform.pos[2] < myPos + 2.5
			and closestTransform.pos[2] > myPos - 2.5 then
			message = message .. " and is level with you."
		elseif closestTransform.pos[2] > myPos then
			message = message .. " and is above you."
		else
			message = message .. " and is below you."
		end
	else
		message = message .. "."
	end
    
	ClientCall( id, "client.hintShowMessage", message, 5)
end

-- This function is mainly used to find the closest hider as a hunter
-- or to find the closest hunter as a hider
function server.GetClosestPlayer(id, teamId)
	local closestDist = math.huge
	local closestPlayer = nil
	local closestTransform = nil

	-- Get source player transform
	local myTransform = nil
	if teamsGetTeamId(id) == 1 then
		local myBody = shared.players.hiders[id] and shared.players.hiders[id].propBody or -1
		if myBody ~= -1 then
			myTransform = GetBodyTransform(myBody) -- If player transformed we get his bodytransform
		else
			myTransform = GetPlayerTransform(id) -- If player decides not to transform or there are no props on the map we get palyerT
		end
	elseif teamsGetTeamId(id) == 2 then
		myTransform = GetPlayerTransform(id)
	end

	if not myTransform then
		return nil, nil
	end

	-- Search only players in the given team
	for _, otherId in ipairs(teamsGetTeamPlayers(teamId)) do
		if otherId ~= id then -- Dont search for yourself
			local otherTransform = nil

			if helperIsPlayerHider(otherId) then
				local otherBody = shared.players.hiders[otherId] and shared.players.hiders[otherId].propBody or -1
				if otherBody ~= -1 then
					otherTransform = GetBodyTransform(otherBody)
				else
					otherTransform = GetPlayerTransform(otherId)
				end
			elseif helperIsPlayerHunter(otherId) then
				otherTransform = GetPlayerTransform(otherId)
			end

			if otherTransform then
				local dist = VecLength(VecSub(myTransform.pos, otherTransform.pos))
				if dist < closestDist then
					closestDist = dist
					closestPlayer = otherId
					closestTransform = otherTransform
				end
			end
		end
	end

	return closestPlayer, closestDist, closestTransform
end