--[[
#include serverMapAnalyser.lua
#include serverSettings.lua
#include serverHider.lua
#include serverHunter.lua
#include serverAllPlayer.lua
#include shape_utils.lua
]]

shared.debug = false

-- Match configuration (lobby / rules)
server.gameConfig = {
	roundLength = 300,
	huntersStartAmount = 1,
	hunterBulletReloadTimer = 5,
	hunterPipebombReloadTimer = 10,
	hunterBluetideReloadTimer = 20,
	distanceHintTimer = 45,
	ringHintTimer = 45,

	hiderTauntReloadTimer = 10,
	hideTime = 45,

	midGameJoin = true,
	hidersJoinHunters = true,
	allowFriendlyFire = false, -- True means the game will kick someone if someone griefs too much. But I disabled it incase the lobby owner isnt aware of this setting
	enforceGameStartHunterAmount = true,

	randomTeams = false,
	enableHunterHints = true,
	minimumSizeLimit = true,
	transformCooldown = 5,

	
	--Server Config only
	unhideCooldown = 0.6, -- Cant be configured
	outOfBoundsCoolDown = 5, -- Cant be configured
	playerPosRecordInterval = 1.5,
}

shared.gameConfig = {
	roundLength = 0,
	minimumSizeLimit = true,
	transformCooldown = 5,
	hiderStandStillWarnTime = 5,
	staminaSeconds = 3, -- How long playes can sprint until the bar depleets completly
	endScreenPathDrawTime = 10,
}

-- Match state (game logic and so on)
server.state = {
	time = 0, -- Accurate server only time
	gameEnded = false,
	triggerLastHint = false,
}

-- Timers (all ticking values)
server.timers = {
	hunterBulletReloadTimer = 0,
	hunterPipebombReloadTimer = 0,
	hunterBluetideReloadTimer = 0,
	distanceHintTimer = 15,
	ringHintTimer = 30,
	hiderTauntReloadTimer = 0,
	nextMapTimer = 0,
	hunterDoubleJumpTimer = 0,
	playerPosRecordInterval = 0,
}

server.players = {
	hunter = {}, -- Contains only Hider Specifc data
	hiders = {}, -- Contains only Hunter Specifc data
	spectator = {}, --Contains only Spectator specific data
	all = {}
}

server.moderation = {}

server.assets = {
	taunt = 0,
	handSprite = 0,
	walkingSound = 0,
	runningSound = 0,
}

-- All other game related variables
server.game = {
	spawnedForHunterRoom = {}, --stores everything spawned for the waiting room to be deleted in server.destroy
	hasPlacedHuntersInRoom = false
}

shared.ui = {}
shared.ui.currentCountDownName = ""
shared.ui.stats = {
	originalHunters = {},
	wasHider = {}
}

shared.serverTime = 0

shared.hint = {
	circleHint = {},
}

shared.state = {
	hunterFreed = false,
	time = 0, -- We only send floored time to the clients
	gameOver = false,
	loadNextMap = false,
	pathStartTime = 0,
	pathEndTime = 0
}

shared.players = {
	hiders = {},
	hunters = {},
	all = {}
}

server.shotgunDefaults = {
	damage = 0,
	range = 0,
	spread = 0,
	fallOffDamage = 0,
	fallOffStart = 0
}

server.mapdata = {}

function server.init()
	RegisterTool("doublejump", "Double Jump", "MOD/assets/doublejump.vox", 2)

	server.assets.walkingSound = LoadLoop("MOD/assets/walk.ogg", 10)
	server.assets.runningSound = LoadLoop("MOD/assets/run.ogg", 10)

	hudInit(true)
	hudAddUnstuckButton()
	teamsInit(3)
	teamsSetNames({ "Hiders", "Hunters" ,"Spectator"})
	teamsSetColors { { 0, 0.95, 0.85 }, { 1, 0, 0 }, {0.8,0.8,0.8} }

	statsInit()

	spawnInit()
	toolsSetDropToolsOnDeath(false)

	--- spawnSetDefaultLoadoutForTeam was modified to support per team loadouts
	spawnSetDefaultLoadoutForTeam(1, {  })                  				  -- Hiders
	spawnSetDefaultLoadoutForTeam(2, {{ "shotgun", 3 }, { "pipebomb", 0 }, { "steroid", 0 }, { "doublejump", 0 }}) -- Hunters

	spawnSetRespawnTime(10)

	server.shotgunDefaults.damage = GetInt('game.tool.shotgun.damage')
	server.shotgunDefaults.range = GetInt('game.tool.shotgun.range')
	server.shotgunDefaults.spread = GetInt('game.tool.shotgun.spread')
	server.shotgunDefaults.fallOffDamage = GetInt('game.tool.shotgun.falloffDamage')

	SetInt('game.tool.shotgun.damage', 2, true)
	SetInt('game.tool.shotgun.range', 10, true)
	SetInt('game.tool.shotgun.falloffDamage', 0.02, true)

	server.analysis()
end

function server.initHider(id)
	SetPlayerParam("healthRegeneration", false, id)
	SetPlayerParam("godmode", true, id)
	SetPlayerTool("taunt", id)
	-- Data the hider also needs
	shared.players.hiders[id] = {}
	shared.players.hiders[id].hp = 3 -- HP Is the amount of shots a hider can take will be changed depending on prop size
	shared.players.hiders[id].health = 1 -- Health is a float the server requires for health math 
	shared.players.hiders[id].damageTick = 0
	shared.players.hiders[id].environmentalDamageTrigger = false 
	shared.players.hiders[id].damageValue = 0.33
	shared.players.hiders[id].transformCooldown = 0
	shared.players.hiders[id].stamina = shared.gameConfig.staminaSeconds -- Players have 3 seconds of sprint
	shared.players.hiders[id].staminaCoolDown = 0
	shared.players.hiders[id].taunts = 1
	shared.players.hiders[id].grabbing = false
	shared.players.hiders[id].standStillTimer = 0
	shared.players.hiders[id].clippingProps = {}

	-- Server Side information only
	server.players.hiders[id] = {}
	server.players.hiders[id].unhideCooldown = 0 -- How quickly a player can get unhiden
	server.players.hiders[id].outOfBoundsTimer = 0
	server.players.hiders[id].grabbing = {}
	server.players.hiders[id].grabbing.body = 0
	server.players.hiders[id].grabbing.localPos = 0
	server.players.hiders[id].grabbing.dist = 0
	server.players.hiders[id].standStillPosition = Vec()
	server.players.hiders[id].currentCameraRot = Quat()
end

function server.update()
	if helperIsGameOver() then return end
	server.hiderUpdate()

	--AutoDrawAABB(dynamicProps.Mapaa, dynamicProps.Mapbb, 1,1,1,1,true,false)
end

function server.nextMap()
	if shared.state.loadNextMap == true then 
		if server.timers.nextMapTimer <= GetTime() then
			StartLevel("","RAW:"..GetString("level.randomMap.path").."/main.xml")
		end
	end
end

function server.tick(dt)
	shared.serverTime = AutoRound(GetTime(),0.1)
	for id in PlayersRemoved() do -- Didnt want to make a whole function just for this
		eventlogPostMessage({id, "Left the game"})
	end

	server.nextMap()

	eventlogTick(dt)

	if teamsTick(dt) then -- This handles the Join/Leave button in the join a team HUD
	-- Executes only once after teams get configured
		spawnRespawnAllPlayers()
		for id in Players() do
			if helperIsPlayerHunter(id) then -- We save this for the end screen statistic
				shared.ui.stats.originalHunters[#shared.ui.stats.originalHunters+1] = id
				SetPlayerParam("healthRegeneration", true, id)
				SetPlayerParam("godmode", false, id)
			end

			if helperIsPlayerHider(id) then 
				server.initHider(id)
			end
		end
		shared.ui.pathStartTime = math.floor(GetTime())
	end

	server.newPlayerJoinRoutine() -- Needs to happen after teamstick so that players gets assigned first

	-- Everything below is game logic
	if not teamsIsSetup() then
		for p in Players() do
			DisablePlayer(p)
		end
		return
	end

	-- Game end
	if server.state.time <= 0 then
		for p in Players() do
			DisablePlayerInput(p)
		end
		countdownTick(dt, 0, false)

		local data, finished = GetEvent("countdownFinished", 1)
        if data == "nextgame" and finished then
			SetString("game.gamemode.next", GetString("game.gamemode"))
		end

		if shared.state.gameOver == true then return end

		shared.ui.pathEndTime = math.floor(GetTime())


		shared.state.gameOver = true
		countdownInit(60, "nextgame")
		return
	end

	-- Game ends early if all hiders are found or if only the host is left
	if #teamsGetTeamPlayers(1) == 0 and teamsIsSetup() or GetPlayerCount() == 1  then
		server.state.time = 0
		shared.state.time = 0
		shared.state.gameOver = true
		server.state.hunterFreed = true
		shared.state.hunterFreed = true

		shared.ui.pathEndTime = math.floor(GetTime())
		for id in Players() do 
			server.sendLogs(id)
			server.resetPlayerToProp(id)
		end
		countdownInit(60, "nextgame")
		return
	end

	if server.state.hunterFreed then
		server.state.time = server.state.time - dt  -- update time
		shared.state.time = math.floor(server.state.time) -- sync only whole seconds to client
	else
		for id in Players() do
			SetPlayerHealth(1, id) -- Cant die during hiding phase.
		end
	end

	spawnTick(dt, teamsGetPlayerTeamsList())
	countdownTick(dt, 0, false)
	if teamsIsSetup() then
		server.hiderTick(dt) -- Logic in serverHiderLogic.lua
		server.playersTick(dt) -- Logic in serverPlayerLogic.lua
		server.hunterTick(dt) -- Logic in serverHunterLogic.lua
		server.deadTick(dt) -- Handles found players
	end

	for id in Players() do 
		if helperIsPlayerSpectator(id) then
			DisablePlayer(id)
		end
	end

	SetFloat("level.hunterTimerForRelease", shared.countdownTimer) --for countdown screen in waiting room
end

function server.deadTick()
	for id in Players() do
		if helperIsPlayerHider(id) then
			if helperGetPlayerShotsLeft(id) == 0 then
				eventlogPostMessage({id, "Was found"  })
				Delete(shared.players.hiders[id].propBody)
				Delete(shared.players.hiders[id].propBackupShape)
				-- shared.players.hiders[id] = {}
				if server.gameConfig.hidersJoinHunters == true then
					 -- #TODO: There seems to be an issue switching teams imidiately after death. Players are "dead" but dont ragdoll
					 -- They just stand around until they respawn.
					teamsAssignToTeam(id, 2)
				else
					teamsAssignToTeam(id, 3)
				end

				-- We note down who was hider for the end screen results
				shared.ui.stats.wasHider[#shared.ui.stats.wasHider+1] = {id, math.floor(server.gameConfig.roundLength - server.state.time)}

				SetPlayerParam("healthRegeneration", true, id)
				SetPlayerParam("collisionMask", 255, id)
				SetPlayerParam("godmode", false, id)
				SetPlayerHealth(0,id) -- We need to kill the player artificially to make the respawn logic work

				server.createLog(id, 4)
			end
		end
	end
end

function server.newPlayerJoinRoutine()
	for id in PlayersAdded() do
		if helperIsGameOver() then 
			for id in Players() do 
				server.sendLogs(id)
			end
		end
		if teamsIsSetup() then
			if server.gameConfig.midGameJoin then
				if helperIsHuntersReleased() then
					spawnRespawnPlayer(id)
				elseif helperIsPlayerHunter(id) then
					local hunter_room_spawn = FindLocation("hunter_spawn_waiting", true)
					local spawn_transform = GetLocationTransform(hunter_room_spawn)
					if IsHandleValid(hunter_room_spawn) then
						-- room spawned, place all hunters there (other case is handled in serverHunter.lua)
						SetPlayerTransform(spawn_transform, id)
						SetPlayerVelocity(Vec(0, 0, 0), id)
					end
				end
				eventlogPostMessage({ id, " Joined the game" }, 5)
			else
				eventlogPostMessage({ id, " Joined as a spectator" }, 5)
			end

			if helperIsPlayerHider(id) then 
				 server.initHider(id)
			end

			server.players.log[id] = {}

			-- build a quick lookup table for loadout tools
			local loadout = {}
			if helperIsPlayerHunter(id) then
				loadout = { { "shotgun", 3 }, { "pipebomb", 0 }, { "steroid", 0 }, { "doublejump", 0 } }
			end

			local loadoutSet = {}
			for i = 1, #loadout do
				loadoutSet[loadout[i][1]] = true
			end

			local tools = ListKeys("game.tool") or {} -- We do this because sometimes if players join mid game they have access to tools that they shouldnt
			for ti = 1, #tools do
				local tool = tools[ti]
				-- only disable tools NOT in the loadout
				if not loadoutSet[tool] then
					SetToolEnabled(tool, false, id)
					SetToolAmmo(tool, 0, id)
				end
			end

			-- enable loadout tools
			for i = 1, #loadout do
				SetToolEnabled(loadout[i][1], true, id)
			end

			-- make the first tool in loadout the active tool
			if #loadout > 0 then
				SetPlayerTool(loadout[1][1], id)
			else
				SetPlayerTool("none", id)
			end

		else
			eventlogPostMessage({id, "Joined the game" , textColor   = {0, 1, 0}})
		end
	end
end

function server.destroy()
	for i = 1, #shared.players.hiders do
		Delete(shared.players.hiders[i].propBody)
		Delete(shared.players.hiders[i].propBackupShape)
	end

	for id in Players() do
		SetPlayerParam("healthRegeneration", true, id)
		SetPlayerParam("collisionMask", 255, id)
		SetPlayerParam("walkingSpeed", 1, id)

		if not helperIsHuntersReleased() then
			RespawnPlayer(id)
		end
	end

	for i=1, #server.game.spawnedForHunterRoom do
		Delete(server.game.spawnedForHunterRoom[i])
	end
	server.game.hasPlacedHuntersInRoom = false

	eventlogPostMessage({"Leave a review for Prophunt on the Workshop!"}, 10) -- Will be displayed on restart of the gamemode

	SetInt('game.tool.shotgun.damage', server.shotgunDefaults.damage, true)
	SetInt('game.tool.shotgun.range', server.shotgunDefaults.range, true)
	SetInt('game.tool.shotgun.falloffDamage', server.shotgunDefaults.fallOffDamage, true)
end

function server.loadRandomMap()
	
	local maps = {}
	local blackList = {
		"builtin-simplehouse",
		"builtin-contentgamemodeexample",
	}

	local contains = function(tab, val)
		for index, value in ipairs(tab) do
			if value == val then
				return true
			end
		end
		return false
	end

	for _, id in ipairs(ListKeys("mods.available")) do
		local isPlayable = GetBool("mods.available." .. id .. ".playable")
		local isMultiplayer = GetBool("mods.available." .. id .. ".multiplayer")
		local name = GetString("mods.available." .. id .. ".name")
		local isLocal = GetInt("mods.available." .. id .. ".local")
		local path = GetString("mods.available." .. id .. ".path")

		if isMultiplayer and isPlayable and isLocal == 0 and not contains(blackList, id) then
			table.insert(maps, {
				id = id,
				name = name,
				path = path,
			})
		end
	end

	local map = maps[math.random(1, #maps)]
	SetString("level.randomMap.name", map.name, true)
	SetString("level.randomMap.path", map.path)
	SetString("level.randomMap.id", map.id)

	ClientCall(0, "client.nextMapBanner")
	shared.state.loadNextMap = true
	server.timers.nextMapTimer = GetTime() + 7
end

function server.cancelNextMap()
	shared.state.loadNextMap = false
	server.timers.nextMapTimer = 0
end

-- EventIDs:
-- 0 = Just Position,
-- 1 = Hurt event,
-- 2 = Transform Event,
-- 3 = Found Event,
-- 4 = Taunt
function server.createLog(id, eventID)
    server.players.log[id] = server.players.log[id] or {}

    local log = server.players.log[id]
    local lastEntry = log[#log] 
    local pos = GetPlayerTransform(id).pos

    if not lastEntry and pos[2] < 1000 then
        log[1] = {
            pos = VecCopy(AutoVecRound(pos), 0.01),
            team = teamsGetTeamId(id),
            time = AutoRound(GetTime(), 0.1),
            event = eventID
        }
        return
    end

	-- Replace last X with Skull
	if lastEntry.event == 1 and eventID == 4 then
		table.remove(log, #log)
	end

    local lastPos = lastEntry.pos
    if VecLength(VecSub(pos, lastPos)) < 250 and pos[2] < 1000 then
        log[#log + 1] = {
            pos = VecCopy(AutoVecRound(pos), 0.01),
            team = teamsGetTeamId(id),
            time = AutoRound(GetTime(), 0.1),
            event = eventID
        }
    end
end

function server.sendLogs(id)

	local countLogs = 0 
	for _ in pairs(server.players.log) do
		countLogs = countLogs + 1
	end

	for logId, data in pairs(server.players.log) do
		ClientCall(id, "client.recieveLogs", data, logId, countLogs) -- Sending too much at once crashes the connection
	end
end