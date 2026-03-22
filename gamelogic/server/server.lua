--[[
#include serverHider.lua
#include serverHunter.lua
#include serverAllPlayer.lua
#include shape_utils.lua
]]


-- Match configuration (lobby / rules)
server.gameConfig = {
	roundLength = 300,
	huntersStartAmount = 1,
	hunterBulletReloadTimer = 5,
	hunterPipebombReloadTimer = 10,
	hunterBluetideReloadTimer = 20,
	hunterHintTimer = 45,
	hiderTauntReloadTimer = 10,

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
}

shared.gameConfig = {
	minimumSizeLimit = true,
	transformCooldown = 5,
	hiderStandStillWarnTime = 5
}

-- Match state (game logic and so on)
server.state = {
	time = 0, -- Accurate server only time
	gameEnded = false,
	triggerLastHint = false,
	autoStartTriggered = false,
}

-- Timers (all ticking values)
server.timers = {
	hunterBulletReloadTimer = 0,
	hunterPipebombReloadTimer = 0,
	hunterBluetideReloadTimer = 0,
	hunterHintTimer = 15,
	hiderTauntReloadTimer = 0,
	nextMapTimer = 0,
}

server.players = {
	hunter = {}, -- Contains only Hider Specifc data
	hiders = {}, -- Contains only Hunter Specifc data
	spectator = {}, --Contains only Spectator specific data
	all = {} -- Contains health and stamina stats
}

server.moderation = {}

server.assets = {
	taunt = 0,
	handSprite = 0
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
	loadNextMap = false
}

shared.players = {
	hiders = {},
	hunters = {},
}

server.shotgunDefaults = {
	damage = 0,
	range = 0,
	spread = 0,
	fallOffDamage = 0,
	fallOffStart = 0
}

function server.init()
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
	spawnSetDefaultLoadoutForTeam(2, {{ "shotgun", 3 }, { "pipebomb", 0 }, { "steroid", 0 }}) -- Hunters

	spawnSetRespawnTime(10)

	server.shotgunDefaults.damage = GetInt('game.tool.shotgun.damage')
	server.shotgunDefaults.range = GetInt('game.tool.shotgun.range')
	server.shotgunDefaults.spread = GetInt('game.tool.shotgun.spread')
	server.shotgunDefaults.fallOffDamage = GetInt('game.tool.shotgun.falloffDamage')

	SetInt('game.tool.shotgun.damage', 2, true)
	SetInt('game.tool.shotgun.range', 10, true)
	SetInt('game.tool.shotgun.falloffDamage', 0.02, true)
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
	shared.players.hiders[id].stamina = 3 -- Players have 3 seconds of sprint
	shared.players.hiders[id].staminaCoolDown = 0
	shared.players.hiders[id].taunts = 1
	shared.players.hiders[id].grabbing = false
	shared.players.hiders[id].standStillTimer = 0

	-- Server Side information only
	server.players.hiders[id] = {}
	server.players.hiders[id].unhideCooldown = 0 -- How quickly a player can get unhiden
	server.players.hiders[id].outOfBoundsTimer = 0
	server.players.hiders[id].grabbing = {}
	server.players.hiders[id].grabbing.body = 0
	server.players.hiders[id].grabbing.localPos = 0
	server.players.hiders[id].grabbing.dist = 0
	server.players.hiders[id].standStillPosition = Vec()
end

function server.start(settings)
	server.state.time = settings.time
	shared.state.time = math.floor(server.state.time)

	server.gameConfig.roundLength = settings.time
	server.gameConfig.huntersStartAmount = settings.huntersStartAmount

	server.gameConfig.hunterBulletReloadTimer = settings.hunterBulletReloadTimer
	server.gameConfig.hunterPipebombReloadTimer = settings.hunterPipebombReloadTimer
	server.gameConfig.hunterBluetideReloadTimer = settings.hunterBluetideReloadTimer
	server.gameConfig.hunterHintTimer = settings.hunterHintTimer
	server.gameConfig.hiderTauntReloadTimer = settings.hiderTauntReloadTimer
	server.gameConfig.transformCooldown = settings.transformCooldown
	

	-- The gameConfig function doesnt support bools? Therefor I am converting them here
	server.gameConfig.midGameJoin = settings.midGameJoin == 1
	server.gameConfig.hidersJoinHunters = settings.hidersJoinHunters == 1
	server.gameConfig.allowFriendlyFire = settings.allowFriendlyFire == 1
	server.gameConfig.enforceGameStartHunterAmount = settings.enforceGameStartHunterAmount == 1
	server.gameConfig.randomTeams = settings.randomTeams == 1
	server.gameConfig.enableHunterHints = settings.enableHints == 1

	shared.gameConfig.transformCooldown = settings.transformCooldown
	shared.gameConfig.minimumSizeLimit = settings.minimumSizeLimit == 1
	shared.gameConfig.maximumSizeLimit = settings.maximumSizeLimit == 1

	server.timers.hunterHintTimer = 15  -- First hint will be triggered in 15 seconds 

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

	local hideTime = settings.hideTime
	if GetPlayerCount() == 2 and GetPlayerName(0) == "Host" then hideTime = 2 end 

	countdownInit(hideTime, "hidersHiding")

	teamsStart(false)

	SetBool("level.sandbox", false, true)
	SetBool("level.unlimitedammo", false, true)
	SetBool("level.spawn", false, true)
	SetBool("level.creative", false, true)
end

function server.update()
	if helperIsGameOver() then return end
	server.hiderUpdate()
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

	if shared._hud.hostMode and shared._hud.hostMode >= 1 and not teamsIsSetup() and not shared._hud.gameIsSetup and not shared.state.loadNextMap then
		if GetPlayerCount() >= 3 then
			if not server.state.autoStartTriggered then
				server.state.autoStartTriggered = true
				shared._hud.gameIsSetup = true
				if shared._hud.hostMode == 2 then
					for p in Players() do
						if IsPlayerHost(p) then
							for t = 1, #shared._teamState.teams do
								local players = shared._teamState.teams[t].players
								for i = #players, 1, -1 do
									if players[i] == p then table.remove(players, i) end
								end
							end
							local spec = shared._teamState.teams[3].players
							spec[#spec + 1] = p
						end
					end
				end
				server.start({
					time                         = GetFloat("savegame.mod.settings.time") ~= 0 and GetFloat("savegame.mod.settings.time") or -1,
					huntersStartAmount           = GetInt("savegame.mod.settings.hunters") ~= 0 and GetInt("savegame.mod.settings.hunters") or -1,
					enforceGameStartHunterAmount = GetInt("savegame.mod.settings.enforceGameStartHunterAmount") ~= 0 and GetInt("savegame.mod.settings.enforceGameStartHunterAmount") or 1,
					randomTeams                  = GetInt("savegame.mod.settings.serverRandomTeams"),
					hideTime                     = GetFloat("savegame.mod.settings.hideTime") ~= 0 and GetFloat("savegame.mod.settings.hideTime") or -1,
					hunterBulletReloadTimer      = GetInt("savegame.mod.settings.hunterBulletReloadTimer") ~= 0 and GetInt("savegame.mod.settings.hunterBulletReloadTimer") or -1,
					hunterPipebombReloadTimer    = GetInt("savegame.mod.settings.hunterPipebombReloadTimer") ~= 0 and GetInt("savegame.mod.settings.hunterPipebombReloadTimer") or 20,
					hunterBluetideReloadTimer    = GetInt("savegame.mod.settings.blueTide") ~= 0 and GetInt("savegame.mod.settings.blueTide") or 20,
					distanceHintTimer            = GetInt("savegame.mod.settings.distanceHintTimer") ~= 0 and GetInt("savegame.mod.settings.distanceHintTimer") or -1,
					ringHintTimer                = GetInt("savegame.mod.settings.ringHintTimer") ~= 0 and GetInt("savegame.mod.settings.ringHintTimer") or -1,
					hiderTauntReloadTimer        = GetInt("savegame.mod.settings.hiderTauntReloadTimer") ~= 0 and GetInt("savegame.mod.settings.hiderTauntReloadTimer") or 15,
					hidersJoinHunters            = GetInt("savegame.mod.settings.hidersJoinHunters") ~= 0 and GetInt("savegame.mod.settings.hidersJoinHunters") or 1,
					midGameJoin                  = GetInt("savegame.mod.settings.midGameJoin") ~= 0 and GetInt("savegame.mod.settings.midGameJoin") or 1,
					minimumSizeLimit             = GetInt("savegame.mod.settings.minimumSizeLimit") ~= 0 and GetInt("savegame.mod.settings.minimumSizeLimit") or -1,
					maximumSizeLimit             = GetInt("savegame.mod.settings.maximumSizeLimit") ~= 0 and GetInt("savegame.mod.settings.maximumSizeLimit") or -1,
					allowFriendlyFire            = GetInt("savegame.mod.settings.allowFriendlyFire"),
					transformCooldown            = GetInt("savegame.mod.settings.transformCooldown") ~= 0 and GetInt("savegame.mod.settings.transformCooldown") or 5,
					hunterJumpReload             = GetInt("savegame.mod.settings.doubleJumpReload") ~= 0 and GetInt("savegame.mod.settings.doubleJumpReload") or 8,
				})
			end
		else
			server.state.autoStartTriggered = false
		end
	end

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
			if shared._hud.hostMode and shared._hud.hostMode >= 1 then
				server.loadRandomMap()
			else
				SetString("game.gamemode.next", GetString("game.gamemode"))
			end
		end

		if shared.state.gameOver == true then return end

		shared.state.gameOver = true
		countdownInit(20, "nextgame")
		return
	end

	-- Game ends early if all hiders are found or if only the host is left
	if #teamsGetTeamPlayers(1) == 0 and teamsIsSetup() or GetPlayerCount() == 1  then
		server.state.time = 0
		shared.state.time = 0
		shared.state.gameOver = true
		server.state.hunterFreed = true
		shared.state.hunterFreed = true
		countdownInit(20, "nextgame")
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
		server.hunterTick(dt) -- Logic in serverHunterLogic.lua
		server.playersTick(dt) -- Logic in serverPlayerLogic.lua
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
			end
		end
	end
end

function server.newPlayerJoinRoutine()
	for id in PlayersAdded() do
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

			-- build a quick lookup table for loadout tools
			local loadout = {}
			if helperIsPlayerHunter(id) then
				loadout = { { "shotgun", 3 }, { "pipebomb", 0 }, { "steroid", 0 } }
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

	local blackList = {
		"builtin-simplehouse",
		"builtin-contentgamemodeexample",
		"builtin-castle",
		"builtin-motorpark",
		"builtin-basic",
		"builtin-debuginfo",
		"builtin-editorshowcase",
		"builtin-robotshowcase",
		"builtin-scriptingshowcase",
		"builtin-uishowcase",
		"builtin-vehicleikshowcase",
		"builtin-heistexample",
		"builtin-bananabomb",
		"builtin-assetpack",
		"builtin-proppack",
		"builtin-vehiclebooster",
		"builtin-vehiclepack",
		"builtin-screenrecorder",
		"builtin-slowmotion",
		"builtin-smokegun",
		"builtin-speedometer",
		"builtin-jetpack",
		"builtin-lasergun",
		"builtin-minigun",
		"builtin-drivetosurvive",
		"builtin-merlin",
	}

	local contains = function(tab, val)
		for _, v in ipairs(tab) do if v == val then return true end end
		return false
	end

	local maps = {}
	for _, id in ipairs(ListKeys("mods.available")) do
		local isPlayable = GetBool("mods.available." .. id .. ".playable")
		local isMultiplayer = GetBool("mods.available." .. id .. ".multiplayer")
		local name = GetString("mods.available." .. id .. ".name")
		local isLocal = GetInt("mods.available." .. id .. ".local")
		local path = GetString("mods.available." .. id .. ".path")

		if isMultiplayer and isPlayable and isLocal == 0
			and not contains(blackList, id)
			and string.sub(id, 1, 8) == "builtin-" then
			table.insert(maps, {
				id = id,
				name = name,
				path = path,
			})
		end
	end

	local usedCount = GetInt("savegame.mod.mapRotation.usedCount") or 0
	local usedIds = {}
	for i = 1, usedCount do
		usedIds[GetString("savegame.mod.mapRotation.used" .. i)] = true
	end

	-- Find maps not yet used this rotation
	local availableMaps = {}
	for _, m in ipairs(maps) do
		if not usedIds[m.id] then
			table.insert(availableMaps, m)
		end
	end

	if #availableMaps == 0 then
		SetInt("savegame.mod.mapRotation.usedCount", 0)
		availableMaps = maps
		usedCount = 0
	end

	local map = availableMaps[math.random(1, #availableMaps)]

	usedCount = usedCount + 1
	SetString("savegame.mod.mapRotation.used" .. usedCount, map.id)
	SetInt("savegame.mod.mapRotation.usedCount", usedCount)

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