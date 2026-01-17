-- =========================
-- Player state helpers
-- =========================

--- Player Team ---

-- Hunter id if no id provided uses localplayer
function helperIsPlayerHunter(id)
    id = id or GetLocalPlayer()
    return teamsGetTeamId(id) == 2
end

-- Hunter id if no id provided uses localplayer
function helperIsPlayerHider(id)
    id = id or GetLocalPlayer()
    return teamsGetTeamId(id) == 1
end

-- Hunter id if no id provided uses localplayer
function helperIsPlayerSpectator(id)
    id = id or GetLocalPlayer()
    return teamsGetTeamId(id) == 3
end

---------

----- Hider Helpers ----

-- Returns if the player has transformed into a prop
-- Will always return false if player is not a Hider
function helperIsPlayerTransformed(id)
    id = id or GetLocalPlayer()
    if not helperIsPlayerHider(id) then return false end 
    return shared.players.hiders[id] and shared.players.hiders[id].propBody ~= -1
end

-- Returns if the player is currently in the hidden / placed state.
-- Will always return false if player is not a Hider
function helperIsPlayerHidden(id)
    id = id or GetLocalPlayer()
    if not helperIsPlayerHider(id) then return false end 
    return shared.players.hiders[id] and shared.players.hiders[id].isPropPlaced == true
end

function helperGetPlayerPropBody(id)
    id = id or GetLocalPlayer()
    if not helperIsPlayerHider(id) then return false end
	if not shared.players.hiders[id] then return false end
	if not shared.players.hiders[id].propBody then return false end

    if shared.players.hiders[id] then
		if shared.players.hiders[id].propBody == -1 or shared.players.hiders[id].propBody == nil then 
			return false 
		end
	end
    return shared.players.hiders[id].propBody
end

function helperGetPlayerPropShape(id)
    id = id or GetLocalPlayer()
    if not helperIsPlayerHider(id) then return false end
    return GetBodyShapes(helperGetPlayerPropBody(id))[1]
end

-- This is how much damage the hider gets when shot at or explodes
function helperGetHiderDamageValue(id)
	id = id or GetLocalPlayer()
	if not helperIsPlayerHider(id) then return false end
	if not helperGetPlayerPropBody(id) then return 0.30 end -- Base Damage
	return shared.players.hiders[id].damageValue
end

function helperGetHiderTauntsAmount(id)
	id = id or GetLocalPlayer()
	if not helperIsPlayerHider(id) then return false end
	return shared.players.hiders[id].taunts
end

function helperGetHiderStandStillTime(id)
	id = id or GetLocalPlayer()
	if not helperIsPlayerHider(id) then return false end
	return math.abs(shared.players.hiders[id].standStillTimer - shared.serverTime)
end

------------

function helperIsHuntersReleased()
    return shared.state and shared.state.hunterFreed == true
end

function helperIsGameOver()
    return shared.state and shared.state.gameOver == true
end

function helperGetPlayerShotsLeft(id)
	local id = id or GetLocalPlayer()
	if helperIsPlayerHider(id) and shared.players.hiders[id] then
		return shared.players.hiders[id].hp
	end
	return false
end

function helperDecreasePlayerShots(id)
	local id = id or GetLocalPlayer()
	if helperIsPlayerHider(id) and shared.players.hiders[id] then
		shared.players.hiders[id].hp = math.max(shared.players.hiders[id].hp - 1,0)
	end
end

function helperGetPlayerHealth(id)
	local id = id or GetLocalPlayer()
	if helperIsPlayerHider(id) and shared.players.hiders[id] then
		return shared.players.hiders[id].health
	elseif helperIsPlayerHunter(id) then
		return GetPlayerHealth(id)
	else -- Spectators
		return 1
	end
end

function helperSetPlayerHealth(id, health)
	if helperIsPlayerHider(id) and shared.players.hiders[id] then
		shared.players.hiders[id].health = math.max(health, 0)
	else
		SetPlayerHealth(health, id)
	end
end

function helperIsPlayerInDangerEnvironment(id)
	local id = id or GetLocalPlayer()
	if helperIsPlayerHider(id) and shared.players.hiders[id] then
		return shared.players.hiders[id].environmentalDamageTrigger
	end
end

----------------# Functions that are used by both client and server #------------------

function checkPropClipping(id)
	local body = helperGetPlayerPropBody(id)
    if not body then return {} end

	local shape = GetBodyShapes(body)[1]
	local aa, bb = GetBodyBounds(body)

	QueryRequire("physical")
	local shapes = QueryAabbShapes(aa, bb)

	local clippingShapes = {}

	for i = 1, #shapes do
		if IsShapeTouching(shape, shapes[i]) and shapes[i] ~= shape then
			clippingShapes[#clippingShapes + 1] = shapes[i]
		end
	end

	return clippingShapes
end

function playerGetLookAtShape(dist, playerID, cameraT)
	local cameraT = cameraT or GetCameraTransform()
	local playerID = playerID or GetLocalPlayer()
	local playerFwd = VecNormalize(TransformToParentVec(cameraT, Vec(0, 0, -1)))

	QueryRequire("physical large")
	QueryRejectBody(shared.players.hiders[playerID].propBody)

	local hit, dist, _, shape = QueryRaycast(cameraT.pos, playerFwd, dist, 0, false)

	DebugCross(VecAdd(cameraT.pos,VecScale(playerFwd,dist)),1,1,1,1)

	if hit and IsShapeBroken(shape) == false then
		return shape
	else
		return -1
	end
end

--better than lerp, is framerate independant and arrives at an end
function expDecay(val, target, decay, dt)
	return target + (val - target) * math.exp(-decay * dt)
end