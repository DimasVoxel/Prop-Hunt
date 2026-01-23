#include "uiHelper.lua"

function client.draw(dt)
	hudTick(dt)
	eventlogDraw(dt, teamsGetPlayerColorsList())

	if shared.state.loadNextMap == true then
		hudDrawBanner(dt)
		hudDrawTitle(dt, "Loading next Map: ".. GetString('level.randomMap.name'), true)
	end
    if not gameInit(dt) then return end -- Dont Proceed while game is not setup

	if helperIsGameOver() then 
		if client.ui.calculatedPaths == false then 
			for id, playerData in pairs(shared.players.all) do
				debugcall(pathPostProcessor(playerData), dt )
				local path = pathPostProcessor(playerData)
				client.ui.paths[id] = path
			end
			client.ui.calculatedPaths = true
		end
		debugcall(client.drawEndPath(), dt )

		client.revealHiderSpots()
		-- TODO: Game Ended should be replaced with a text who actually won or if everyone left something akin to "Hiders Left"
		hudDrawResults("Game Ended!", {1, 1, 1, 0.75}, "Prop Hunt Results", {{name="Time Survived", width=160, align="center"}}, getEndResults())
		return
	end

	hudDrawScoreboard(InputDown("tab") and not helperIsGameOver(), "", {{name="Time Survived", width=160, align="center"}}, getPlayerStats())

	if helperIsPlayerHunter() then
		client.hunterDraw(dt)
	elseif helperIsPlayerHider() then
		client.hiderDraw(dt)
		client.grab(dt)
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
	if not shared.state.loadNextMap == true then
    	hudDrawBanner(dt)
    	hudDrawTitle(dt, "Prophunt!")
	end

	return client.SetupScreen(dt)
end

local helpTextHunter = { --tbh there was probably a better way to do this but it works so idc
	open = true, 
	actualW = 300, 
	actualH = 250,
	openA = 1,
	closedA = -1
}

function client.hunterDraw(dt)
	-- Draws The Image While hunters Wait

	if not helperIsGameOver() then
		--hudDrawGameModeHelpText("You are a Hunter", "Search players! Shoot at props, if you find a hider make sure to kill them.")
		UiPush()--help text
			UiAlign("right middle")
			UiTranslate(UiWidth()-40, UiMiddle())

			if InputPressed("G") then
				helpTextHunter.open = not helpTextHunter.open
			end

			if helpTextHunter.open then
				helpTextHunter.actualW = expDecay(helpTextHunter.actualW, 300, 10, dt)
				helpTextHunter.actualH = expDecay(helpTextHunter.actualH, 250, 10, dt)
				helpTextHunter.openA   = expDecay(helpTextHunter.openA,   1,   10, dt)
				helpTextHunter.closedA = expDecay(helpTextHunter.closedA, -1,  10, dt)
			else
				helpTextHunter.actualW = expDecay(helpTextHunter.actualW, 50,  10, dt)
				helpTextHunter.actualH = expDecay(helpTextHunter.actualH, 240, 10, dt)
				helpTextHunter.openA   = expDecay(helpTextHunter.openA,   -1,  10, dt)
				helpTextHunter.closedA = expDecay(helpTextHunter.closedA, 1,   10, dt)
			end

			RoundedBlurredRect(helpTextHunter.actualW, helpTextHunter.actualH, 10, 0.5, {0,0,0,0.6})
			
			--open text
			UiPush()
				UiTranslate(-150)
				UiTextAlignment("center")
				UiPush()
					UiColor(0.94, 0.94, 0.47, helpTextHunter.openA)
					UiFont("bold.ttf", 35)
					UiAlign("center top")
					UiTranslate(0,-110)
					UiText("You are a hunter!")
				UiPop()
				UiPush()
					UiColor(1, 1, 1, helpTextHunter.openA)
					UiFont("regular.ttf", 30)
					UiAlign("center bottom")
					UiTranslate(7,110)
					UiText("Search for players!\nShoot at props, if you\nfind a hider make\nsure to kill them.\n\nPress ( G ) to close.")
				UiPop()
			UiPop()

			--closed text
			UiPush()
				UiTextAlignment("center")
				UiTranslate(-25)
				UiRotate(-90)
				UiFont("regular.ttf", 30)
				UiAlign("center middle")
				UiColor(1, 1, 1, helpTextHunter.closedA)
				UiText("Press ( G ) to open.")
			UiPop()
		UiPop()

		if helperIsPlayerHunter() and not helperIsHuntersReleased() then
			--UiImageBox("assets/placeholder.png", UiWidth(), UiHeight(), 0,0)
			if shared.ui.currentCountDownName == "hidersHiding" then
				countdownDraw("Hide! Hunters start in", true)
			end
		end

		hudDrawRespawnTimer(spawnGetPlayerRespawnTimeLeft(GetLocalPlayer()))
		hudDrawPlayerWorldMarkers(teamsGetTeamPlayers(2), false, 100, teamsGetColor(2))
	end
end

local healthBarActualFill = 0
local helpTextHider = { --tbh there was probably a better way to do this but it works so idc
	open = true, 
	actualW = 400, 
	actualH = 275,
	openA = 1,
	closedA = -1
}
--local lowHealthSoundEffect = false
--local lowHealthSfxVol = 3
function client.hiderDraw(dt)
	if shared.ui.currentCountDownName == "hidersHiding" then
		countdownDraw("Hide! Hunters start in")
	end

	hudDrawPlayerWorldMarkers(teamsGetTeamPlayers(2), true, 50, teamsGetColor(2))

	if not helperIsHuntersReleased() then
		for id in Players() do
			if not helperIsPlayerHidden(id) then 
				local body = helperGetPlayerPropBody(id)
				if body and IsBodyVisible(body,20,false) then
					hudDrawPlayerWorldMarkers({id}, false, 10, teamsGetColor(1))
				else
					hudDrawPlayerWorldMarkers({id}, true, 10, teamsGetColor(1))
				end
			end
		end
	end

	if not helperIsGameOver() then
		UiPush()--help text
			UiAlign("right middle")
			UiTranslate(UiWidth()-40, UiMiddle())

			if InputPressed("G") then
				helpTextHider.open = not helpTextHider.open
			end

			if helpTextHider.open then
				helpTextHider.actualW = expDecay(helpTextHider.actualW, 400, 10, dt)
				helpTextHider.actualH = expDecay(helpTextHider.actualH, 280, 10, dt)
				helpTextHider.openA   = expDecay(helpTextHider.openA,   1,   10, dt)
				helpTextHider.closedA = expDecay(helpTextHider.closedA, -1,  10, dt)
			else
				helpTextHider.actualW = expDecay(helpTextHider.actualW, 50,  10, dt)
				helpTextHider.actualH = expDecay(helpTextHider.actualH, 240, 10, dt)
				helpTextHider.openA   = expDecay(helpTextHider.openA,   -1,  10, dt)
				helpTextHider.closedA = expDecay(helpTextHider.closedA, 1,   10, dt)
			end

			RoundedBlurredRect(helpTextHider.actualW, helpTextHider.actualH, 10, 0.5, {0,0,0,0.6})
			
			--open text
			UiPush()
				UiTranslate(-200)
				UiTextAlignment("center")
				UiPush()
					UiColor(0.94, 0.94, 0.47, helpTextHider.openA)
					UiFont("bold.ttf", 35)
					UiAlign("center top")
					UiTranslate(0,-125)
					UiText("You are a hider!")
				UiPop()
				UiPush()
					UiColor(1, 1, 1, helpTextHider.openA)
					UiFont("regular.ttf", 30)
					UiAlign("center bottom")
					UiTranslate(7,125)
					UiText("Press ( E ) to transform\n\nPress & hold ( LMB ) to Taunt\nPress & Hold ( Shift ) to Sprint\nWater will kill you!\n\nPress ( G ) to close.")
					if helperGetHiderStandStillTime(GetLocalPlayer()) > 5 then
						UiTextOutline(0.94, 0.94, 0.47, Pulse(-1, 0, 4)+helpTextHider.openA, 0.4)
					end
					UiText("Press ( F ) to hide\n\n\n\n\n ")
				UiPop()
			UiPop()

			--closed text
			UiPush()
				UiTextAlignment("center")
				UiTranslate(-25)
				UiRotate(-90)
				UiFont("regular.ttf", 30)
				UiAlign("center middle")
				UiColor(1, 1, 1, helpTextHider.closedA)
				if helperGetHiderStandStillTime(GetLocalPlayer()) > 5 then
					UiTextOutline(0.94, 0.94, 0.47, Pulse(-1, 0, 4)+helpTextHider.closedA, 0.4)
				end
				UiText("Press ( G ) to open.")
			UiPop()
		UiPop()

		hudDrawRespawnTimer(spawnGetPlayerRespawnTimeLeft(GetLocalPlayer()))
		--hudDrawGameModeHelpText("You are a Hider", "- Press ( E ) to transform\n- Press ( F ) to hide\n- Press & hold ( LMB ) to Taunt\n- Press & Hold ( Shift ) to Sprint\n- Water will kill you!",nil, 385)
		client.clippingText()
		client.tauntForce()

		client.DrawTransformPrompt()

		--Below is the HUD for health, sprint, taunts, and cooldown
		UiPush()
			UiAlign("center middle")
			UiTextAlignment("center")
			UiColor(1,1,1,1)

			UiTranslate(UiCenter(),UiHeight()-90)

			RoundedBlurredRect(800, 35, 10, 0.5, {0,0,0,0.6})

			--health
			UiPush()
				UiAlign("left middle")
				UiTranslate(110)

				local barBlink = 0
				if helperIsPlayerInDangerEnvironment(GetLocalPlayer()) then --text warning, bar blink, danger sound
					UiPush()
						UiFont("regular.ttf", 25)
						UiAlign("center middle")
						UiTextAlignment("center")
						UiTranslate(140, -35)
						UiColor(1,1,1,Pulse(0, 1, 7))
						UiText("Taking water damage!") --TODO make say what type of damage when fire dmg implemented
						
						UiSoundLoop("MOD/assets/taking_env_damage.ogg")
					UiPop()

					barBlink = 1
				end

				do
					local barMax = math.max(AutoRound(1/shared.players.hiders[GetLocalPlayer()].damageValue),1)
					local barFill = helperGetPlayerShotsLeft()
					healthBarActualFill = expDecay(healthBarActualFill, barFill, 10, dt)
					ProgressBar(true, 25, 250, healthBarActualFill, barMax, 13, {0.82,0.08,0.02,1}, barMax, barBlink)
				end

				UiTranslate(256)
				UiColor(1,1,1,1)
				UiImageBox("MOD/assets/heart_graphic.png", 25, 25)
			UiPop()

			--sprint
			UiPush()
				UiRotate(180)
				UiTranslate(110)
				do
					local maxStamina = shared.gameConfig.staminaSeconds
					local stamina = shared.players.hiders[GetLocalPlayer()].stamina
					local barColor = {0.02, 0.49, 0.82, 1}
					local barBlink = 0
					if client.player.jumpTimer > GetTime() and not IsPlayerGrounded() and shared.players.hiders[GetLocalPlayer()].stamina > 1.5 then--if more than half and jumping
						barBlink = maxStamina/2
					end
					if math.max(shared.players.hiders[GetLocalPlayer()].staminaCoolDown - shared.serverTime, 0) ~= 0 then
						barColor = {0.6, 0.2, 0.2, 1}
					end
					ProgressBar(true, 25, 250, stamina, maxStamina, 13, barColor, 0, barBlink)
				end
				UiTranslate(256)
				UiAlign("right middle")
				UiRotate(180)
				UiColor(1,1,1,1)
				UiImageBox("MOD/assets/run_graphic.png", 25, 25)
			UiPop()

			--double jump
			UiPush()
				UiAlign("right middle")
				UiTranslate(-410)
				RoundedBlurredRect(80, 35, 10, 0.5, {0,0,0,0.6})
				UiAlign("center middle")

				UiTranslate(-57.5)
				UiImageBox("MOD/assets/double_jump_graphic.png", 25, 25)

				UiTranslate(35)
				if shared.players.hiders[GetLocalPlayer()].stamina < 1.5 then--if not more than half
					UiColor(0, 0, 0, 1)
				else
					UiColor(0.02, 0.49, 0.82, 1)
				end
				UiRoundedRect(25,25,12.5)

				if client.player.jumpTimer > GetTime() and not IsPlayerGrounded() and shared.players.hiders[GetLocalPlayer()].stamina > 1.5 then--if more than half and jumping
					UiColor(1, 1, 1, Pulse(0,1,7))
					UiRoundedRect(25,25,12.5)
				end
			UiPop()

			--center info
			RoundedBlurredRect(200, 70, 15, 0.5, {0,0,0,0.6})
			UiRect(3, 55)

			--taunts
			UiPush()
				UiTranslate(50)

				UiPush()
					UiTranslate(0,35)
					UiRotate(90)
					do
						local barFill = client.helperGetTauntProgress()
						if barFill < dt then barFill = 0 end
						ProgressBar(false, 100, 70, barFill, 1, 15, {1,1,1,0.3})
					end
				UiPop()

				UiTranslate(0, -20)
				UiFont("regular.ttf", 20)
				UiText("Taunts:")

				local Xamount = math.max(helperGetHiderTauntsAmount()-8,0)
				local yamount = math.max(helperGetHiderTauntsAmount()-8,0)
				local Xwiggle = math.random(Xamount*-1, Xamount)
				local Ywiggle = math.random(yamount*-1, yamount)
				local blink = math.min(math.sin(GetTime()), math.max(helperGetHiderTauntsAmount()-6,0)/3)
				UiColor(1,1-blink,1-blink,1)

				UiTranslate(Xwiggle, 30+Ywiggle)
				UiFont("bold.ttf", 40)
				UiText(helperGetHiderTauntsAmount(GetLocalPlayer()))
			UiPop()

			--cooldown
			local cooldownText = ""
			local cooldownTimer = AutoRound(AutoClamp((shared.players.hiders[GetLocalPlayer()].transformCooldown-shared.serverTime),0,shared.gameConfig.transformCooldown),0.1) --TODO these need to use the server's max cooldown, no? maybe make a func to get the current (real, not floored) cooldown
			if not helperIsHuntersReleased() then
				cooldown = 0
			end

			local textSize = 40
			if cooldownTimer == 0 then 
				cooldownText = "Ready!"
				textSize = 30
			else
				cooldownText = cooldownTimer
			end

			UiPush()
				UiTranslate(-50)

				UiPush()
					UiTranslate(0,35)
					UiRotate(90)
					do
						local barFill = AutoClamp(shared.players.hiders[GetLocalPlayer()].transformCooldown-shared.serverTime,0,shared.gameConfig.transformCooldown) --TODO these need to use the server's max cooldown, no? maybe make a func to get the current (real, not floored) cooldown
						local barMax = shared.gameConfig.transformCooldown
						ProgressBar(false, 100, 70, barFill, barMax, 15, {1,1,1,0.3})
					end
				UiPop()

				UiTranslate(0, -20)
				UiFont("regular.ttf", 20)
				UiText("Cooldown:")
				UiTranslate(0, 30)
				UiFont("bold.ttf", textSize)
				UiText(cooldownText)
			UiPop()
		UiPop()
	else
		lowHealthSoundEffect = false
		lowHealthSfxVol = 10
	end
end



function client.DrawTransformPrompt()
	if client.player.lookAtShape ~= -1 and not helperIsPlayerHidden() then
		local boundsAA, boundsBB = GetBodyBounds(GetShapeBody(client.player.lookAtShape))
		local middle = VecLerp(boundsAA, boundsBB, 0.5)
		AutoTooltip("Transform Into Prop (E)", middle, false, 40, 1)
	end
end

function client.tauntForce()
	UiPush()
	UiColor(1,1,1)
	UiTranslate(UiWidth()/2, UiHeight()-150)
	UiFont("bold.ttf",30)
	UiAlign('center middle')
	if helperGetHiderTauntsAmount() >= 7 then
		UiText("If you get 10 taunts, the game will taunt for you! Already " .. helperGetHiderTauntsAmount() .. " taunts!")
	end
	UiPop()
end

function client.clippingText()
	UiPush()
	UiColor(1,1,1)
	UiTranslate(UiWidth()/2, UiHeight()-160)
	UiFont("bold.ttf",30)
	UiAlign('center middle')
	if client.player.hider.hidingAttempt and not helperIsPlayerHidden() then
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
			maxHunters[1] = { label = "Auto", value = -1 }
			local players = GetMaxPlayers()
			for i = 1, math.max(players - 1, 12) do
				maxHunters[#maxHunters + 1] = { label = tostring(i) .. " Hunter", value = i }
			end

			local settings = {
				{
					title = "Default is Recommended",
					items = {
						{
							key = "savegame.mod.settings.time",
							label = "Round Length",
							info = "How long one round lasts",
							options = { { label = "Auto", value = -1 }, { label = "03:00", value = 3 * 60 }, { label = "06:00", value = 6 * 60 }, { label = "07:30", value = 7.5 * 60 }, { label = "10:00", value = 10 * 60 }, }
						},
						{
							key = "savegame.mod.settings.hideTime",
							label = "Hide Time",
							info = "How much time hiders have to hide",
							options = {{ label = "Auto", value = -1 }, { label = "00:30", value = 30}, { label = "00:45", value = 45 }, { label = "01:00", value = 60 }, { label = "01:30", value = 90 }, { label = "02:00", value = 120 },}
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
							info ="The amount of hunters at the beginning of a game. There will always be atleast one hider",
							options = maxHunters
						},
						{
							key = "savegame.mod.settings.enforceGameStartHunterAmount",
							label = "Limit Hunters",
							info ="At the start of each game, the server removes extra hunters if there are more hunters than are set in 'Hunters Amount'.",
							options = { { label = "Enable", value = 1 }, { label = "Disable", value = 0 } }
						},
						{
							key = "savegame.mod.settings.serverRandomTeams",
							label = "Random Hunters",
							info ="The server will randomize each team no matter if someone already joined hunters or hiders.",
							options = {{ label = "Disable", value = 0 },  { label = "Enable", value = 1 } }
						},
						{
							key = "savegame.mod.settings.distanceHintTimer",
							label = "Distance Hints",
							info = "Timer when Hunters get a hint",
							options = {{ label = "Auto", value = -1}, { label = "15 Seconds", value = 15} , { label = "30 Seconds", value = 30},{ label = "45 Seconds", value = 45}, { label = "60 Seconds", value = 60}, { label = "120 Seconds", value = 120}, { label = "Disable Hints", value = -2}}
						},
						{
							key = "savegame.mod.settings.ringHintTimer",
							label = "Hunter Hints",
							info ="Enable or disable hints.",
							options = {{ label = "Auto", value = -1}, { label = "30 Seconds", value = 30}, { label = "45 Seconds", value = 45}, { label = "60 Seconds", value = 60}, { label = "120 Seconds", value = 120}, { label = "Disable Hints", value = -2},}
						},
						{
							key = "savegame.mod.settings.doubleJumpReload",
							label = "Hunter Jump Rel.",
							info ="How quickly hunters can double jump.",
							options = {{ label = "8 Seconds", value = 8},  { label = "10 Seconds", value = 10}, { label = "3 Seconds", value = 3}, { label = "5 Seconds", value = 5}}
						},
						{
							key = "savegame.mod.settings.hunterBulletReloadTimer",
							label = "Bullet Reload",
							info ="How quickly hunters get new bullets.",
							options = { { label = "Auto", value = -1}, { label = "1 Second", value = 1}, { label = "2 Seconds", value = 2}, { label = "3 Seconds", value = 3}, { label = "4 Seconds", value = 4}, { label = "5 Seconds", value = 5},  { label = "6 Seconds", value = 6}, { label = "7 Seconds", value = 7}, { label = "8 Seconds", value = 8}, { label = "9 Seconds", value = 9}, { label = "10 Seconds", value = 10}, }
						},
						{
							key = "savegame.mod.settings.hunterPipebombReloadTimer",
							label = "Pipebomb Reload",
							info ="How quickly hunters get new PipeBombs.",
							options = {  { label = "20 Seconds", value = 20}, { label = "30 Seconds", value = 30}, { label = "40 Seconds", value = 40}, { label = "50 Seconds", value = 50}, { label = "60 Seconds", value = 60}, { label = "Disable PipeBombs", value = -1}, { label = "10 Seconds", value = 10}  }
						},
						{
							key = "savegame.mod.settings.blueTide",
							label = "Bluetide Reload",
							info ="How quickly hunters get new Bluetides.",
							options = { { label = "20 Seconds", value = 20},  { label = "30 Seconds", value = 30}, { label = "40 Seconds", value = 40}, { label = "50 Seconds", value = 50}, { label = "60 Seconds", value = 60}, { label = "Disable BlueTide", value = -1}, { label = "10 Seconds", value = 10},   }
						},
						{
							key = "savegame.mod.settings.hiderTauntReloadTimer",
							label = "Forced taunt",
							info ="Players get a taunt every X seconds. After reaching 10 they will be forced to taunt. Configure how quickly a player Recieves a new taunt.",
							options = {{ label = "15 Seconds", value = 15}, { label = "20 Seconds", value = 20}, { label = "30 Seconds", value = 30}, { label = "60 Seconds", value = 60}, { label = "Disable Forced Taunt", value = 1000000} ,{ label = "10 Seconds", value = 10}}
						},
						{
							key = "savegame.mod.settings.minimumSizeLimit",
							label = "Min. Size Limits",
							info ="Enables the minimum Size limit.",
							options = { { label = "Auto", value = -1 }, { label = "Enable", value = 1 }, { label = "Disable", value = 0 } }
						},
						{
							key = "savegame.mod.settings.maximumSizeLimit",
							label = "Max. Size Limits",
							info ="Enables the max Size limit.",
							options = { { label = "Auto", value = -1 }, { label = "Enable", value = 1 }, { label = "Disable", value = 0 } }
						},
						{
							key = "savegame.mod.settings.transformCooldown",
							label = "Prop Cooldown",
							info ="How quickly hiders can switch from one prop to another.",
							options = { { label = "8 Seconds", value = 8}, { label = "10 Seconds", value = 10}, { label = "15 Seconds", value = 15}, { label = "3 Seconds", value = 3}, { label = "5 Seconds", value = 5} }
						},
						{
							key = "savegame.mod.settings.allowallowallowFriendlyFire",
							label = "Kick Friendly Fire",
							info ="If enabled players that kill too many players will be kicked.",
							options = { { label = "Enable", value = 1 }, { label = "Disable", value = 0 }, }
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
					distanceHintTimer = GetInt("savegame.mod.settings.distanceHintTimer"),
					ringHintTimer = GetInt("savegame.mod.settings.ringHintTimer"),
					hiderTauntReloadTimer = GetInt("savegame.mod.settings.hiderTauntReloadTimer"),
					hidersJoinHunters = GetInt("savegame.mod.settings.hidersJoinHunters"),
					midGameJoin = GetInt("savegame.mod.settings.midGameJoin"),
					minimumSizeLimit = GetInt("savegame.mod.settings.minimumSizeLimit"),
					maximumSizeLimit = GetInt("savegame.mod.settings.maximumSizeLimit"),
					allowFriendlyFire = GetInt("savegame.mod.settings.allowFriendlyFire"),
					transformCooldown = GetInt("savegame.mod.settings.transformCooldown"),
					hunterJumpReload = GetInt("savegame.mod.settings.doubleJumpReload"),
				})
			end
		end
		return false
	end
	return true
end


function getPlayerStats() -- This is for the tab button scoreboard
	local stats
	local hunterTable = {}
	local hiderTable = {}
	local spectators = {}

	local function wasHider(id)
		for i = 1, #shared.ui.stats.wasHider do 
		-- need to check if id is in the wasHider table
			if  shared.ui.stats.wasHider[i][1] == id then
				return true
			end
		end
		return false
	end

	for id in Players() do
		if teamsGetTeamId(id) == 2 and not wasHider(id) then
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
		hunterTable[#hunterTable+1] = {
			player = shared.ui.stats.wasHider[i][1],
			columns = { "Found after " ..shared.ui.stats.wasHider[i][2] .."s" }
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
	

	local stats = shared.ui.stats

	local hunterTable = {}
	local hiderTable = {}

	-- Build lookup tables
	local originalHunterLookup = {}
	for i = 1, #stats.originalHunters do
		originalHunterLookup[stats.originalHunters[i]] = true
	end

	local wasHiderLookup = {}
	for i = 1, #stats.wasHider do
		wasHiderLookup[stats.wasHider[i][1]] = stats.wasHider[i][2]
	end

	-- Original hunters
	for i = 1, #stats.originalHunters do
		hunterTable[#hunterTable + 1] = {
			player = stats.originalHunters[i],
			columns = { "Hunter" }
		}
	end

	-- Hiders that survived
	for id in Players() do
		if teamsGetTeamId(id) == 1 and not wasHiderLookup[id] then
			hiderTable[#hiderTable + 1] = {
				player = id,
				columns = { "Survived" }
			}
		end
	end

	-- Hiders that were found (with time)
	for playerId, time in pairs(wasHiderLookup) do
		hiderTable[#hiderTable + 1] = {
			player = playerId,
			columns = { time .. " seconds" }
		}
	end

	-- Joined mid game hunters
	for id in Players() do
		if teamsGetTeamId(id) == 2
			and not originalHunterLookup[id]
			and not wasHiderLookup[id] then

			hunterTable[#hunterTable + 1] = {
				player = id,
				columns = { "Joined mid game" }
			}
		end
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

function client.nextMapBanner()
	_titleState.time = 0
	client.ui.switchingMap = true
end

function pathPostProcessor(playerData)
    if #playerData > 4 then
		table.insert(playerData,1,playerData[1])
		table.insert(playerData,#playerData,playerData[#playerData])
        return client.buildCardinalSpline(playerData,10)
	end
end

function client.buildCardinalSpline(knots,precision)
	local function bezierFast(p1,p2,p3,p4, t) -- By Thomasims
		local omt = 1 - t
		local t2, omt2 = t ^ 2, omt ^ 2


		local p = VecAdd(VecAdd(VecAdd(VecScale(p1, omt ^ 3), VecScale(p2, 3 * t * omt2)), VecScale(p3, 3 * t2 * omt)),
			VecScale(p4, t ^ 3))
		return p
	end
    precision = precision or 30
    local curve = {}

    --Linear spline to cardinal spline https://youtu.be/jvPPXbo87ds?t=2656

    local magicNumber = 4.1 -- Magic number explained https://youtu.be/jvPPXbo87ds?t=2824
    for i=1, #knots do
        if i ~= #knots-2 then 
            -- # Hermite to bezier conversion https://youtu.be/jvPPXbo87ds?t=2528
            local velocity = VecSub(knots[i+2].pos,knots[i].pos)
            local controllPoint1 = VecScale(velocity,1/magicNumber)
            local velocityKnos2 = VecSub(knots[i+3].pos,knots[i+1].pos)
            local controllPoint1Knot2 = VecScale(velocityKnos2,1/magicNumber)
            local controllPoint2 = VecAdd(knots[i+2].pos,VecScale(controllPoint1Knot2,-1))
            for j=1, precision do 
               -- DebugLine(controllPoint1,GetPlayerPos())
                curve[#curve+1] = {} 
                curve[#curve].pos = bezierFast(knots[i+1].pos,VecAdd(knots[i+1].pos,controllPoint1),controllPoint2,knots[i+2].pos,j/precision)
				curve[#curve].color = VecLerp(knots[i].color, knots[i+1].color, j/precision)
				DebugPrint("In Bezier time")
				curve[#curve].time  = AutoLerp(knots[i].time, knots[i+1].time, j/precision) or 0
				if j == 1 then
					curve[#curve].event = knots[i].event
				end
			end
        else 
            break
        end
    end

    return curve
end


-- Call this to restart the animation
function client.restartAnimation()
	client.ui.uiPathProgress = 0
	client.ui.uiPathStartTime = GetTime()
end

-- Call this once per frame (tick or draw)
local function updatePathProgress()
	local elapsed = GetTime() - client.ui.uiPathStartTime
	client.ui.uiPathProgress = AutoClamp(elapsed / 30, 0, 1)
end

function client.drawEndPath()
	updatePathProgress()

	local function drawPlayerMarker(id, pos, color, text)
		text = text or nil
		local x, y, d = UiWorldToPixel(pos)

		UiPush()
			local near, far = 100, 500
			local t = AutoClamp((d - near) / (far - near), 0, 1)
			DebugPrint("Size")
			local size = AutoLerp(1.5, 0.5, t)

			UiAlign("center middle")
			UiTranslate(x, y)
			uiDrawPlayerImage(id, 15 * size, 15 * size, 3, color, 2)

			UiTranslate(0, 14 * size)
			UiFont("bold.ttf", 12 * size)
			UiText(GetPlayerName(id), false)

			if text then
				UiTranslate(0, 10 * size)
				UiText(text, false)
			end
		UiPop()
	end

	-- Convert progress (0–1) to time window
	local t = client.ui.uiPathProgress
	-- optional easing
	t = t * t * (3 - 2 * t)

	DebugPrint("Before Time")
	local time = AutoLerp(
		shared.ui.pathStartTime,
		shared.ui.pathEndTime,
		t
	)

	for id, path in pairs(client.ui.paths) do
		for i = 2, #path do
			if path[i].time <= time then
				local r, g, b = unpack(path[i].color)
				DebugLine(path[i].pos, path[i-1].pos, r, g, b, 1 - t)
				if path[i].event then
					drawPlayerMarker(id, path[i].pos, {r, g, b}, path[i].event)
				end
				if i == #path then
					drawPlayerMarker(id, path[i].pos, {r, g, b})
				end
			else
				drawPlayerMarker(id, path[i].pos, path[i].color)
				break
			end
		end
	end
end


function print(...)
	local res = {}
	for i = 1, select("#", ...) do
		res[i] = tostring(select(i, ...))
	end
	DebugPrint(table.concat(res, "    "))
end

function debugcall(func, ...)
	local args = {...}
	xpcall(function()
		return func(unpack(args))
	end, function(err)
		print(server and "SERVER" or "CLIENT: " .. GetLocalPlayer(), tostring(err) .. "\n", table.concat(stacktrace(), "\n    "))
	end)
end
function stacktrace( start )
    start = (start or 0) + 3
    local stack, last = {}, nil
    for i = start, 32 do
        local _, line = pcall( error, "-", i )
        if line == "-" then
            if last == "-" then
                break
            end
        else
            if last == "-" then
                stack[#stack + 1] = "[C]:?"
            end
---@diagnostic disable-next-line: need-check-nil
            stack[#stack + 1] = line:sub( 1, -4 )
        end
        last = line
    end
    return stack
end