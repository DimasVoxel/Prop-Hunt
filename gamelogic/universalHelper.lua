-- =========================
-- Player state helpers
-- =========================

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
    if shared.players.hiders[id] and shared.players.hiders[id].propBody == -1 then return false end
    return shared.players.hiders[id].propBody
end

function helperGetPlayerPropShape(id)
    id = id or GetLocalPlayer()
    if not helperIsPlayerHider(id) then return false end
    return GetBodyShapes(helperGetPlayerPropBody(id))[1]
end

function helperIsHuntersReleased()
    return shared.state and shared.state.hunterFreed == true
end

function helperIsGameOver()
    return shared.state and shared.state.gameOver == true
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