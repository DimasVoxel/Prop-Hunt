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
server.gameConfig.hiderTauntReloadTimer = 0
server.lobbySettings.midGameJoin = 0 
server.lobbySettings.hiderHunters = 0
server.lobbySettings.enableSizeLimits = 1
server.lobbySettings.friendlyFire = 0

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
server.game.lastHint = false

server.hunters = {}
server.hunters.hunter = {}
server.hiders = {}

server.moderation = {}

server.added = {}

shared.hiders = {}
shared.game = {}
shared.game.time = 0
shared.game.hunterFreed = false
shared.game.enableSizeLimits = true

shared.game.hint = {}
shared.game.hint.circleHint = {}

shared.stats = {}
shared.stats.hiders = {}
shared.stats.originalHunters = {}
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
client.camera.Rotation = Vec() -- Using a Vec instead of a quat so it doesn't cause any roll by mistake.

client.camera.SM = {
        pos = AutoSM_Define(Vec(), 2, 0.8, 1),      -- Inital Value, Frequency, Dampening, Response
        rot = AutoSM_DefineQuat(Quat(), 2, 0.8, 1), -- Inital Value, Frequency, Dampening, Response
    }

client.camera.dist = 8






function server.tick(dt)
	-- AutoInspectWatch(shared, " ", 3, " ", false)
	
	

	


	if teamsTick(dt) then

	end








	--if InputPressed("k") then 
	--	server.game.time = 1
	--end



















end























function client.enableThirdPerson(value)

end















function client.draw(dt)
	-- during countdown, display the title of the game mode.

	hudDrawTitle(dt, "Prophunt!")
	hudDrawBanner(dt)
	hudTick(dt)
	eventlogDraw(dt, teamsGetPlayerColorsList())

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
			hudDrawGameModeHelpText("You are a Hider", "Search a prop and press ( E ) to transform. And press ( F ) to hide. Water will kill you!")
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

				DrawSprite(client.assets.rect, Transform(playerPos,quat), client.finalHint ,1.5 , 1,1,1,0.7, true, true, false)
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
end




-- Global Helper Function



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

function client.friendlyFireWarning(amount)
	hudShowBanner("You killed " .. amount .. " players! If you kill more you will get kicked.", {amount/3,0,0})

	if amount == 4 then
		Menu()
	end
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
				columns = {"Spectator"}
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
			rows = spectators
		}
	}

	return stats
end

function getEndResults()
	local stats

	local hunterTable = {}
	local hiderTable = {}
	for i = 1, #shared.stats.originalHunters do
		hunterTable[#hunterTable+1] = {
			player = shared.stats.originalHunters[i],
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