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
	client.HighlightDynamicBodies()
	
end


function client.hiderCamera()
	local body = helperGetPlayerPropBody()
	if body ~= -1 and body ~= false then
		if helperIsPlayerHidden() then
			local body_center = AutoBodyCenter(body)
			local dt = GetTimeStep()
			do -- Camera Rotation
				local mouse_rotation = Vec(-InputValue("cameray") * 50, -InputValue("camerax") * 50)
				client.camera.Rotation = VecAdd(client.camera.Rotation, mouse_rotation)
				client.camera.Rotation[1] = AutoClamp(client.camera.Rotation[1], -100, 20)

				client.camera.dist = AutoClamp(client.camera.dist + InputValue("mousewheel") / -2, 2, 10)

			end
			local camera_rotation_quat = QuatEuler(unpack(client.camera.Rotation))

			local target_position = VecCopy(body_center)
			local outwards = QuatRotateVec(camera_rotation_quat, Vec(0, 0, 1))

			QueryRejectBody(body)
			local dir = VecNormalize(VecSub(AutoSM_Get(client.camera.SM.pos), VecAdd(body_center,Vec(0,1,0))))
			local hit, dist = QueryRaycast(VecAdd(body_center,Vec(0,1,0)), dir, client.camera.dist, 0.2, false)

			if hit then
				dist = dist - 0.3
			else
				dist = client.camera.dist
			end

			target_position = VecAdd(target_position, VecScale(outwards, dist))

				AutoSM_Update(client.camera.SM.pos, target_position, dt)
			AutoSM_Update(client.camera.SM.rot, camera_rotation_quat, dt)

			local sm_transform = Transform(AutoSM_Get(client.camera.SM.pos), AutoSM_Get(client.camera.SM.rot))
			SetCameraTransform(sm_transform)
		else
			local playerTransform = GetPlayerTransform()
			local aa = VecAdd(playerTransform.pos, Vec(10, 5, 10))
			local bb = VecAdd(playerTransform.pos, Vec(-10, -5, -10))

			QueryRequire("physical visible")
			QueryInclude("player")
			QueryRejectBody(body)
			DrawBodyOutline(body,  0, 0.95, 0.85, 0.6)

			local bodies = QueryAabbBodies(bb, aa)
			SetPivotClipBody(bodies[1], 0)
			for i = 1, #bodies do
				SetPivotClipBody(bodies[i])
			end
		end
	end
end

function client.hiderUpdate()
    if helperIsPlayerHider() and teamsIsSetup() then
		client.sendHideRequest()
        client.SelectProp()

		if client.hint.tauntCooldown == 0 and InputDown("usetool", GetLocalPlayer()) then
			client.player.taunting = true
		else
			client.player.taunting = false
			client.player.tauntChargeCount = GetTime() + client.gameConfig.tauntChargeTime
		end

		if client.player.tauntChargeCount <= GetTime() then 
			ServerCall("server.tauntBroadcast", GetPlayerTransform(GetLocalPlayer()).pos, GetLocalPlayer())
			client.hint.tauntCooldown = 5
		end

		if client.hint.tauntCooldown > 0 then
			client.hint.tauntCooldown = math.max(0, client.hint.tauntCooldown - GetTimeStep())
		end
	end
end

function client.SelectProp()
	local cooldown = AutoClamp(math.floor(shared.players.hiders[GetLocalPlayer()].transformCooldown-shared.serverTime+0.4),0,3)
	if not helperIsHuntersReleased() then
		cooldown = 0
	end

	if client.player.lookAtShape ~= -1 and cooldown == 0 and not helperIsPlayerHidden() then
		if InputPressed("interact") then
			ServerCall("server.PropSpawnRequest", GetLocalPlayer(), client.player.lookAtShape, client.calculatePlayerHurtValue(client.player.lookAtShape),  GetCameraTransform())
		end
	end
end

function client.sendHideRequest()

    if InputPressed("flashlight") and not helperIsPlayerHidden() then
		local playerID = GetLocalPlayer()
        if not shared.players.hiders[playerID].isPropClipping and helperGetPlayerPropBody() and client.player.hideCoolDown <= GetTime() then
            ServerCall("server.clientHideRequest", playerID)
			client.player.hider.hidingAttempt = false
			client.player.hideCoolDown = GetTime() + client.gameConfig.hideCoolDown
		end
		if shared.players.hiders[playerID].isPropClipping then
			client.player.hider.hidingAttempt = true
		end
    end
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

	QueryRejectBody(helperGetPlayerPropBody())
	local bodies = QueryAabbBodies(bb, aa)

	client.player.lookAtShape = -1

	for i = 1, #bodies do
		local body = bodies[i]
		-- Dont highlight ourselves
        if shared.players.hiders[GetLocalPlayer()].propBody ~= body and IsBodyDynamic(body) then
			local shapes = GetBodyShapes(body)
			for i = 1, #shapes do
				local shape = shapes[i]
				-- We can only transform into intact shapes 
				-- As of right now I didnt bother implementing multi shape bodies
				if not IsShapeBroken(shape) then
					local x, y, z = GetShapeSize(shape)
					local voxelCount = GetShapeVoxelCount(shape)

					local unqualified = false
					if shared.gameConfig.minimumSizeLimit then
						-- 70 is large enough for containers and 150 is reasonably large to still see easily
						if voxelCount < 150 then
							unqualified = true
						end
					else
						if voxelCount < 20
							or not ((x > 1 and y > 1)
								or (x > 1 and z > 1)
								or (y > 1 and z > 1))
						then
							unqualified = true
						end
					end
					if shared.gameConfig.maximumSizeLimit then 
						if (x > 70 or y > 70 or z > 70) then 
							unqualified = true
						end
					end

					local lookAtShape = playerGetLookAtShape(10, GetLocalPlayer())
					
					if unqualified == false then 
						DrawShapeOutline(shape, 1, 1, 1, 1)
						if lookAtShape == shape then
							DrawShapeHighlight(shape, 0.8)
							client.player.lookAtShape = shape
						end
					end
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



function client.calculatePlayerHurtValue(shape)
		-- Sort axes so flat/thin shapes behave correctly
	local function getSortedAxes(x, y, z)
		local t = {x, y, z}
		table.sort(t)
		return t[1], t[2], t[3] -- small, mid, large
	end

	-- Generalized size - damage factor (small = high)
	local function sizeDamageFactor(mid)
		mid = math.max(mid, 1)
		-- Linear inverse scaling
		local t = mid / 30         -- 1- 30 scale
		local factor = 1 - t
		-- Extra boost for very small objects (generalized)
		-- Smooth: smaller - more damage
		if mid <= 8 then
			factor = factor + (8 - mid) * 0.08
		end
		return math.min(factor, 1.0)
	end

	-- Solidity - damage factor (hollow = high)
	local function solidityDamageFactor(sol)
		-- Weighted average of axes
		return 1 - (sol.min * 0.7 + sol.avg * 0.3)
	end

	local function getShapeSolidity(shape)
		-- Return cached result
		-- This function will only be called once on client side as calling it continiously can lag the game. 
		-- Its also done on the client to distribute the load and not bog down the host. 
		-- This function accepts a shape and will project / test from all 3 axis to determin how "see through"/solid it is 
		-- For example a table is a very small U shape from the side and is hard to hit because of that. 
		-- A box or container is basically solid box from all sides therefor is a lot easier to hit. 
		-- Depending on this value its determinede how easy the shape is to hit 
		-- It is also used to dermine how many hits it takes to kill the player 
		-- Using only Voxel count or surface area is not enough to determine that

		local x,y,z = GetShapeSize(shape)

		local yProj, xProj, zProj = 0,0,0

		-- top
		for xi=0,x-1 do
			for zi=0,z-1 do
				for yi=0,y-1 do
					local mat = GetShapeMaterialAtIndex(shape, xi, yi, zi)
					if mat ~= "" and mat ~= "unphysical" then
						yProj = yProj + 1
						break
					end
				end
			end
		end

		-- front
		for yi=0,y-1 do
			for zi=0,z-1 do
				for xi=0,x-1 do
					local mat = GetShapeMaterialAtIndex(shape, xi, yi, zi)
					if mat ~= "" and mat ~= "unphysical" then
						xProj = xProj + 1
						break
					end
				end
			end
		end

		-- side
		for xi=0,x-1 do
			for yi=0,y-1 do
				for zi=0,z-1 do
					local mat = GetShapeMaterialAtIndex(shape, xi, yi, zi)
					if mat ~= "" and mat ~= "unphysical" then
						zProj = zProj + 1
						break
					end
				end
			end
		end

		local solX = xProj / (y*z)
		local solY = yProj / (x*z)
		local solZ = zProj / (x*y)

		local solMin = math.min(solX, solY, solZ)
		local solAvg = (solX + solY + solZ) / 3
		local solFinal = solMin * 0.65 + solAvg * 0.35

		local result =
		{
			x = solX,
			y = solY,
			z = solZ,
			min = solMin,
			avg = solAvg,
			final = solFinal
		}

		return result
	end


	local x, y, z = GetShapeSize(shape)
	local _, mid, _ = getSortedAxes(x, y, z)

	local sol = getShapeSolidity(shape) -- expects sol.min, sol.avg

	-- Base factors
	local sizeFactor = sizeDamageFactor(mid)
	local solidityFactor = solidityDamageFactor(sol)

	-- Combine: size dominates small objects, solidity still matters
	local difficulty = sizeFactor * 0.65 + solidityFactor * 0.35

	local minDmg = 0.05
	local maxDmg = 0.6

	-- Map difficulty - damage
	local damage = AutoClamp((minDmg + difficulty * (maxDmg - minDmg)), 0.126 , 0.49)

	-- Clamp to 2 - 10 Health
	return damage
end

function client.grab() -- Is being used in client.draw 
	if InputDown("grab") and not helperIsPlayerHidden() and helperGetPlayerPropBody() then 
		local x,y = UiGetMousePos()
		local dir = UiPixelToWorld(x, y)
		local pos = GetCameraTransform().pos
		QueryRejectBody(helperGetPlayerPropBody())
		QueryRequire("physical dynamic")
		local hit, dist,_, shape = QueryRaycast(pos, dir, 10)
		if hit and not shared.players.hiders[GetLocalPlayer()].grabbing then
			local hitPoint = VecAdd(pos, VecScale(dir, dist))
			local localPoint = TransformToLocalPoint(GetBodyTransform(GetShapeBody(shape)), hitPoint)

			client.player.grab = {
				grabBody = GetShapeBody(shape),
				dist = dist,
				localPoint = localPoint
			}

			ServerCall("server.clientGrabRequest", GetLocalPlayer(), GetShapeBody(shape), localPoint, dist, dir)
		end
		if InputDown("grab") and shared.players.hiders[GetLocalPlayer()].grabbing then
			SetPivotClipBody(client.player.grab.grabBody, 0)

			local body = client.player.grab.grabBody
			local targetDist = client.player.grab.dist
			local localPos = client.player.grab.localPoint
			local playerT = GetPlayerCameraTransform()
			local targetPoint = VecAdd(playerT.pos, VecScale(dir, targetDist))
			local worldPoint = TransformToParentPoint(GetBodyTransform(body), localPos)
			local pointDist = VecLength(VecSub(worldPoint, targetPoint))

			local xAxis = VecNormalize(VecSub(targetPoint, playerT.pos))
			local zAxis = VecNormalize(VecSub(playerT.pos, worldPoint))

			local quat = QuatAlignXZ(xAxis, zAxis)

			DrawSprite(client.assets.grabHand, Transform(worldPoint,quat), 0.4, 0.4, 1,1,1,1 ,false, false)
			local d = pointDist / 4
			DrawLine(worldPoint, targetPoint, 1, 1 - d, 1 - d , 1 - d)

			ServerCall("server.updateClientGrab", GetLocalPlayer(), dir)
		end
	end
end