--[[
#include serverHider.lua
#include serverHunter.lua
#include serverAllPlayer.lua
]]


-- Match configuration (lobby / rules)
server.gameConfig = {
	roundLength = 300,
	huntersStartAmount = 1,
	hunterBulletReloadTimer = 5,
	hunterPipebombReloadTimer = 10,
	hunterBluetideReloadTimer = 20,
	hunterHinttimer = 45,
	hiderTauntReloadTimer = 10,

	midGameJoin = true,
	hidersJoinHunters = true,
	allowFriendlyFire = false, -- True means the game will kick someone if someone griefs too much. But I disabled it incase the lobby owner isnt aware of this setting
	enforceGameStartHunterAmount = true,

	randomTeams = false,
	enableHunterHints = true,
	enableSizeLimits = true
}

shared.gameConfig = {
	enableSizeLimits = true
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
	hunterHinttimer = 0,
	hiderTauntReloadTimer = 0
}

server.players = {
	hunter = {},
	hider = {},
	Spectator = {}
}

server.moderation = {}

server.assets = {
	taunt = 0
}

shared.ui = {}
shared.ui.currentCountDownName = ""
shared.ui.stats = {
	originalHunters = {},
	wasHider = {}
}

shared.hint = {
	circleHint = {},
	
}

shared.state = {
	hunterFreed = false,
	time = 0, -- We only send floored time to the clients
	gameOver = false
}

shared.players = {
	hiders = {},
	hunters = {}
}

function server.init()
	RegisterTool("taunt", "taunt", "", 1)
	server.assets.taunt = LoadSound('MOD/assets/taunt0.ogg')

	hudInit(true)
	hudAddUnstuckButton()
	teamsInit(3)
	teamsSetNames({ "Hiders", "Hunters" ,"Spectator"})
	teamsSetColors { { 0, 0.95, 0.85 }, { 1, 0, 0 }, {0.8,0.8,0.8} }

	statsInit()

	spawnInit()
	toolsSetDropToolsOnDeath(false)

	--- spawnSetDefaultLoadoutForTeam was modified to support per team loadouts
	spawnSetDefaultLoadoutForTeam(1, { {"taunt", 1} })                  				  -- Hiders
	spawnSetDefaultLoadoutForTeam(2, {{ "gun", 3 }, { "pipebomb", 0 }, { "steroid", 0 }}) -- Hunters

	spawnSetRespawnTime(10)
end

function server.start(settings)
	server.state.time = settings.time
	shared.state.time = math.floor(server.state.time)

	server.gameConfig.roundLength = settings.time 
	server.gameConfig.huntersStartAmount = settings.huntersStartAmount 

	server.gameConfig.hunterBulletReloadTimer = settings.hunterBulletReloadTimer
	server.gameConfig.hunterPipebombReloadTimer = settings.hunterPipebombReloadTimer
	server.gameConfig.hunterBluetideReloadTimer = settings.hunterBluetideReloadTimer
	server.gameConfig.hunterHinttimer = settings.hunterHinttimer
	server.gameConfig.hiderTauntReloadTimer = settings.hiderTauntReloadTimer

	-- The gameConfig function doesnt support bools? Therefor I am converting them here
	server.gameConfig.midGameJoin = settings.midGameJoin == 1
	server.gameConfig.hidersJoinHunters = settings.hidersJoinHunters == 1
	server.gameConfig.allowFriendlyFire = settings.allowFriendlyFire == 1
	server.gameConfig.enforceGameStartHunterAmount = settings.enforceGameStartHunterAmount == 1
	server.gameConfig.randomTeams = settings.randomTeams == 1
	server.gameConfig.enableHunterHints = settings.enableHunterHints == 1
	server.gameConfig.enableSizeLimits = settings.enableSizeLimits == 1
	shared.gameConfig.enableSizeLimits = settings.enableSizeLimits == 1

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

	if settings.hunterHinttimer == -1 then
		server.gameConfig.hunterHintTimer = false
	else
		server.gameConfig.hunterHintTimer = true
	end

	countdownInit(settings.hideTime, "hidersHiding")

	teamsStart(false)

	SetBool("level.sandbox", false, true)
	SetBool("level.unlimitedammo", false, true)
	SetBool("level.spawn", false, true)
	SetBool("level.creative", false, true)

	for id in Players() do
		shared.players.hiders[id] = {}
		shared.players.hiders[id].propBody = -1
		shared.players.hiders[id].propBackupShape = -1
		shared.players.hiders[id].isPropPlaced = false
	end
end

function server.update()
	if helperIsGameOver() then return end
	server.hiderUpdate()
end

function server.tick(dt)

	server.newPlayerJoinRoutine()
	for id in PlayersRemoved() do -- Didnt want to make a whole function just for this
		eventlogPostMessage({id, "Left the game"})
	end

	eventlogTick(dt)

	if teamsTick(dt) then -- This handles the Join/Leave button in the join a team HUD
		-- Executes only once after teams get configured
		spawnRespawnAllPlayers()
		for id in Players() do
			if helperIsPlayerHunter(id) then -- We save this for the end screen statistic
				shared.ui.stats.originalHunters[#shared.ui.stats.originalHunters+1] = id
			end

			if helperIsPlayerHider(id) then 
				SetPlayerParam("healthRegeneration", false, id)
				SetPlayerTool("taunt", id)
			end
		end
	end

	-- Everything below is game logic
	if not teamsIsSetup() then
		for p in Players() do
			DisablePlayer(p)
		end
		return
	end

	-- Game end
	if server.state.time <= 0 then
		shared.state.gameOver = true
		for p in Players() do
			DisablePlayerInput(p)
		end
		return
	end

	-- Game ends early if all hiders are found or if only the host is left
	if #teamsGetTeamPlayers(1) == 0 and teamsIsSetup() or GetPlayerCount() == 1  then
		server.state.time = 0
		shared.state.time = 0
		shared.state.gameOver = true
		server.state.hunterFreed = true
		shared.state.hunterFreed = true
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
	
	server.hiderTick(dt) -- Logic in serverHiderLogic.lua
	server.hunterTick(dt) -- Logic in serverHunterLogic.lua
	server.playersTick(dt) -- Logic in serverPlayerLogic.lua
	server.deadTick(dt) -- Handles found players

	for id in Players() do 
		if helperIsPlayerSpectator(id) then
			DisablePlayer(id)
		end
	end
end

function server.deadTick()
	for id in Players() do
		if helperIsPlayerHider(id) then
			local health = GetPlayerHealth(id)
			if health == 0 and helperIsHuntersReleased() then
				eventlogPostMessage({id, " Was found"  })
				Delete(shared.players.hiders[id].propBody)
				Delete(shared.players.hiders[id].propBackupShape)
				shared.players.hiders[id] = {}
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
				SetPlayerParam("walkingSpeed", 1, id)
			end
		end
	end
end

function server.newPlayerJoinRoutine()
	for id in PlayersAdded() do
		if teamsIsSetup() then
			if server.gameConfig.midGameJoin == 1 then
				spawnRespawnPlayer(id)
				eventlogPostMessage({ id, " Joined the game" }, 5)
			else
				eventlogPostMessage({ id, " Joined as a spectator" }, 5)
			end

			-- build a quick lookup table for loadout tools
			local loadout = {}
			if helperIsPlayerHider(id) then
				loadout = { {"taunt", 1} }
			elseif helperIsPlayerHunter(id) then
				loadout = { { "gun", 3 }, { "pipebomb", 0 }, { "steroid", 0 } }
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
	end

	eventlogPostMessage({"Leave a review for Prophunt on the Workshop!"}, 10) -- Wont be actually displayed because the script for handling it will be destroyed
end
