function client.draw(dt)
	hudTick(dt)
	eventlogDraw(dt, teamsGetPlayerColorsList())

    if not gameInit(dt) then return end -- Dont Proceed while game is not setup

	if helperIsGameOver() then 
		client.revealHiderSpots()
		-- TODO: Game Ended should be replaced with a text who actually won or if everyone left something akin to "Hiders Left"
		hudDrawResults("Game Ended!", {1, 1, 1, 0.75}, "Prop Hunt Results", {{name="Time Survived", width=160, align="center"}}, getEndResults())
		return
	end

	hudDrawScoreboard(InputDown("shift") and not helperIsGameOver(), "", {{name="Time Survived", width=160, align="center"}}, getPlayerStats())

	if helperIsPlayerHunter() then
		client.hunterDraw()
	elseif helperIsPlayerHider() then
		client.hiderDraw()
	else
		client.spectator()
	end

	--[[ moved so only hiders see this timer, seekers get the tv screen
	if shared.ui.currentCountDownName == "hidersHiding" then
		countdownDraw("Hider are Hiding!")
	end
	--]]

	if helperIsHuntersReleased() and not helperIsGameOver() then
		hudDrawTimer(shared.state.time, 1)
		hudDrawScore2Teams(teamsGetColor(1), "Hiders ".. #teamsGetTeamPlayers(1), teamsGetColor(2), #teamsGetTeamPlayers(2) .. " Hunters", 1)

		client.showHint()
		spectateDraw()
	end
end

function gameInit(dt)
	-- In the beginning of the game draw Title and banner
    hudDrawBanner(dt)
    hudDrawTitle(dt, "Prophunt!")

	return client.SetupScreen(dt)
end

function client.hunterDraw()
	-- Draws The Image While hunters Wait

	if not helperIsGameOver() then
		if helperIsPlayerHunter() and not helperIsHuntersReleased() then
			--UiImageBox("assets/placeholder.png", UiWidth(), UiHeight(), 0,0)
			if shared.ui.currentCountDownName == "hidersHiding" then
				countdownDraw("Hide! Hunters start in", true)
			end
		end

		hudDrawRespawnTimer(spawnGetPlayerRespawnTimeLeft(GetLocalPlayer()))
		hudDrawGameModeHelpText("You are a Hunter", "Search players! Shoot at props, if you find a hider make sure to kill them.")
		hudDrawPlayerWorldMarkers(teamsGetTeamPlayers(2), false, 100, teamsGetColor(2))
	end
end

function client.hiderDraw()
	if shared.ui.currentCountDownName == "hidersHiding" then
		countdownDraw("Hide! Hunters start in")
	end

	if not helperIsGameOver() then

		hudDrawRespawnTimer(spawnGetPlayerRespawnTimeLeft(GetLocalPlayer()))
		hudDrawGameModeHelpText("You are a Hider", "Search a prop and press ( E ) to transform. And press ( F ) to hide. Water will kill you!")
		client.clippingText()
		client.tauntForce()

		client.DrawTransformPrompt()
	end
end

function client.DrawTransformPrompt()
	if client.player.lookAtShape ~= -1 then

		local boundsAA, boundsBB = GetBodyBounds(GetShapeBody(client.player.lookAtShape))
		local middle = VecLerp(boundsAA, boundsBB, 0.5)
		AutoTooltip("Transform Into Prop (E)", middle, false, 40, 1)
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
	if client.player.hider.hidingAttempt then
		UiText("You're clipping into " .. #checkPropClipping(GetLocalPlayer()) .. " shapes. Can't hide.")
	end
	UiPop()
end

function client.showHint()
	if client.hint.closestPlayerHint.timer > 0 then
		if client.hint.closestPlayerHint.detailed then detail =  client.hint.closestPlayerHint.detailed end
		hudDrawInformationMessage(client.hint.closestPlayerHint.message)
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
		DrawSprite(client.assets.arrow, Transform(pos, rot), 0.7, 0.7, 0.7 ,0.7,1,1,1,false,false,false)

		if VecLength(VecSub(pos, client.hint.closestPlayerArrowHint.transform.pos)) < 40 then
			client.hint.closestPlayerArrowHint.timer = client.hint.closestPlayerArrowHint.timer - GetTimeStep()*10
		end

    	client.hint.closestPlayerArrowHint.timer = client.hint.closestPlayerArrowHint.timer - GetTimeStep()
    end

	-- Loop through all circle hints. Remove after they expire but not in the same loop
	for i=1, #shared.hint.circleHint do
		if shared.hint.circleHint[i].timer > 0 then
			for j=1, 5 do
				local c = j
				if j % 2 == 0 then c = j*-1 end
				local rot = QuatRotateQuat(QuatAxisAngle(Vec(0,1,0), GetTime()*c), shared.hint.circleHint[i].transform.rot)
				local pos = VecAdd(shared.hint.circleHint[i].transform.pos, Vec(0, -j, 0))
				DrawSprite(client.assets.circle, Transform(pos, rot), shared.hint.circleHint[i].radius, shared.hint.circleHint[i].radius, 1 , 0, 0, shared.hint.circleHint[i].timer/30 , false, false, false)
			end
		end
	end
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

function client.revealHiderSpots()
	for id in Players() do
		if teamsGetTeamId(id) == 1 then
			local camPos = GetCameraTransform().pos
			local playerPos = GetPlayerTransform(id).pos

			local xAxis = Vec(0, 1 ,0)
			local zAxis = VecNormalize(VecSub(playerPos, camPos))

			local quat = QuatAlignXZ(xAxis, zAxis) 

			DrawSprite(client.assets.rect, Transform(playerPos,quat), client.ui.finalRevealRectSize ,1.5 , 1,1,1,0.7, true, true, false)
		end
	end

	if client.ui.finalHiderRevealDelay > 0 then
		client.ui.finalHiderRevealDelay = client.ui.finalHiderRevealDelay - GetTimeStep()
	else
		client.ui.finalRevealRectSize = 2000
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
							options = { { label = "05:00", value = 5 * 60 }, { label = "07:30", value = 7.5 * 60 }, { label = "10:00", value = 10 * 60 }, { label = "03:00", value = 70 } }
						},
						{
							key = "savegame.mod.settings.hideTime",
							label = "Hide Time",
							info = "How much time hiders have to hide",
							options = {{ label = "00:30", value = 3}, { label = "00:45", value = 45 }, { label = "01:00", value = 60 }, { label = "01:30", value = 90 }, { label = "02:00", value = 120 },  }
						},
						{
							key = "savegame.mod.settings.hidersJoinHunters",
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
							key = "savegame.mod.settings.enforceGameStartHunterAmount",
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
							key = "savegame.mod.settings.enableHunterHints",
							label = "Hunter Hints",
							info ="Enable or disable hints.",
							options = { { label = "Enable", value = 1 }, { label = "Disable", value = 0 } }
						},
						{
							key = "savegame.mod.settings.hunterBulletReloadTimer",
							label = "Bullet Reload",
							info =
							"How quickly hunters get new bullets.",
							options = {  { label = "5 Seconds", value = 5},  { label = "6 Seconds", value = 6}, { label = "7 Seconds", value = 7}, { label = "8 Seconds", value = 8}, { label = "9 Seconds", value = 9}, { label = "10 Seconds", value = 10}, { label = "1 Second", value = 1}, { label = "2 Seconds", value = 2}, { label = "3 Seconds", value = 3}, { label = "4 Seconds", value = 4} }
						},
						{
							key = "savegame.mod.settings.hunterPipebombReloadTimer",
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
							key = "savegame.mod.settings.hiderTauntReloadTimer",
							label = "Forced taunt",
							info ="Players get a taunt every X seconds. After reaching 10 they will be forced to taunt. Configure how quickly a player Recieves a new taunt.",
							options = { { label = "20 Seconds", value = 20}, { label = "30 Seconds", value = 30}, { label = "60 Seconds", value = 60}, { label = "Disable Forced Taunt", value = 1000000} ,{ label = "10 Seconds", value = 10}, { label = "15 Seconds", value = 15}  }
						},
						{
							key = "savegame.mod.settings.enableSizeLimits",
							label = "Size Limits",
							info ="Enable Size limits.",
							options = { { label = "Enable", value = 1 }, { label = "Disable", value = 0 } }
						},
						{
							key = "savegame.mod.settings.allowallowallowFriendlyFire",
							label = "Kick Friendly Fire",
							info ="If enabled players that kill too many players will be kicked.",
							options = { { label = "Disable", value = 0 }, { label = "Enable", value = 1 } }
						}
					}
				}
			}

			if hudDrawGameSetup(settings) then
				ServerCall("server.start", {
					time = GetFloat("savegame.mod.settings.time"),
					huntersStartAmount = GetInt("savegame.mod.settings.hunters"),
					enforceGameStartHunterAmount = GetInt("savegame.mod.settings.enforceGameStartHunterAmount"),
					randomTeams = GetInt("savegame.mod.settings.serverRandomTeams"),
					hideTime = GetFloat("savegame.mod.settings.hideTime"),
					hunterBulletReloadTimer = GetInt("savegame.mod.settings.hunterBulletReloadTimer"),
					hunterPipebombReloadTimer = GetInt("savegame.mod.settings.hunterPipebombReloadTimer"),
					hunterBluetideReloadTimer = GetInt("savegame.mod.settings.blueTide"),
					hunterHintTimer = GetInt("savegame.mod.settings.hintTimer"),
					hiderTauntReloadTimer = GetInt("savegame.mod.settings.hiderTauntReloadTimer"),
					hidersJoinHunters = GetInt("savegame.mod.settings.hidersJoinHunters"),
					midGameJoin = GetInt("savegame.mod.settings.midGameJoin"),
					enableHints = GetInt("savegame.mod.settings.enableHunterHints"),
					enableSizeLimits = GetInt("savegame.mod.settings.enableSizeLimits"),
					allowFriendlyFire = GetInt("savegame.mod.settings.allowFriendlyFire")
				})
			end
		end
		return false
	end
	return true
end


function getPlayerStats() -- This is for the Shift button scoreboard
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

	for i = 1, #shared.ui.stats.wasHider do
		hiderTable[#hiderTable+1] = {
			player = shared.ui.stats.wasHider[i][1],
			columns = { shared.ui.stats.wasHider[i][2] .. " seconds" }
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

function getEndResults() -- This is for the end game scoreboard. Perhaps players found should be a statistic in the future
	local stats

	local hunterTable = {}
	local hiderTable = {}
	for i = 1, #shared.ui.stats.originalHunters do
		hunterTable[#hunterTable+1] = {
			player = shared.ui.stats.originalHunters[i],
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
	for i = 1, #shared.ui.stats.wasHider do
		hiderTable[#hiderTable+1] = {
			player = shared.ui.stats.wasHider[i][1],
			columns = { shared.ui.stats.wasHider[i][2] .. " seconds" }
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