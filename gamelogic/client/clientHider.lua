function client.hiderTick()
	if not client.state.matchEnded then
		if client.player.hider.hidingAttempt then
			if shared.players.hiders[GetLocalPlayer()].isPropPlaced == true or shared.players.hiders[GetLocalPlayer()].isPropClipping == false then
				client.player.hider.hidingAttempt = false
			end
		end

		client.hiderCamera()
	end
	client.highlightClippingProps()
end

function client.hiderCamera()
	local body = shared.players.hiders[GetLocalPlayer()].propBody
	if body ~= -1 then
		if shared.players.hiders[GetLocalPlayer()].isPropPlaced then
			local body_center = AutoBodyCenter(body)
			local dt = GetTimeStep()
			do -- Camera Rotation
				local mouse_rotation = Vec(-InputValue("cameray") * 50, -InputValue("camerax") * 50)
				client.camera.Rotation = VecAdd(client.camera.Rotation, mouse_rotation)
				client.camera.Rotation[1] = AutoClamp(client.camera.Rotation[1], -89, -3)

				client.camera.dist = AutoClamp(client.camera.dist + InputValue("mousewheel") / -2, 2, 10)

			end
			local camera_rotation_quat = QuatEuler(unpack(client.camera.Rotation))

			local target_position = VecCopy(body_center)
			local outwards = QuatRotateVec(camera_rotation_quat, Vec(0, 0, 1))

			QueryRejectBody(body)
			local dir = VecNormalize(VecSub(AutoSM_Get(client.camera.SM.pos), VecAdd(body_center,Vec(0,1,0))))
			local hit, dist = QueryRaycast(VecAdd(body_center,Vec(0,1,0)), dir, client.camera.dist, 0.2, false)

			if hit then
				dist = dist - 0.2
			else
				dist = client.camera.dist
			end

			target_position = VecAdd(target_position, VecScale(outwards, dist))

				AutoSM_Update(client.camera.SM.pos, target_position, dt)
			AutoSM_Update(client.camera.SM.rot, camera_rotation_quat, dt)

			local sm_transform = Transform(AutoSM_Get(client.camera.SM.pos), AutoSM_Get(client.camera.SM.rot))
			SetCameraTransform(sm_transform)
		end
	end
end

function client.hiderUpdate()
    if helperIsPlayerHider() and teamsIsSetup() then
		client.sendHideRequest()
        client.SelectProp()
		if client.hints.tauntCooldown == 0 and GetString("game.player.tool", GetLocalPlayer()) == "taunt" and InputPressed("usetool", GetLocalPlayer()) then
			ServerCall("server.taunt", GetPlayerTransform(GetLocalPlayer()).pos, GetLocalPlayer())
			client.hints.tauntCooldown = 5
		end

		if client.hints.tauntCooldown > 0 then
			client.hints.tauntCooldown = math.max(0, client.hints.tauntCooldown - GetTimeStep())
		end
	end
end

function client.SelectProp()
	client.HighlightDynamicBodies()

	if client.player.lookAtShape ~= -1 then
		if InputPressed("interact") then
			ServerCall("server.PropSpawnRequest", GetLocalPlayer(), client.player.lookAtShape, GetCameraTransform())
		end
	end
end

function client.sendHideRequest()
    if InputPressed("flashlight") then
		local playerID = GetLocalPlayer()
        if not shared.players.hiders[playerID].isPropClipping and shared.players.hiders[playerID].propBody ~= -1 then
            ServerCall("server.clientHideRequest", playerID)
			client.player.hider.hidingAttempt = false
		end
		if shared.players.hiders[playerID].isPropClipping then
			client.player.hider.hidingAttempt = true
		end
    end
end

function client.playTaunt(pos)
--	PlaySound(taunt,GetPlayerTransform().pos,10,true,1)
end

function client.HighlightDynamicBodies()
	if helperIsPlayerHidden() then return end
	local playerTransform = GetPlayerTransform()
	local aa = VecAdd(playerTransform.pos, Vec(5, 5, 5))
	local bb = VecAdd(playerTransform.pos, Vec(-5, -5, -5))

	QueryRequire("physical dynamic large")

    -- Cant become a vehicle therefor we dont highlight it
	local vehicles = FindVehicles("", true)

	for i = 1, #vehicles do
		QueryRejectVehicle(vehicles[i])
	end

	local bodies = QueryAabbBodies(bb, aa)

	client.player.lookAtShape = -1

	for i = 1, #bodies do
		local body = bodies[i]
		-- Dont highlight ourselves
        if shared.players.hiders[GetLocalPlayer()].propBody ~= body then
			local shapes = GetBodyShapes(body)

            -- We can only transform into intact shapes and bodies that only have one shape.
            -- As of right now I didnt bother implementing multi shape bodies
			if #shapes == 1 and not IsBodyBroken(body) and IsBodyDynamic(body) then
				local shape = shapes[1]
				local x, y, z = GetShapeSize(shape)
				local voxelCount = GetShapeVoxelCount(shape)

				local unqualified = false
				if shared.gameConfigs.enableSizeLimits == 1 then
                    -- 70 is large enough for containers and 150 is reasonably large to still see easily
					if (x > 70 or y > 70 or z > 70 or voxelCount < 150) then
						unqualified = true
					else
						DrawBodyOutline(body, 1, 1, 1, 1)
					end
				else
                    -- Even if players deactivate size limit we make sure that you cant just become a 
                    -- Single voxel objects, or a very thin stick
					if voxelCount < 20
						or not ((x > 1 and y > 1)
							or (x > 1 and z > 1)
							or (y > 1 and z > 1))
					then
						unqualified = true
					else
						DrawBodyOutline(body, 1, 1, 1, 1)
					end
				end

				local lookAtShape = playerGetLookAtShape(10, GetLocalPlayer())

				if lookAtShape == shape and unqualified == false then
					DrawBodyHighlight(body, 0.8)
					client.player.lookAtShape = shape
				end
			end
		end
	end
end

function client.highlightClippingProps()
    if shared.players.hiders[GetLocalPlayer()].propBody ~= -1 and not shared.players.hiders[GetLocalPlayer()].isPropPlaced then
		local clippingShapes = checkPropClipping(GetLocalPlayer())
        for i = 1, #clippingShapes do
            DrawShapeOutline(clippingShapes[i], 1,0,0,1)
        end
    end
end