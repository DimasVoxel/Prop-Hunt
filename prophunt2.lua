--[[
#version 2
#include "script/include/player.lua"
#include "Automatic.lua"
#include "/mplib/mp.lua"
]]


server.lobbySettings = {}
server.lobbySettings.enforceLimit = 1 -- Using 1 and 0 instead of booleans
server.lobbySettings.forceTeams = 1
server.lobbySettings.randomTeams = 1
server.lobbySettings.amountHunters = 1
server.lobbySettings.hunterBulletTimer = 0
server.lobbySettings.pipeBombTimer = 0
server.lobbySettings.bluetideTimer = 0
server.lobbySettings.tauntReload = 0
server.lobbySettings.midGameJoin = 0 
server.lobbySettings.hiderHunters = 0

server.game = {}
server.game.time = 0

server.game.respawnQueue = {}
server.game.hunterBulletTimer = 0
server.game.hunterPipeBombTimer = 0
server.game.bluetideTimer = 0
server.game.hunterPIpeBombEnabled = true
server.game.hunterFreed = false
server.game.hunterHintTimer = 0
server.game.tauntSnd = 0
server.game.tauntReloadTimer = 30

server.hunters = {}
server.hunters.hunter = {}
server.hiders = {}

shared.hiders = {}
shared.game = {}
shared.game.time = 0
shared.game.hunterFreed = false
shared.game.nextHint = 0

shared.stats = {}
shared.stats.hiders = {}
shared.stats.OriginalHunters = {}
shared.stats.wasHider = {}

client.game = {}
client.game.hider = {}
client.game.hider.lookAtShape = -1
client.game.hider.hiderOutline = {}
client.game.hider.triedHiding = false

client.hint = {}
client.hint.closestPlayerHint = {}
client.hint.closestPlayerHint.distance = 0
client.hint.closestPlayerHint.timer = 0
client.hint.closestPlayerHint.detailed = false

client.hint.closestPlayerArrowHint = {}
client.hint.closestPlayerArrowHint.transform = Transform()
client.hint.closestPlayerArrowHint.timer = 0
client.hint.closestPlayerArrowHint.player = 0

client.hint.meow = {}
client.hint.meow.timer = 0
client.hint.tauntCooldown = 0

client.finalHint = 0
client.finalHintLerpDelay = 3

client.camera = {}
client.camera = {}
client.camera.Rotation = Vec() -- Using a Vec instead of a quat so it doesn't cause any roll by mistake.

client.camera.SM = {
        pos = AutoSM_Define(Vec(), 2, 0.8, 1),      -- Inital Value, Frequency, Dampening, Response
        rot = AutoSM_DefineQuat(Quat(), 2, 0.8, 1), -- Inital Value, Frequency, Dampening, Response
    }

client.camera.dist = 8

function server.init()
	RegisterTool("taunt", "taunt", "", 1)
	server.game.tauntSnd = LoadSound('MOD/assets/taunt0.ogg')

	hudInit(true)
	hudAddUnstuckButton()
	teamsInit(3)
	teamsSetNames({ "Hiders", "Hunters" ,"Spectator"})
	teamsSetColors { { 0, 0.95, 0.85 }, { 1, 0, 0 }, {1,1,1} }

	statsInit()

	spawnInit()
	toolsSetDropToolsOnDeath(false)
	spawnSetDefaultLoadoutForTeam(1, { {"taunt", 1} })                  -- Hiders
	spawnSetDefaultLoadoutForTeam(2, {{ "gun", 3 }, { "pipebomb", 0 }, { "steroid", 0 }}) -- Hunters

	spawnSetRespawnTime(10)
end

function server.start(settings)
	server.game.time = settings.time
	shared.game.time = math.floor(server.game.time)

	server.lobbySettings.roundLength = settings.time
	server.lobbySettings.enforceLimit = settings.enforceLimit
	server.lobbySettings.forceTeams = settings.forceTeams
	server.lobbySettings.randomTeams = settings.randomTeams
	server.lobbySettings.amountHunters = settings.amountHunters
	server.lobbySettings.hunterBulletTimer = settings.bulletTimer
	server.lobbySettings.pipeBombTimer = settings.pipeBombTimer
	server.lobbySettings.bluetideTimer = settings.bluetideTimer
	server.lobbySettings.hunterHinttimer = settings.hunterHinttimer
	server.lobbySettings.tauntReload = settings.tauntReload
	server.lobbySettings.midGameJoin = settings.midGameJoin
	server.lobbySettings.hiderHunters = settings.hiderHunters
	server.lobbySettings.hints = settings.hints

	server.game.hunterHintTimer = settings.hunterHinttimer
	--server.lobbySettings.joinHunters = settings.joinHunters

	if settings.pipeBombTimer == -1 then
		server.game.hunterPIpeBombEnabled = false
	end

	countdownInit(settings.hideTime, "hidersHiding")

	teamsStart(false)

	for id in Players() do
		shared.hiders[id] = {}
		shared.hiders[id].propBody = -1
		shared.hiders[id].propBackupShape = -1
		shared.hiders[id].isPropPlaced = false
		shared.hiders[id].isHider = true
		shared.hiders[id].dead = false

		server.hunters[id] = {}
	end
end

function server.deadTick()
	for id in Players() do
		if teamsGetTeamId(id) == 1 then
			local health = GetPlayerHealth(id)
			if health == 0 and server.game.hunterFreed then

				eventlogPostMessage({id, " Was found"  })
				shared.hiders[id].dead = true
				Delete(shared.hiders[id].propBody)
				Delete(shared.hiders[id].propBackupShape)
				shared.hiders[id] = {}
				server.game.respawnQueue[id] = true

				if server.lobbySettings.hiderHunters then
					teamsAssignToTeam(id, 2)
				else
					teamsAssignToTeam(id, 3)
				end

				shared.stats.wasHider[#shared.stats.wasHider+1] = {id, math.floor(server.lobbySettings.roundLength - server.game.time)}

				SetPlayerParam("healthRegeneration", true, id)
				SetPlayerParam("collisionMask", 1, id)
				SetPlayerParam("walkingSpeed", 1, id)
			end
		end
	end
end

function server.destroy()
	for i = 1, #shared.hiders do
		Delete(shared.hiders[i].propBody)
		Delete(shared.hiders[i].propBackupShape)
	end
end

function server.tick(dt)
	-- AutoInspectWatch(shared, " ", 3, " ", false)

	if teamsTick(dt) then
		spawnRespawnAllPlayers()

		for id in Players() do
			if teamsGetTeamId(id) == 2 then
				shared.stats.OriginalHunters[#shared.stats.OriginalHunters+1] = id
			end
		end
	end

	for id in PlayersRemoved() do
		eventlogPostMessage({id, "Left the game"})
	end

	if server.game.time <= 0 then
		for p in Players() do
			DisablePlayerInput(p)
		end
		return
	end

	if not teamsIsSetup() then
		for p in Players() do
			DisablePlayer(p)
		end
		return
	end


	for p in Players() do
		if teamsGetTeamId(p) == 3 then
			SetPlayerHealth(0, p)
			SetPlayerTransform(Transform(Vec(0, 3000, 0)), p)
			DisablePlayer(p)
		end
	end


	--if InputPressed("k") then 
	--	server.game.time = 60
	--end

	spawnTick(dt, teamsGetPlayerTeamsList())
	eventlogTick(dt)
	countdownTick(dt, 0, false)


	if #teamsGetTeamPlayers(1) == 0 and teamsIsSetup() or GetPlayerCount() == 1  then
		server.game.time = 0
		shared.game.time = 0
		server.game.hunterFreed = true
		shared.game.hunterFreed = true
		return
	end


	if #teamsGetTeamPlayers(2) == 0 and teamsIsSetup() then
		local id = teamsGetTeamPlayers(1)[#teamsGetTeamPlayers(1)]

		eventlogPostMessage({id, "Was moved to Hunter because all hunters left"  })
		shared.hiders[id].dead = false
		Delete(shared.hiders[id].propBody)
		Delete(shared.hiders[id].propBackupShape)
		shared.hiders[id] = {}
		server.game.respawnQueue[id] = true

		teamsAssignToTeam(id, 2)
		spawnRespawnPlayer(id)

		SetPlayerParam("healthRegeneration", true, id)
		SetPlayerParam("collisionMask", 1, id)
		SetPlayerParam("walkingSpeed", 1, id)
	end

	server.deadTick()

	if server.game.hunterFreed == false then
		local data, finished = GetEvent("countdownFinished", 1)

		for id in Players() do
			if teamsGetTeamId(id) == 2 then
				if data == "hidersHiding" and finished then
					spawnRespawnPlayer(id)

					server.game.hunterFreed = true
					shared.game.hunterFreed = true

					eventlogPostMessage({ "loc@EVENT_GLHF" })
				else
					SetPlayerTransform(Transform(Vec(0, 10000, 0)), id)
					SetPlayerVelocity(Vec(0, 0, 0), id)
					DisablePlayer(id)
				end
			end
		end
	end

	for id in Players() do
		if teamsGetTeamId(id) == 1 then
			server.hiderTick(id)
		elseif teamsGetTeamId(id) == 2 then
			server.hunterTick(id)
		end
	end

	if server.game.hunterFreed then
		server.game.hunterHintTimer = server.game.hunterHintTimer - dt
		if server.game.hunterHintTimer < 0 then
			server.game.hunterHintTimer = server.lobbySettings.hunterHinttimer
			server.TriggerHint()
		end
	end


	if server.game.hunterFreed then
		server.game.time = server.game.time - dt  -- update time
		shared.game.time = math.floor(server.game.time) -- sync only whole seconds to client
	else
		for id in Players() do
			SetPlayerHealth(1, id)
		end
	end
end

function newPlayerJoinRoutine()
	local loadout = {{ "gun", 3 }, { "pipebomb", 0 }, { "steroid", 0 }}
	for id in PlayersAdded() do
		if server.lobbySettings.midGameJoin then
			spawnRespawnPlayer(id)
			eventlogPostMessage({id, " Joined the game"  })
		else
			eventlogPostMessage({id, " Spectates the game"  })
		end

		if loadout ~= nil then
			local tools = ListKeys("game.tool")
			for ti=1, #tools do
				local tool = tools[ti]
				SetToolEnabled(tool, false, id)
				SetToolAmmo(tool, 0, id)
			end

			for i=1,#loadout do
				SetToolEnabled(loadout[i][1], true, id)
				SetToolAmmo(loadout[i][1], loadout[i][2], id)
			end

			-- make the first tool in loadout the active tool
			if #loadout > 0 then
				SetPlayerTool(loadout[1][1], id)
			else
				SetPlayerTool("none", id)
			end
		end
	end
end




function server.hunterTick(id)
	if server.game.hunterFreed then
		local dt = GetTimeStep()
		server.game.hunterBulletTimer = server.game.hunterBulletTimer - dt
		server.game.hunterPipeBombTimer = server.game.hunterPipeBombTimer - dt
		server.game.bluetideTimer = server.game.bluetideTimer - dt
		

		if server.game.hunterBulletTimer < 0 then
			server.game.hunterBulletTimer = server.lobbySettings.hunterBulletTimer
			SetToolAmmo("gun", math.min(GetToolAmmo("gun", id) + 1, 10), id)
			--SetToolAmmo("pipebomb", math.min(GetToolAmmo("pipebomb", id) + 1, 3), id)
		end

		if server.game.hunterPipeBombTimer < 0 then
			server.game.hunterPipeBombTimer = server.lobbySettings.pipeBombTimer
			SetToolAmmo("pipebomb", math.min(GetToolAmmo("pipebomb", id) + 1, 3), id)
		end

		if server.game.bluetideTimer < 0 then
			server.game.bluetideTimer = server.lobbySettings.bluetideTimer
			SetToolAmmo("steroid", math.min(GetToolAmmo("steroid", id) + 1, 3), id)
		end

	end
end

function server.TriggerHint()
	-- Only trigger in first 20% of round time
	--if server.game.time > (server.lobbySettings.roundLength * 0.2) then
	--	return
	--end

	if server.lobbySettings.hints == 0 then
		return
	end

	for myId in Players() do
		local closestDist = math.huge
		local cloestTransform = Transform()
		local closestPlayer = 0

		-- Get my transform depending on team
		local myTransform
		if teamsGetTeamId(myId) == 1 then
			-- Hider
			local myBody = shared.hiders[myId].propBody ~= -1
			if myBody then
				myTransform = GetBodyTransform(shared.hiders[myId].propBody)
			else
				myTransform = GetPlayerTransform(myId)
			end
		elseif teamsGetTeamId(myId) == 2 then
			-- Hunter
			myTransform = GetPlayerTransform(myId)
		end

		if myTransform then
			for otherId in Players() do
				if myId ~= otherId and teamsGetTeamId(myId) ~= teamsGetTeamId(otherId) then
					-- Get other player transform
					local otherTransform
					if teamsGetTeamId(otherId) == 1 then
						local otherBody = shared.hiders[myId].propBody ~= -1
						if otherBody then
							otherTransform = GetBodyTransform(otherBody)
						else
							otherTransform = GetPlayerTransform(otherId)
						end
					elseif teamsGetTeamId(otherId) == 2 then
						otherTransform = GetPlayerTransform(otherId)
					end

					if otherTransform then
						local dist = VecLength(VecSub(myTransform.pos, otherTransform.pos))
						if dist < closestDist then
							closestDist = dist
							cloestTransform = otherTransform
							closestPlayer = otherId
						end
					end
				end
			end
		end

		local detail  
		if server.game.time < (server.lobbySettings.roundLength * 0.7) then 
			local myPos = GetPlayerTransform(myId).pos[2]
			-- if closestransform within 3 meters on z pos its level if higher its higher if lower its lower
			if cloestTransform.pos[2] < myPos + 2.5 and cloestTransform.pos[2] > myPos - 2.5 then
				detail = "and is level with you."
			elseif cloestTransform.pos[2] > myPos then
				detail = "and is above you."
			else
				detail = "and is below you."
			end
		end

		if closestDist < math.huge then
			ClientCall(myId, "client.hintShowCloestPlayer", math.floor(closestDist * 10) / 10, 5, detail)
		end

		if server.game.time < (server.lobbySettings.roundLength * 0.7) and closestDist > 50 then
			ClientCall(myId, "client.hintShowArrow", cloestTransform, closestPlayer, 5)
		end
	end
end


function server.hiderTick(id)
	if teamsIsSetup() then
		SetPlayerParam("healthRegeneration", false, id)
		SetPlayerVehicle(0, id)

		if shared.game.hunterFreed then
			local dt = GetTimeStep()
			server.game.tauntReloadTimer = server.game.tauntReloadTimer - dt

			if server.game.tauntReloadTimer < 0 then
				if server.game.forcedTaunt then
					server.game.forcedTaunt = false
					server.taunt(GetPlayerTransform(id).pos, id)
					SetToolAmmo("taunt", 6, id)
				end

				server.game.tauntReloadTimer = server.lobbySettings.tauntReload
				SetToolAmmo("taunt", math.min(GetToolAmmo("taunt", id) + 1, 10), id)
				if GetToolAmmo("taunt", id) == 10 then
					server.game.forcedTaunt = true
				else
					server.game.forcedTaunt = false
				end
			end
		end

		if shared.hiders[id].propBody ~= -1 then
			SetPlayerHidden(id)
			if not shared.hiders[id].isPropPlaced then
				SetPlayerParam("collisionMask", 255 - 4, id)
			else
				SetPlayerParam("collisionMask", 1 , id)
				SetPlayerParam("walkingSpeed", 0, id)
			end

			if IsBodyBroken(shared.hiders[id].propBody) then
				SetPlayerHealth(GetPlayerHealth(id) - 0.33, id)

				local aa,bb = GetBodyBounds(shared.hiders[id].propBody)
				local center = VecLerp(aa, bb, 0.5)
				SetPlayerTransform(Transform(VecAdd(center, Vec(0, 0.0, 0)),GetPlayerCameraTransform(id).rot), id)

				server.propRegenerate(id, shared.hiders[id].propBackupShape)
				shared.hiders[id].isPropPlaced = false
				ClientCall(0, "client.highlightPlayer", shared.hiders[id].propBody)
			end

			if IsPointInBoundaries(GetPlayerTransform(id).pos) then

			end
		end
	end
end

function disableBodyCollission(body, bool)
	local shapes = GetEntityChildren(body, "", true, "shape")

	for i = 1, #shapes do
		if bool then
			SetShapeCollisionFilter(shapes[i], 4, 4)
		else
			SetShapeCollisionFilter(shapes[i], 128, 1)
		end
	end
end

function server.taunt(pos, id)
	--ClientCall(0, "client.playTaunt", pos)
	SetToolAmmo("taunt", math.max(GetToolAmmo("taunt", id) - 3 ,1), id)
	PlaySound(server.game.tauntSnd,pos,2,true,1)
end

function server.update()

	if server.game.time <= 0 then
		return
	end

	for id in Players() do
		if teamsGetTeamId(id) == 1 then
			server.hiderUpdate(id)
		elseif teamsGetTeamId(id) == 2 then
			server.hunterUpdate(id)
		end
	end
end

function server.hunterUpdate(id)

end

function server.hiderUpdate(id)


	if teamsIsSetup() then
		if shared.hiders[id].isPropPlaced then
			local aa,bb = GetBodyBounds(shared.hiders[id].propBody)
			local center = VecLerp(aa, bb, 0.5)
			if IsPointInWater(center) or InputDown('down', id) or InputDown('up', id) or InputDown('left', id) or InputDown('right', id) or InputDown('jump', id) then
				shared.hiders[id].isPropPlaced = false
				SetPlayerTransform(Transform(VecAdd(center, Vec(0, 0.2, 0)),GetPlayerCameraTransform(id).rot), id)
			end
		end

		if IsPointInWater(GetPlayerTransform(id).pos) then
			SetPlayerHealth(GetPlayerHealth(id) - GetTimeStep()/10, id)
		end

		server.handlePlayerProp(id)
		SetLightEnabled(GetFlashlight(id), false)
	end
end

function server.handlePlayerProp(id)
	local clippingProps = checkPropClipping(id)
	if #clippingProps == 0 then
		shared.hiders[id].isPropClipping = false
	else
		shared.hiders[id].isPropClipping = true
	end

	if shared.hiders[id].propBody ~= -1 then
		if shared.hiders[id].isPropPlaced then
			disableBodyCollission(shared.hiders[id].propBody, false)
			--local t = GetPlayerTransform(id)
			--SetPlayerTransform(Transform(Vec(-1000, 10 , -1000),t.rot), id)
		else
			disableBodyCollission(shared.hiders[id].propBody, true)

			local shape = GetBodyShapes(shared.hiders[id].propBody)[1]


			local playerTransform = GetPlayerTransform(id)
			local playerBhnd = TransformToParentVec(playerTransform, Vec(0, 0.5, 0))
			SetBodyVelocity(shared.hiders[id].propBody, Vec(0, 0, 0))
			SetBodyTransform(shared.hiders[id].propBody,
				Transform(VecAdd(playerTransform.pos, playerBhnd), playerTransform.rot))
		end
	end
end

function checkPropClipping(id)
	local body = shared.hiders[id].propBody
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

--- Helper Server Functions ---

function server.PropSpawnRequest(playerid, propid,cameraTransform)
	local string = "Player " .. GetPlayerName(playerid) .. " wants to spawn prop " .. propid
	local shape = playerGetLookAtShape(10, playerid, cameraTransform)
	local shapeBody = GetShapeBody(shape)

	if shape == propid and shapeBody ~= shared.hiders[playerid].propBody then
		if shared.hiders[playerid].propBody ~= -1 then
			Delete(shared.hiders[playerid].propBody)
		end

		if shared.hiders[playerid].propBackupShape ~= -1 then
			Delete(GetShapeBody(shared.hiders[playerid].propBackupShape))
		end

		local newBody, newShape = server.cloneShape(propid)
		local backUpBody, backUpShape = server.cloneShape(propid)

		local bodyTransform = GetBodyTransform(newBody)

		SetBodyTransform(newBody, Transform(VecAdd(GetPlayerTransform(propid).pos, Vec(0, 0, 2)), bodyTransform.rot))
		SetBodyDynamic(newBody, true)
		disableBodyCollission(newBody, true)

		shared.hiders[playerid].propBody = newBody
		shared.hiders[playerid].propBackupShape = backUpShape
		SetBodyTransform(backUpBody, Transform(Vec(-1000, 10, 0)))
		SetBodyDynamic(backUpBody, false)
		disableBodyCollission(backUpBody, false)

		SetProperty(newShape, "strength", 10)
		SetProperty(newShape, "density", 1)

		--SetInt('options.game.thirdperson',1, true)
	end
end

function server.propRegenerate(playerid, propid)
	if shared.hiders[playerid].propBody ~= - 1 then
		if shared.hiders[playerid].propBody ~= -1 then
			Delete(shared.hiders[playerid].propBody)
		end

		local newBody, newShape = server.cloneShape(propid)

		local bodyTransform = GetBodyTransform(newBody)

		SetBodyTransform(newBody, GetPlayerTransform(playerid))
		SetBodyDynamic(newBody, true)
		disableBodyCollission(newBody, true)

		shared.hiders[playerid].propBody = newBody

		SetProperty(newShape, "strength", 10)
		SetProperty(newShape, "density", 1)

		--SetInt('options.game.thirdperson',1, true)
	end
end

function server.clientHideRequest(playerid)
    if not shared.hiders[playerid].isPropClipping then
        shared.hiders[playerid].isPropPlaced = true
    end
end

function server.DisablePlayers(teamID, disablePlayer)
	for p in Players() do
		if teamsGetTeamId(p) == teamID or teamID == 0 then
			if disablePlayer then
				SetPlayerWalkingSpeed(0, p)
				DisablePlayerDamage(p)
				SetPlayerParam("disableinteract", true, p)
			end
		end
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

-- Client Functions

function client.init()
	client.arrow = LoadSprite("assets/arrow.png")
	client.rect = LoadSprite("gfx/white.png")
end

function client.tick()
	SetBool("game.disablemap", true)
	SetLowHealthBlurThreshold(0.01)

	client.game.matchEnded = shared.game.time <= 0.0


	if teamsGetTeamId(GetLocalPlayer()) == 1 and teamsIsSetup() then
		client.hiderTick()
	elseif teamsGetTeamId(GetLocalPlayer()) == 2 and teamsIsSetup() then
		-- Hunter Logic?
	end
	spectateTick(GetAllPlayers())
end

function client.hiderTick()
	if not client.game.matchEnded then
		if client.game.hider.triedHiding then
			if shared.hiders[GetLocalPlayer()].isPropPlaced == true or shared.hiders[GetLocalPlayer()].isPropClipping == false then
				client.game.hider.triedHiding = false
			end
		end


		for i = 1, #client.game.hider.hiderOutline do
			if client.game.hider.hiderOutline[i].timer > 0 then
				client.game.hider.hiderOutline[i].timer = client.game.hider.hiderOutline[i].timer - GetTimeStep()
				DrawBodyHighlight(client.game.hider.hiderOutline[i].body, client.game.hider.hiderOutline[i].timer)
				DrawBodyOutline(client.game.hider.hiderOutline[i].body,1,0,0, client.game.hider.hiderOutline[i].timer/4)
			end
		end

		for i = 1, #client.game.hider.hiderOutline do
			if client.game.hider.hiderOutline[i].timer < 0 then
				table.remove(client.game.hider.hiderOutline, i)
				break
			end
		end

		local body = shared.hiders[GetLocalPlayer()].propBody
		if body ~= -1 then
			if shared.hiders[GetLocalPlayer()].isPropPlaced then
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

	-- Hider Logic
	client.SelectProp()
	client.highlightClippingProps()
end

function client.update()
	if teamsGetTeamId(GetLocalPlayer()) == 1 and teamsIsSetup() then
		client.sendHideRequest()
		if client.hint.tauntCooldown == 0 and GetString("game.player.tool", GetLocalPlayer()) == "taunt" and InputPressed("usetool", GetLocalPlayer()) then
			ServerCall("server.taunt", GetPlayerTransform(GetLocalPlayer()).pos, GetLocalPlayer())
			client.hint.tauntCooldown = 5
		end

		if client.hint.tauntCooldown > 0 then
			client.hint.tauntCooldown = math.max(0, client.hint.tauntCooldown - GetTimeStep())
		end
	end
end

function client.enableThirdPerson(value)

end

function client.sendHideRequest()
    if InputPressed("flashlight") then
		local playerID = GetLocalPlayer()
        if not shared.hiders[playerID].isPropClipping and shared.hiders[playerID].propBody ~= -1 then
            ServerCall("server.clientHideRequest", playerID)
			client.game.hider.triedHiding = false
		end
		if shared.hiders[playerID].isPropClipping then
			client.game.hider.triedHiding = true
		end
    end
end

function client.SelectProp()
	client.HighlightDynamicBodies()

	if client.game.hider.lookAtShape ~= -1 then
		if InputPressed("interact") then
			ServerCall("server.PropSpawnRequest", GetLocalPlayer(), client.game.hider.lookAtShape, GetCameraTransform())
		end
	end
end

function client.playTaunt(pos)
--	DebugPrint("bla")
--	DebugPrint(HasFile('assets/taunt1.ogg'))
--	taunt = LoadSound('MOD/assets/taunt0.ogg', 5)
--	DebugPrint(taunt)
--	PlaySound(taunt,GetPlayerTransform().pos,10,true,1)
end

function client.HighlightDynamicBodies()

	if shared.hiders[GetLocalPlayer()].isPropPlaced then return end
	local playerTransform = GetPlayerTransform()
	local aa = VecAdd(playerTransform.pos, Vec(5, 5, 5))
	local bb = VecAdd(playerTransform.pos, Vec(-5, -5, -5))

	QueryRequire("physical dynamic large")

	local vehicles = FindVehicles("", true)

	for i = 1, #vehicles do
		QueryRejectVehicle(vehicles[i])
	end

	local bodies = QueryAabbBodies(bb, aa)

	client.game.hider.lookAtShape = -1

	for i = 1, #bodies do
		local body = bodies[i]
		if shared.hiders[GetLocalPlayer()].propBody ~= body then
			local shapes = GetBodyShapes(body)

			if #shapes == 1 then
				local shape = shapes[1]
				local x, y, z = GetShapeSize(shape)
				local voxelCount = GetShapeVoxelCount(shape)

				local unqualified = false
				if x > 70 or y > 70 or z > 70 or voxelCount < 150 then
					unqualified = true
				else
					DrawBodyOutline(body, 1, 1, 1, 1)
				end

				local lookAtShape = playerGetLookAtShape(10, GetLocalPlayer())

				if lookAtShape == shape and unqualified == false and IsBodyDynamic(GetShapeBody(lookAtShape)) then
					DrawBodyHighlight(body, 0.8)
					client.game.hider.lookAtShape = shape
				end
			end
		end
	end
end

function client.highlightClippingProps()
    if shared.hiders[GetLocalPlayer()].propBody ~= -1 and not shared.hiders[GetLocalPlayer()].isPropPlaced then
		local clippingShapes = checkPropClipping(GetLocalPlayer())
        for i = 1, #clippingShapes do
            DrawShapeOutline(clippingShapes[i], 1,0,0,1)
        end
    end
end

function client.hintShowCloestPlayer(dist, timer, detailed)
	client.hint.closestPlayerHint = {}
	client.hint.closestPlayerHint.distance = dist
	client.hint.closestPlayerHint.timer = timer
	client.hint.closestPlayerHint.detailed = detailed
end

function client.hintShowArrow(transform, player, timer)
	client.hint.closestPlayerArrowHint = {}
	client.hint.closestPlayerArrowHint.transform = transform
	client.hint.closestPlayerArrowHint.player = player
	client.hint.closestPlayerArrowHint.timer = timer
end

function client.showHint()
	if client.hint.closestPlayerHint.timer > 0 then

		local detail = ""
		if client.hint.closestPlayerHint.detailed then detail =  client.hint.closestPlayerHint.detailed end


		if teamsGetTeamId(GetLocalPlayer()) == 1 then
			hudDrawInformationMessage("The closest hunter is " .. client.hint.closestPlayerHint.distance .. " meters away ".. detail, 1)
		elseif teamsGetTeamId(GetLocalPlayer()) == 2 then
			hudDrawInformationMessage("The closest hider is " .. client.hint.closestPlayerHint.distance .. " meters away " .. detail, 1)
		end

		client.hint.closestPlayerHint.timer = client.hint.closestPlayerHint.timer - GetTimeStep()
	end

    if client.hint.closestPlayerArrowHint.timer > 0 then
		local pos
		if teamsGetTeamId(GetLocalPlayer()) == 1 then
			pos = TransformToParentPoint(GetPlayerTransform(client.hint.closestPlayerArrowHint.player), Vec(0,1, -2))
		elseif  teamsGetTeamId(GetLocalPlayer()) == 2 then
			pos = TransformToParentPoint(GetPlayerTransform(GetLocalPlayer()), Vec(0,1, -2))
		end


		local rot = QuatAlignXZ(VecNormalize(VecSub(pos, client.hint.closestPlayerArrowHint.transform.pos)), VecNormalize(VecSub(pos, GetCameraTransform().pos)))
		DrawSprite(client.arrow, Transform(pos, rot), 0.7, 0.7, 0.7 ,0.7,1,1,1,false,false,false)


		if VecLength(VecSub(pos, client.hint.closestPlayerArrowHint.transform.pos)) < 40 then
			client.hint.closestPlayerArrowHint.timer = client.hint.closestPlayerArrowHint.timer - GetTimeStep()*10
		end

    	client.hint.closestPlayerArrowHint.timer = client.hint.closestPlayerArrowHint.timer - GetTimeStep()
    end
end

function client.render(dt)
    if client.game.matchEnded then return end
	spectateRender(dt)
end


function client.draw(dt)
	-- during countdown, display the title of the game mode.

	hudDrawTitle(dt, "Prophunt!")
	hudDrawBanner(dt)
	hudTick(dt)

	if not client.SetupScreen(dt) then return end -- If Setup not complete dont proceed

	if teamsGetTeamId(GetLocalPlayer()) == 2 and not client.game.matchEnded and not shared.game.hunterFreed then
		UiImageBox("assets/placeholder.png", UiWidth(), UiHeight(), 0,0)
	end

	if shared.countdownName == "hidersHiding" then
		countdownDraw("Hiding Time!")
	end

	if not client.game.matchEnded then
		if teamsGetTeamId(GetLocalPlayer()) == 1 then
			client.clippingText()
			hudDrawGameModeHelpText("You are a Hider", "Search a prop and press ( E ) to transform. And press ( F ) to hide.")
		elseif teamsGetTeamId(GetLocalPlayer()) == 2 then
			hudDrawGameModeHelpText("You are a Hunter", "Search players! Shoot at props, if you find a hider make sure to kill them.")
			hudDrawPlayerWorldMarkers(teamsGetTeamPlayers(2), false, 100, teamsGetColor(2))
		end

		if shared.game.hunterFreed then
			hudDrawTimer(shared.game.time, 1)
			hudDrawScore2Teams(teamsGetColor(1), "Hiders ".. #teamsGetTeamPlayers(1), teamsGetColor(2), #teamsGetTeamPlayers(2) .. " Hunters", 1)

			client.showHint()
		end

		spectateDraw()

		if teamsGetTeamId(GetLocalPlayer()) ~= 3 then
			hudDrawRespawnTimer(spawnGetPlayerRespawnTimeLeft(GetLocalPlayer()))
			client.tauntForce()
		else
			client.spectator()
		end
	end

	hudDrawScoreboard(InputDown("shift") and not client.game.matchEnded, "", {{name="Time Survived", width=160, align="center"}}, getPlayerStats())

	if client.game.matchEnded then

		for id in Players() do
			if teamsGetTeamId(id) == 1 then

				local camPos = GetCameraTransform().pos
				local playerPos = GetPlayerTransform(id).pos

				local xAxis = Vec(0, 1 ,0)
				local zAxis = VecNormalize(VecSub(playerPos, camPos))

				local quat = QuatAlignXZ(xAxis, zAxis) 

				DrawSprite(client.rect, Transform(playerPos,quat), client.finalHint ,1.5 , 1,1,1,0.7, true, true, false)
			end
		end


		if client.finalHintLerpDelay > 0 then
			client.finalHintLerpDelay = client.finalHintLerpDelay - GetTimeStep()
		else
			client.finalHint = 2000
		end

		hudDrawResults("Game Ended!", {1, 1, 1, 0.75}, "loc@RESULTS_TITLE_TEAM_DEATHMATCH", {{name="Time Survived", width=160, align="center"}}, getEndResults())
	end

	if teamsGetTeamId(GetLocalPlayer()) == 1 then
		client.DrawTransformPrompt()
	end

	eventlogDraw(dt, teamsGetPlayerColorsList())
end

function client.highlightPlayer(body)
	client.game.hider.hiderOutline[#client.game.hider.hiderOutline+1] = { }
	client.game.hider.hiderOutline[#client.game.hider.hiderOutline].body = body
	client.game.hider.hiderOutline[#client.game.hider.hiderOutline].timer = 1
end

function client.DrawTransformPrompt()
	if client.game.hider.lookAtShape ~= -1 then

		local boundsAA, boundsBB = GetBodyBounds(GetShapeBody(client.game.hider.lookAtShape))
		local middle = VecLerp(boundsAA, boundsBB, 0.5)
		AutoTooltip("Transform Into Prop (E)", middle, false, 40, 1)
	end
end

function client.SetupScreen(dt)
	if not teamsIsSetup() then
		teamsDraw(dt)

		if not hudGameIsSetup() then
			local maxHunters = {}
			local players = GetMaxPlayers()
			for i = 1, math.max(players - 1, 12) do
				maxHunters[#maxHunters + 1] = { label = tostring(i) .. " Hunter", value = i }
			end

			local settings = {
				{
					title = "",
					items = {
						{
							key = "savegame.mod.settings.time",
							label = "Round Length",
							info = "How long one round lasts",
							options = { { label = "05:00", value = 5 * 60 }, { label = "07:30", value = 7.5 * 60 }, { label = "10:00", value = 10 * 60 }, { label = "03:00", value = 3*60 } }
						},
						{
							key = "savegame.mod.settings.hideTime",
							label = "Hide Time",
							info = "How much time hiders have to hide",
							options = {{ label = "00:30", value = 30}, { label = "00:45", value = 45 }, { label = "01:00", value = 60 }, { label = "01:30", value = 90 }, { label = "02:00", value = 120 },  }
						},
						{
							key = "savegame.mod.settings.joinHunters",
							label = "Hider Hunters",
							info = "Makes the hiders join the hunters once found.",
							options = { { label = "Enable", value = 1 }, { label = "Disable", value = 0 } }
						},
						{
							key = "savegame.mod.settings.midGameJoin",
							label = "Mid game join",
							info = "Players joining during a round will join the hunters..",
							options = { { label = "Enable", value = 1 }, { label = "Disable", value = 0 } }
						},
						{
							key = "savegame.mod.settings.hunters",
							label = "Hunters Amount",
							info =
							"The amount of hunters at the beginning of a game. There will always be atleast one hider",
							options = maxHunters
						},
						{
							key = "savegame.mod.settings.enforceLimit",
							label = "Limit Hunters",
							info =
							"At the start of each game, the server removes extra hunters if there are more hunters than are set in 'Hunters Amount'.",
							options = { { label = "Enable", value = 1 }, { label = "Disable", value = 0 } }
						},
						{
							key = "savegame.mod.settings.serverRandomTeams",
							label = "Random Hunters",
							info =
							"The server will randomize each team no matter if someone already joined hunters or hiders.",
							options = { { label = "Enable", value = 1 }, { label = "Disable", value = 0 } }
						},
						{
							key = "savegame.mod.settings.hintTimer",
							label = "Hunter Hints",
							info = "Timer when Hunters get a hint",
							"How quickly hunters get new PipeBombs.",
							options = {    { label = "60 Seconds", value = 60}, { label = "120 Seconds", value = 120}, { label = "Disable Hints", value = -1}, { label = "15 Seconds", value = 15} , { label = "30 Seconds", value = 30}, { label = "45 Seconds", value = 45}}
						},
						{
							key = "savegame.mod.settings.bulletTimer",
							label = "Bullet Reload",
							info =
							"How quickly hunters get new bullets.",
							options = {  { label = "5 Seconds", value = 5},  { label = "6 Seconds", value = 6}, { label = "7 Seconds", value = 7}, { label = "8 Seconds", value = 8}, { label = "9 Seconds", value = 9}, { label = "10 Seconds", value = 10}, { label = "1 Second", value = 1}, { label = "2 Seconds", value = 2}, { label = "3 Seconds", value = 3}, { label = "4 Seconds", value = 4} }
						},
						{
							key = "savegame.mod.settings.pipeBombTimer",
							label = "Pipebomb Reload",
							info =
							"How quickly hunters get new PipeBombs.",
							options = {  { label = "20 Seconds", value = 20}, { label = "30 Seconds", value = 30}, { label = "40 Seconds", value = 40}, { label = "50 Seconds", value = 50}, { label = "60 Seconds", value = 60}, { label = "Disable PipeBombs", value = -1}, { label = "10 Seconds", value = 10}  }
						},
						{
							key = "savegame.mod.settings.blueTide",
							label = "Bluetide Reload",
							info =
							"How quickly hunters get new Bluetides.",
							options = { { label = "20 Seconds", value = 20},  { label = "30 Seconds", value = 30}, { label = "40 Seconds", value = 40}, { label = "50 Seconds", value = 50}, { label = "60 Seconds", value = 60}, { label = "Disable BlueTide", value = -1}, { label = "10 Seconds", value = 10},   }
						},
						{
							key = "savegame.mod.settings.tauntReload",
							label = "Forced taunt",
							info ="Players get a taunt every X seconds. After reaching 10 they will be forced to taunt. Configure how quickly a player Recieves a new taunt.",
							options = { { label = "20 Seconds", value = 20}, { label = "30 Seconds", value = 30}, { label = "60 Seconds", value = 60}, { label = "Disable Forced Taunt", value = 1000000} ,{ label = "10 Seconds", value = 10}, { label = "15 Seconds", value = 15}  }
						},
						{
							key = "savegame.mod.settings.hints",
							label = "Hunter Hints",
							info ="Enable or disable hints.",
							options = { { label = "Enable", value = 1 }, { label = "Disable", value = 0 } }
						}
					}
				}
			}

			if hudDrawGameSetup(settings) then
				ServerCall("server.start", {
					time = GetFloat("savegame.mod.settings.time"),
					amountHunters = GetInt("savegame.mod.settings.hunters"),
					forceTeams = GetInt("savegame.mod.settings.forceTeams"),
					enforceLimit = GetInt("savegame.mod.settings.enforceLimit"),
					randomTeams = GetInt("savegame.mod.settings.serverRandomTeams"),
					hideTime = GetFloat("savegame.mod.settings.hideTime"),
					bulletTimer = GetInt("savegame.mod.settings.bulletTimer"),
					pipeBombTimer = GetInt("savegame.mod.settings.pipeBombTimer"),
					bluetideTimer = GetInt("savegame.mod.settings.blueTide"),
					hunterHinttimer = GetInt("savegame.mod.settings.hintTimer"),
					tauntReload = GetInt("savegame.mod.settings.tauntReload"),
					hunterHiders = GetInt("savegame.mod.settings.hunterHiders"),
					midGameJoin = GetInt("savegame.mod.settings.midGameJoin"),
					hints = GetInt("savegame.mod.settings.hints"),
				--joinHunters = GetInt("savegame.mod.settings.joinHunters")
				})
			end
		end
		return false
	end
	return true
end

-- Global Helper Function

function playerGetLookAtShape(dist, playerID, cameraT)
	local cameraT = cameraT or GetCameraTransform()
	local playerFwd = VecNormalize(TransformToParentVec(cameraT, Vec(0, 0, -1)))

	QueryRequire("physical large")
	QueryRejectBody(shared.hiders[playerID].propBody)

	local hit, dist, _, shape = QueryRaycast(cameraT.pos, playerFwd, dist, 0, false)

	DebugCross(VecAdd(cameraT.pos,VecScale(playerFwd,dist)),1,1,1,1)

	if hit and IsShapeBroken(shape) == false then
		return shape
	else
		return -1
	end
end

function client.tauntForce()
	UiPush()
	UiColor(1,1,1)
	UiTranslate(UiWidth()/2, UiHeight()-120)
	UiFont("bold.ttf",30)
	UiAlign('center middle')
	if GetToolAmmo("taunt", GetLocalPlayer()) >= 7 then
		UiText("If you get 10 taunts, the game will taunt for you! Already " .. GetToolAmmo("taunt", GetLocalPlayer()) .. " taunts!")
	end
	UiPop()
end

function client.clippingText()
	UiPush()
	UiColor(1,1,1)
	UiTranslate(UiWidth()/2, UiHeight()-160)
	UiFont("bold.ttf",30)
	UiAlign('center middle')
	if client.game.hider.triedHiding then
		UiText("You're clipping into " .. #checkPropClipping(GetLocalPlayer()) .. " shapes. Can't hide.")
	end
	UiPop()
end

function client.spectator()
	UiPush()
	UiColor(1,1,1)
	UiTranslate(UiWidth()/2, UiHeight()-190)
	UiFont("bold.ttf",30)
	UiAlign('center middle')
	UiText("You were found, or joining midgame is disabled. You will join after this round ends.")
	UiPop()
end

function makePlayerInvisible(bool)
    animators = FindAnimators("",true)
    for i = 1, #animators do
        local animator = animators[i]
        local shapes = GetEntityChildren(animator, "", true, "shape")

        for j = 1, #shapes do
            local aa,bb = GetShapeBounds(shapes[j])
            local middle = VecLerp(aa,bb,0.5)
            if bool then
                SetTag(shapes[j],'invisible')
            else
                RemoveTag(shapes[j],'invisible')
            end
        end
    end
end

function getPlayerStats()
	local stats
	local hunterTable = {}
	local hiderTable = {}
	local spectators = {}

	for id in Players() do
		if teamsGetTeamId(id) == 2 then
			hunterTable[#hunterTable+1] = {
				player = id,
				columns = { "Hunter" }
			}
		end

		if teamsGetTeamId(id) == 1 then
			hiderTable[#hiderTable+1] = {
				player = id,
				columns = { "Not Found"}
			}
		end
	end

	for i = 1, #shared.stats.wasHider do
		hiderTable[#hiderTable+1] = {
			player = shared.stats.wasHider[i][1],
			columns = { shared.stats.wasHider[i][2] .. " seconds" }
		}
	end
	for id in Players() do
		if teamsGetTeamId(id) == 3 then
			spectators[#spectators+1] = {
				player = id,
				columns = "Spectator"
			}
		end
	end


	stats = {
		{
			name = "Hiders",
			color = teamsGetColor(1),
			rows = hiderTable
		},
		{
			name = "Hunters",
			color = teamsGetColor(2),
			rows = hunterTable
		},
		{
			name = "Spectators",
			color = {0.8,0.8,0.8},
			rows = "spectators"
		}
	}

	return stats
end

function getEndResults()
	local stats

	local hunterTable = {}
	local hiderTable = {}
	for i = 1, #shared.stats.OriginalHunters do
		hunterTable[#hunterTable+1] = {
			player = shared.stats.OriginalHunters[i],
			columns = { "Hunter" }
		}
	end

	for id in Players() do
		if teamsGetTeamId(id) == 1 then
			hiderTable[#hiderTable+1] = {
				player = id,
				columns = { "Survived"}
			}
		end
	end
	for i = 1, #shared.stats.wasHider do
		hiderTable[#hiderTable+1] = {
			player = shared.stats.wasHider[i][1],
			columns = { shared.stats.wasHider[i][2] .. " seconds" }
		}
	end

	if #teamsGetTeamPlayers(1) == 0 then
		stats = {{
				name = "Hunters Win",
				color = teamsGetColor(2),
				rows = hunterTable
			},
			{
				name = "Hiders Lost",
				color = teamsGetColor(1),
				rows = hiderTable
			}
		}
	else
		stats = {{
				name = "Hiders Win",
				color = teamsGetColor(1),
				rows = hiderTable
			},
			{
				name = "Hunters Lost",
				color = teamsGetColor(2),
				rows = hunterTable
			}
		}
	end

	return stats
end