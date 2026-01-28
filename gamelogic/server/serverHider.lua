function server.clientHideRequest(playerid)
	local body = helperGetPlayerPropBody(playerid)
	local playerTransform = GetPlayerTransform(playerid)
	local pos = TransformToParentPoint(playerTransform, VecScale(shared.players.hiders[playerid].offset,-1))
	pos = VecAdd(pos,  Vec(0, 0.05, 0))

	local function enableHideMode()
		shared.players.hiders[playerid].isPropPlaced = true
		server.players.hiders[playerid].unhideCooldown = GetTime() + server.gameConfig.unhideCooldown

		body = server.propRegenerate(playerid)
	
		server.disableBodyCollission(body, false)
		
		SetBodyDynamic(body, true)
		SetBodyActive(body, true)
		
		SetBodyVelocity(body, GetPlayerVelocity(playerid))
	end

	local function checkLineOfSight(pos1,pos2)

		local _,_,_, shape = QueryRaycast(pos1, Vec(0,-1,0), 1, 0.3, false)
		QueryRejectShape(shape)
		local dir = VecNormalize(VecSub(pos2, pos1))
		QueryRejectBody(body)
		local hit = QueryRaycast(pos1, dir, 2, 0, false)
		if hit then return false else return true end
	end

	local clippingProps = checkPropClipping(playerid)
	if #clippingProps == 0 then 
		enableHideMode()
		return
	else
		for i = 1, 10 do
			local newPos = VecAdd(pos, Vec(0, (i / 10)  - 0.1, 0))
			SetBodyTransform(body, Transform(newPos, playerTransform.rot))
			local tempClipping = checkPropClipping(playerid)
			local bool = checkLineOfSight(pos, newPos)
			if bool == false then break end
			if #tempClipping == 0 then
				enableHideMode()
				return
			end
		end
	end

	shared.players.hiders[playerid].clippingProps = clippingProps
	-- If the server was unable to find a place to hide reset back to original pos
	local offset
	
	pos = VecAdd(pos, Vec(0,0.05,0))

	-- We move the prop body to player on the server. Player Camera is in handeled in client.hiderTick()
	SetBodyVelocity(body, Vec(0, 0, 0))
	SetBodyTransform(body, Transform(pos, playerTransform.rot))
end


function server.hiderTick(dt)
    local hiders = teamsGetTeamPlayers(1)

    if helperIsHuntersReleased() then
        server.handleHiderTaunts(hiders)
    end

    for _, id in ipairs(hiders) do
        -- Hiders should not be able to enter vehicles
        SetPlayerVehicle(0, id) 
        -- Sometimes other mods can mess with the tools we just set it to be taunt so they are unable to use other ones
        SetPlayerTool("", id) 

        local propBody = helperGetPlayerPropBody(id)
        if propBody then
             -- Placing this here means that if the game ends all players become visible since hiderTick wont get called in the endscreen
             -- May need to be rethought
            SetPlayerHidden(id)
            if not helperIsPlayerHidden(id) then
                -- While running the prop has no collission with anything neither world nor player
                SetPlayerParam("collisionMask", 255 - 4, id)
            else
                -- If player is placed / hidden then prop gets collission with world but not with player
                SetPlayerParam("collisionMask", 1 , id)
                SetPlayerParam("walkingSpeed", 0, id)
				ReleasePlayerGrab(id)
				SetPlayerTransform(Transform(Vec(0,10000,0), GetPlayerTransform(id).rot), id)
            end
		elseif not propBody and helperIsHuntersReleased() then
			SetPlayerParam("godmode", false, id)
		end

		local velocity = GetPlayerVelocity(id)
		local speed = VecLength(velocity)
		if speed > 1 and IsPlayerGrounded(id) then
			PlayLoop(server.assets.walkingSound, GetPlayerTransform(id).pos, math.max(0, speed / 6), true, math.max(0, speed / 7))
			PlayLoop(server.assets.runningSound, GetPlayerTransform(id).pos, math.max(0, speed / 10), true, math.max(0, speed / 7))
		end

		server.handleHiderPlayerDamage(id)
    end
	
	local eventCount = GetEventCount("playerhurt")
	if eventCount ~= 0 then
		local playerID, _,_, attackerID = GetEvent("playerhurt",1)
		if helperIsPlayerHider(playerID) and not helperGetPlayerPropBody(playerID) then 
			helperDecreasePlayerShots(playerID)
			helperSetPlayerHealth(playerID, shared.players.hiders[playerID].health - shared.players.hiders[playerID].damageValue)
			SetPlayerHealth(1, playerID)
			server.createLog(playerID, 1)
		end
	end
end

function server.hiderUpdate()
	if teamsIsSetup() then
		for id in Players() do
			if helperIsPlayerHider(id) then
				if helperIsPlayerHidden(id) then
					local aa,bb = GetBodyBounds(helperGetPlayerPropBody(id))
					local center = VecLerp(aa, bb, 0.5)

					local input = (InputDown('down', id) or InputDown('up', id) or InputDown('left', id) or InputDown('right', id) or InputDown('jump', id))
					local timer = server.players.hiders[id].unhideCooldown < GetTime()

					if (IsPointInWater(center) or (input and timer)) and shared.players.hiders[id].isPropPlaced == true then
						shared.players.hiders[id].isPropPlaced = false
						server.resetPlayerToProp(id)
						-- You shouldnt spam this function because every call will put the message in a queue
						if IsPointInWater(center) then
							ClientCall(id, "client.notify", "Water will damage you, get out as soon as you can." )
						end
					end
				end

				local speed = VecLength(GetPlayerVelocity(id))

				if InputDown("shift", id) and not helperIsPlayerHidden(id) and shared.players.hiders[id].staminaCoolDown < GetTime() and speed > 0.1 then 
					SetPlayerParam("walkingSpeed", 11, id)
					shared.players.hiders[id].stamina = math.max(shared.players.hiders[id].stamina - GetTimeStep(), 0)

					if shared.players.hiders[id].stamina == 0 then 
						shared.players.hiders[id].staminaCoolDown = GetTime() + 10
					end

					PlayLoop(server.assets.runningSound, GetPlayerTransform(id).pos, math.max(0, speed / 3.5), true, math.max(0, speed / 7))
				else
					shared.players.hiders[id].stamina = math.min(shared.players.hiders[id].stamina + GetTimeStep()/8, shared.gameConfig.staminaSeconds)
				end

				server.handlePlayerProp(id)
				SetLightEnabled(GetFlashlight(id), false)
			end

		--AutoInspectWatch(shared.players.hiders,"2", 2," ", 0)

		--AutoInspectWatch(server.players.hiders,"1", 2," ", 0)

			if shared.players.hiders[id] and shared.players.hiders[id].grabbing and not helperIsPlayerHidden(id) and helperGetPlayerPropBody(id) then 
				if InputDown("grab", id) then
					local body = server.players.hiders[id].grabbing.body
					local dir = server.players.hiders[id].grabbing.dir
					local dist = server.players.hiders[id].grabbing.dist

					local localPos = server.players.hiders[id].grabbing.localPos
					local playerT = GetPlayerCameraTransform(id)
					local targetPoint = VecAdd(playerT.pos, VecScale(dir, dist + 0.2)) 
					local worldPoint = TransformToParentPoint(GetBodyTransform(body), localPos)

					local dist = VecLength(VecSub(worldPoint, targetPoint))

					if dist < 4 then 
						local velocity = AutoClamp(math.pow(dist,3), -6, 6)
						local strength = AutoClamp(dist*60, -150, 150)

						ConstrainPosition(body, 0, worldPoint, targetPoint, velocity, strength)
					else
						shared.players.hiders[id].grabbing = false
					end

					ReleasePlayerGrab(id)
					SetPlayerParam("walkingSpeed", 7 * ( 1 - dist / 4 ), id)
				else
					shared.players.hiders[id].grabbing = false
				end
			end
		end
	end
end

function server.handlePlayerProp(id) -- In Update
	local propBody = helperGetPlayerPropBody(id)

	if propBody ~= false then
		if not shared.players.hiders[id].isPropPlaced then
			server.disableBodyCollission(propBody, true)

			local playerTransform = GetPlayerTransform(id)
			local pos = TransformToParentPoint(playerTransform, VecScale(shared.players.hiders[id].offset,-1))

			local offset
			if InputDown("crouch", id) then
				offset = Vec()
			else
				offset = Vec(0, 0.05, 0)
			end
			pos = VecAdd(pos, offset)

			-- We move the prop body to player on the server. Player Camera is in handeled in client.hiderTick()
			SetBodyVelocity(propBody, Vec(0, 0, 0))
			SetBodyAngularVelocity(propBody, Vec(0, 0, 0))

			SetBodyDynamic(propBody, false)
			SetBodyActive(propBody, false)

			SetBodyTransform(propBody, Transform(pos, playerTransform.rot))

			local dist = VecLength(VecSub(playerTransform.pos, server.players.hiders[id].standStillPosition))
			if dist > 0.01 then 
				shared.players.hiders[id].standStillTimer = shared.serverTime
			end
			server.players.hiders[id].standStillPosition = VecCopy(playerTransform.pos)
		end
	end
end

function server.handleHiderPlayerDamage(id) -- In Tic
	local propBody = helperGetPlayerPropBody(id)
	if propBody then
		local aa,bb = GetBodyBounds(propBody)
		local center = VecLerp(aa, bb, 0.5)
		local transform = GetBodyTransform(propBody)
		if transform.pos[2] < -15 then 
			local speed = VecLength(GetBodyVelocity(propBody))
			if speed > 0.1 then 
				server.players.hiders[id].outOfBoundsTimer = GetTime() + server.gameConfig.outOfBoundsCoolDown
			end
		else
			server.players.hiders[id].outOfBoundsTimer = GetTime() + server.gameConfig.outOfBoundsCoolDown
		end

		if server.players.hiders[id].outOfBoundsTimer < GetTime() then

			-- just doing this twice to make more punishing
			helperDecreasePlayerShots(id)
			helperDecreasePlayerShots(id)
			helperSetPlayerHealth(id, shared.players.hiders[id].health - shared.players.hiders[id].damageValue)
			helperSetPlayerHealth(id, shared.players.hiders[id].health - shared.players.hiders[id].damageValue)
			server.propRegenerate(id)
			server.resetPlayerToProp(id)
			shared.players.hiders[id].isPropPlaced = false
			ClientCall(id, "client.notify", "Hiding out of bounds is not allowed." )

			if helperGetPlayerShotsLeft(id) == 0 then 
				eventlogPostMessage({id, "Tried hiding out of bounds"  })
			end

			server.createLog(id, 1)
		end

		if IsBodyBroken(propBody) then
			helperDecreasePlayerShots(id)
			helperSetPlayerHealth(id, shared.players.hiders[id].health - shared.players.hiders[id].damageValue)
			server.resetPlayerToProp(id)
			server.createLog(id, 1)

			-- We move the player to the shape if player was too far from the prop when found
			-- If we dont there are situations when the prop falls down a cliff or building and the player stays on top of the cliff.
			-- Once found the prop gets teleported back to the player. This makes it look like as if the prop dissapeared for the hunter
			-- Therefor we move the player to the prop. One issue is that players can get stun locked sometimes

			propBody = server.propRegenerate(id)
			shared.players.hiders[id].isPropPlaced = false

			local aa,bb = GetBodyBounds(propBody)
			center = VecLerp(aa, bb, 0.5)

			ClientCall(0, "client.highlightPlayer", id)
		end


		local lowerHalf = Vec(center[1],AutoLerp(center[2], aa[2],0.5),center[3])

		if not IsPointInWater(lowerHalf) or not helperIsHuntersReleased() then 
			shared.players.hiders[id].damageTick = GetTime()
			shared.players.hiders[id].environmentalDamageTrigger = false
		else
			shared.players.hiders[id].environmentalDamageTrigger = true
		end
	else
		local playerTransform = GetPlayerTransform(id)
		if not IsPointInWater(VecAdd(playerTransform.pos,Vec(0,0.5,0))) or not helperIsHuntersReleased() then 
			shared.players.hiders[id].damageTick = GetTime()
			shared.players.hiders[id].environmentalDamageTrigger = false
		else
			shared.players.hiders[id].environmentalDamageTrigger = true
		end
	end

	local totalWaterTime = 10
	local tickDamageTime = totalWaterTime/(1/shared.players.hiders[id].damageValue) + 1

	if (shared.players.hiders[id].damageTick + tickDamageTime) <= GetTime() then
		helperDecreasePlayerShots(id)
		helperSetPlayerHealth(id, shared.players.hiders[id].health - shared.players.hiders[id].damageValue)
		shared.players.hiders[id].damageTick = GetTime()

		server.createLog(id, 1)
	end

	if IsPointInBoundaries(center) == false and helperIsPlayerHidden(id) then
		shared.players.hiders[id].isPropPlaced = false
		server.resetPlayerToProp(id)
	end
end

-- Gets Called by clients.
-- #TODO: Some say that the server sound sync sucks and its recommended to use ClientCall to execute a playsound locally
function server.tauntBroadcast(pos, id)
	shared.players.hiders[id].taunts = math.max(helperGetHiderTauntsAmount(id) - 2, 1)
	local soundID = math.random(1, 4)
	local propguy = false

	if GetPlayerName(id) == "The Mafia" and math.random(1,5) ~= 1 then 
		propguy = true
	end

	if math.random(1, 100) == 50 then 
		propguy = true
	end

	server.createLog(id, 3)

	ClientCall(0, "client.tauntBroadcast", pos, soundID, propguy)
end

function server.handleHiderTaunts(hiderIds)
    if server.timers.hiderTauntReloadTimer <= GetTime() then
        server.timers.hiderTauntReloadTimer = GetTime() + server.gameConfig.hiderTauntReloadTimer

        for _, id in ipairs(hiderIds) do
            -- If the player has 10 taunts already, force them to taunt.
            if helperGetHiderTauntsAmount(id) == 10 then
                server.tauntBroadcast(GetPlayerTransform(id).pos, id)
                shared.players.hiders[id].taunts = 6
            else
				shared.players.hiders[id].taunts = math.min(helperGetHiderTauntsAmount(id) + 1, 10)
            end
        end
    end
end

function server.PropSpawnRequest(playerid, propid, damageValue, cameraTransform)
	local string = "Player " .. GetPlayerName(playerid) .. " wants to spawn prop " .. propid

    -- GetCameraTransform() is client only. But I wanted to validate if the player is looking at the prop on the server too
	local shape = playerGetLookAtShape(10, playerid, cameraTransform)
	local shapeBody = GetShapeBody(shape)

	if shape == propid and shapeBody ~= shared.players.hiders[playerid].propBody then

		server.createLog(playerid, 2)

		-- Delete Old Prop and Backup shapes if transforming into a new shape
		if shared.players.hiders[playerid].propBody ~= -1 then
			Delete(shared.players.hiders[playerid].propBody)
		end

		if shared.players.hiders[playerid].propBackupShape ~= -1 then
			Delete(GetShapeBody(shared.players.hiders[playerid].propBackupShape))
		end

		-- Create new Clone Shape and keep a backup copy to regenerate if damaged
		local newBody, newShape = server.cloneShape(propid)
		local t = GetShapeLocalTransform(shape)
		SetShapeLocalTransform(newShape, Transform(Vec(0,0,0), t.rot))
		SetTag(newBody,"bounded")
		
		local backUpBody, backUpShape = server.cloneShape(propid) -- We clone twice if the prop gets damaged we regenerate using the backup
		local t = GetShapeLocalTransform(shape)
		SetShapeLocalTransform(backUpShape, Transform(Vec(0,0,0), t.rot))

		local emissiveScale = GetProperty(shape, "emissiveScale")
		SetProperty(backUpShape, "emissiveScale", emissiveScale * 2)
		SetProperty(newShape, "emissiveScale", emissiveScale * 2)

		-- Move the prop to the player
		local bodyTransform = GetBodyTransform(newBody)
		SetBodyTransform(newBody, Transform(VecAdd(GetPlayerTransform(playerid).pos, Vec(0, 0, 2)), bodyTransform.rot))
		SetBodyDynamic(newBody, false)
		server.disableBodyCollission(newBody, true)
		server.makePropBreakable(newBody)

		-- Move Backup shape away
		SetBodyTransform(backUpBody, Transform(Vec(-1000, 10, 0)))
		SetBodyDynamic(backUpBody, false)
		server.disableBodyCollission(backUpBody, false)
		server.makePropBreakable(backUpBody)

		local bodyTransform = GetBodyTransform(backUpBody)
		local aa,bb = GetBodyBounds(backUpBody)
		local center = TransformToLocalPoint(bodyTransform, VecLerp(aa, bb, 0.5))
		center[2] = 0

		shared.players.hiders[playerid].offset = VecScale(center, 1)

		-- Note down Prop IDs
		shared.players.hiders[playerid].propBody = newBody
		shared.players.hiders[playerid].propBackupShape = backUpShape

		-- Make sure Prop isnt fragile
		SetProperty(newShape, "strength", 10) -- Shapes only get destroyed by weapons
		SetProperty(newShape, "density", 500/GetBodyMass(newBody))

		SetPlayerParam("godmode", true, playerid)

		-- Note Down the damage values of the prop
		shared.players.hiders[playerid].damageValue = damageValue
		shared.players.hiders[playerid].hp = math.max(AutoRound(helperGetPlayerHealth(playerid)/damageValue),1)
		shared.players.hiders[playerid].transformCooldown = shared.serverTime + server.gameConfig.transformCooldown
		shared.players.hiders[playerid].environmentalDamageTrigger = false
	end
end

function server.propRegenerate(playerid)
    local propBody = helperGetPlayerPropBody(playerid)
	if propBody then
        Delete(propBody)

		local backupShape = shared.players.hiders[playerid].propBackupShape

		-- I tried doing just copyshapecontents but it didnt get rid of the "IsBodyBroken" property and breaks my logic.
		-- Therefor I will keep it like this for now 
		-- #Todo: could perhaps use voxel count instead of is broken?
		local newBody, newShape = server.cloneShape(backupShape) 
		SetTag(newBody,"bounded")

		SetBodyTransform(newBody, GetPlayerTransform(playerid))
		server.disableBodyCollission(newBody, true)

		shared.players.hiders[playerid].propBody = newBody

		SetProperty(newShape, "strength", 10)
		SetProperty(newShape, "density", 1)

		local emissiveScale = GetProperty(backupShape, "emissiveScale")
		SetProperty(newShape, "emissiveScale", emissiveScale * 2)

		--SetInt('options.game.thirdperson',1, true)
		return newBody
	end
end

function server.cloneShape(shape, collisison)
	local newBody = Spawn('<body pos="0.0 0 0.0" dynamic="true"> <voxbox tags="deleteTempShape" size="1 1 1"/> </body>',
		Transform(Vec(0,0,0)), false)[1]                                                                                                                -- Temo shape because empty bodies get rmoved?
	local save = CreateShape(newBody, Transform(), 0)
	CopyShapeContent(shape, save)
	local x, y, z, scale = GetShapeSize(shape)
	local start = GetShapeWorldTransform(shape)
	local body = GetShapeBody(save)
	ResizeShape(shape, 0, 0, 0, x - 1, y - 1, z + 1)
	SetBrush("cube", 1, 1)
	DrawShapeBox(shape, 0, 0, z + 1, 0, 0, z + 1)
	local pieces = SplitShape(shape, false)
	local moved = VecScale(TransformToLocalPoint(GetShapeWorldTransform(shape), start.pos), 1 / scale)
	local mx, my, mz = math.floor(moved[1] + 0.5), math.floor(moved[2] + 0.5), math.floor(moved[3] + 0.5)
	ResizeShape(shape, mx, my, mz, 1, 1, 1)

	CopyShapeContent(save, shape)
	local splitoffset = VecScale(TransformToLocalPoint(GetShapeWorldTransform(pieces[1]), start.pos), 1 / scale)
	local sx, sy, sz = math.floor(splitoffset[1] + 0.5), math.floor(splitoffset[2] + 0.5),
		math.floor(splitoffset[3] + 0.5)
	ResizeShape(pieces[1], sx, sy, sz, 1, 1, 1)
	CopyShapeContent(save, pieces[1])
	Delete(save)
	for i = 2, #pieces do
		Delete(pieces[i])
	end
	Delete(FindShape("deleteTempShape", true))

	SetShapeBody(pieces[1], newBody, true)

	SetShapeLocalTransform(pieces[1], GetShapeLocalTransform(shape))

	return newBody, pieces[1]
end

function server.disableBodyCollission(body, bool)
	local shapes = GetEntityChildren(body, "", true, "shape")

	for i = 1, #shapes do
		if bool then
			SetShapeCollisionFilter(shapes[i], 4, 4)
		else
			SetShapeCollisionFilter(shapes[i], 1, 255)
		end
	end
end

function server.makePropBreakable( body )
	local shape = GetBodyShapes(body)[1]
	local palette = GetShapePaletteContent(shape)

	for i = 1, #palette do
		local mat = palette[i].material
		palette[i].material = "wood" -- We make this so that props can burn
	end

	SetShapePaletteContent(shape, palette)
end

function server.clientGrabRequest(playerid, shape, localPoint, dist, dir)
	server.players.hiders[playerid].grabbing.body = shape
	server.players.hiders[playerid].grabbing.localPos = localPoint
	server.players.hiders[playerid].grabbing.dist = dist
	server.players.hiders[playerid].grabbing.dir = dir
	shared.players.hiders[playerid].grabbing = true
end

function server.updateClientGrab(playerid, dir)
	server.players.hiders[playerid].grabbing.dir = dir
end

function server.resetPlayerToProp(id)
	if helperGetPlayerPropBody(id) then
		local vel = GetPlayerVelocity(id)
		local bodyT = GetBodyTransform(helperGetPlayerPropBody(id))
		local pos = TransformToParentPoint(bodyT, VecScale(shared.players.hiders[id].offset,1))
		SetPlayerTransform(Transform(pos, server.players.hiders[id].currentCameraRot), id)
		SetPlayerVelocity(vel, id)
	end
end

function server.updateCameraRot(id, quat)
	server.players.hiders[id].currentCameraRot = quat
end