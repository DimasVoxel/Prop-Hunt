function client.draw(dt)
    -- In the beginning of the game draw Title and banner
    hudDrawBanner(dt)
    hudDrawTitle(dt, "Prophunt!")
    -- If Setup not complete dont proceed
    if not client.SetupScreen(dt) then return end 
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
							options = { { label = "05:00", value = 5 * 60 }, { label = "07:30", value = 7.5 * 60 }, { label = "10:00", value = 10 * 60 }, { label = "03:00", value = 90 } }
						},
						{
							key = "savegame.mod.settings.hideTime",
							label = "Hide Time",
							info = "How much time hiders have to hide",
							options = {{ label = "00:30", value = 30}, { label = "00:45", value = 45 }, { label = "01:00", value = 60 }, { label = "01:30", value = 90 }, { label = "02:00", value = 120 },  }
						},
						--{ # There is no spectator mode
						--	key = "savegame.mod.settings.joinHunters",
						--	label = "Hider Hunters",
						--	info = "Makes the hiders join the hunters once found.",
						--	options = { { label = "Enable", value = 1 }, { label = "Disable", value = 0 } }
						--},
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
							options = { { label = "20 Seconds", value = 20},  { label = "30 Seconds", value = 30}, { label = "40 Seconds", value = 40}, { label = "50 Seconds", value = 50}, { label = "60 Seconds", value = 60}, { label = "Disable PipeBombs", value = -1}, { label = "10 Seconds", value = 10},   }
						},
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
				--joinHunters = GetInt("savegame.mod.settings.joinHunters")
				})
			end
		end
		return false
	end
	return true
end