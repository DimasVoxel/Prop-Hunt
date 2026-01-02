function server.clientHideRequest(playerid)
    if not shared.players.hiders[playerid].isPropClipping then
        shared.players.hiders[playerid].isPropPlaced = true
    end
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
        SetPlayerTool("taunt", id) 

        local propBody = helperGetPlayerPropBody(id)
        if propBody then
            for _, playerId in ipairs(teamsGetTeamPlayers(1)) do
                -- You cant grab other hiders props and throw them into the ocean for example
                if GetPlayerGrabBody() == helperGetPlayerPropBody(playerId) then
                    ReleasePlayerGrab()
                end
            end

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
            end

            local aa,bb = GetBodyBounds(propBody)
            local center = VecLerp(aa, bb, 0.5)
            if IsBodyBroken(propBody) then
                -- #TODO: make damage variable depending on prop size
                -- Reason: Small props are harder to find and harder to shoot at.
                SetPlayerHealth(GetPlayerHealth(id) - 0.33, id) 

                -- We move the player to the shape if player was too far from the prop when found
                -- If we dont there are situations when the prop falls down a cliff or building and the player stays on top of the cliff.
                -- Once found the prop gets teleported back to the player. This makes it look like as if the prop dissapeared for the hunter
                -- Therefor we move the player to the prop. One issue is that players can get stun locked sometimes
                if VecLength(VecSub(GetPlayerTransform(id).pos, center)) > 2 then
                    SetPlayerTransform(Transform(VecAdd(center, Vec(0, 0.0, 0)),GetPlayerCameraTransform(id).rot), id)
                end

                server.propRegenerate(id)
                shared.players.hiders[id].isPropPlaced = false
                ClientCall(0, "client.highlightPlayer", shared.players.hiders[id].propBody)
            end

            if IsPointInBoundaries(center) == false and helperIsPlayerHidden(id) then
                shared.players.hiders[id].isPropPlaced = false

                if VecLength(VecSub(GetPlayerTransform(id).pos, center)) > 2 then
                    SetPlayerTransform(Transform(VecAdd(center, Vec(0, 0.0, 0)),GetPlayerCameraTransform(id).rot), id)
                end
            end
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
					if (IsPointInWater(center) or InputDown('down', id) or InputDown('up', id) or InputDown('left', id) or InputDown('right', id) or InputDown('jump', id)) and shared.players.hiders[id].isPropPlaced == true then
						shared.players.hiders[id].isPropPlaced = false
						SetPlayerTransform(Transform(VecAdd(center, Vec(0, 0.2, 0)),GetPlayerCameraTransform(id).rot), id)

						-- You shouldnt spam this function because every call will put the message in a queue
						hudShowBanner("Water will damage you, get out as soon as you can.", {0,0,0}) 
					end
	
					if IsPointInWater(GetPlayerTransform(id).pos) then
						SetPlayerHealth(GetPlayerHealth(id) - GetTimeStep()/15, id)
					end
				end

				server.handlePlayerProp(id)
				SetLightEnabled(GetFlashlight(id), false)
			end
		end
	end
end

function server.handlePlayerProp(id)
	local clippingProps = checkPropClipping(id)
    -- The server only needs to know if props are clipping or not. It doesnt matter which shapes in particular
    -- On client we use the output to highlight shapes that are being clipped into
	if #clippingProps == 0 then 
		shared.players.hiders[id].isPropClipping = false
	else
		shared.players.hiders[id].isPropClipping = true
	end

	local propBody = helperGetPlayerPropBody(id)

	if propBody ~= -1 then
		if shared.players.hiders[id].isPropPlaced then
			server.disableBodyCollission(propBody, false)
		else
			server.disableBodyCollission(propBody, true)

			local playerTransform = GetPlayerTransform(id)
			local playerBhnd = TransformToParentVec(playerTransform, Vec(0, 0.5, 0))

			-- We move the prop body to player on the server. Player Camera is in handeled in client.hiderTick()
			SetBodyVelocity(propBody, Vec(0, 0, 0))
			SetBodyTransform(propBody, Transform(VecAdd(playerTransform.pos, playerBhnd), playerTransform.rot))
		end
	end
end

-- Gets Called by clients.
-- #TODO: Some say that the server sound sync sucks and its recommended to use ClientCall to execute a playsound locally
function server.taunt(pos, id)
	SetToolAmmo("taunt", math.max(GetToolAmmo("taunt", id) - 3 ,1), id)
	PlaySound(server.assets.taunt,pos,2,true,1)
end

function server.handleHiderTaunts(hiderIds)
    local dt = GetTimeStep()

    server.timers.hiderTauntReloadTimer = server.timers.hiderTauntReloadTimer - dt

    if server.timers.hiderTauntReloadTimer < 0 then
        server.timers.hiderTauntReloadTimer = server.gameConfig.hiderTauntReloadTimer

        for _, id in ipairs(hiderIds) do
            -- If the player has 10 taunts already, force them to taunt.
            if GetToolAmmo("taunt", id) == 10 then
                server.taunt(GetPlayerTransform(id).pos, id)
                SetToolAmmo("taunt", 6, id)
            else
                SetToolAmmo("taunt", math.min(GetToolAmmo("taunt", id) + 1, 10), id)
            end
        end
    end
end

function server.PropSpawnRequest(playerid, propid, cameraTransform)
	local string = "Player " .. GetPlayerName(playerid) .. " wants to spawn prop " .. propid

    -- GetCameraTransform() is client only. But I wanted to validate if the player is looking at the prop on the server too
	local shape = playerGetLookAtShape(10, playerid, cameraTransform)
	local shapeBody = GetShapeBody(shape)

	if shape == propid and shapeBody ~= shared.players.hiders[playerid].propBody then
		if shared.players.hiders[playerid].propBody ~= -1 then
			Delete(shared.players.hiders[playerid].propBody)
		end

		if shared.players.hiders[playerid].propBackupShape ~= -1 then
			Delete(GetShapeBody(shared.players.hiders[playerid].propBackupShape))
		end

		local newBody, newShape = server.cloneShape(propid)
		local backUpBody, backUpShape = server.cloneShape(propid) -- We clone twice if the prop gets damaged we regenerate using the backup
		local emissiveScale = GetProperty(shape, "emissiveScale")
		SetProperty(backUpShape, "emissiveScale", emissiveScale * 2)
		SetProperty(newShape, "emissiveScale", emissiveScale * 2)

		local bodyTransform = GetBodyTransform(newBody)

		SetBodyTransform(newBody, Transform(VecAdd(GetPlayerTransform(propid).pos, Vec(0, 0, 2)), bodyTransform.rot))
		SetBodyDynamic(newBody, true)
		server.disableBodyCollission(newBody, true)

		shared.players.hiders[playerid].propBody = newBody
		shared.players.hiders[playerid].propBackupShape = backUpShape
		SetBodyTransform(backUpBody, Transform(Vec(-1000, 10, 0)))
		SetBodyDynamic(backUpBody, false)
		server.disableBodyCollission(backUpBody, false)

		SetProperty(newShape, "strength", 10) -- Shapes only get destroyed by weapons
	end
end

function server.propRegenerate(playerid)
    local propBody = helperGetPlayerPropBody(playerid)
	if propBody then
        Delete(propBody)

		local backupShape = shared.players.hiders[playerid].propBackupShape

		-- I tried doing just copyshapecontents but it didnt get rid of the "IsBodyBroken" property and breaks my logic.
		-- Therefor I will keep it like this for now
		local newBody, newShape = server.cloneShape(backupShape) 

		SetBodyTransform(newBody, GetPlayerTransform(playerid))
		SetBodyDynamic(newBody, true)
		server.disableBodyCollission(newBody, true)

		shared.players.hiders[playerid].propBody = newBody

		SetProperty(newShape, "strength", 10)
		SetProperty(newShape, "density", 1)

		local emissiveScale = GetProperty(backupShape, "emissiveScale")
		SetProperty(newShape, "emissiveScale", emissiveScale * 2)

		--SetInt('options.game.thirdperson',1, true)
	end
end

function server.cloneShape(shape, collisison)
	local newBody = Spawn('<body pos="0.0 0 0.0" dynamic="true"> <voxbox tags="deleteTempShape" size="1 1 1"/> </body>',
		Transform(), false)[1]                                                                                                                -- Temo shape because empty bodies get rmoved?
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
			SetShapeCollisionFilter(shapes[i], 128, 1)
		end
	end
end

