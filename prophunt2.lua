#version 2
#include "script/include/player.lua"
#include "Automatic.lua"
#include "/mplib/mp.lua"

shared.hiders = {}

function server.init()
	hudInit(true)
	hudAddUnstuckButton()
	teamsInit(2)
	teamsSetNames({"Hiders", "Hunters"})
	teamsSetColors{{0,1,1},{1,0,0}}
end

function server.tick()

end

function server.start(settings)
	shared.time = settings.time
	teamsStart(false)
end

function client.tick(dt)
	hudTick(dt)
	SetLowHealthBlurThreshold(0.25)
	spectateTick(teamsGetLocalTeam())
end

function client.update()
    if IsPlayerHost(GetLocalPlayer()) then 
        client.hostTools()
    end

end

function client.hostTools()

end

function client.draw(dt)
	-- during countdown, display the title of the game mode.
	hudDrawTitle(dt, "Prophunt!")
	hudDrawBanner(dt)


	if not teamsIsSetup() then
		teamsDraw(dt)

		if not hudGameIsSetup() then
			local maxHunters = {}
			local players = GetPlayerCount()
			for i=1, math.max(players - 1, 1) do
				maxHunters[#maxHunters+1] = {label = tostring(i).. " Hunter", value = i}
			end

			local settings = {
			{
				title = "",
					items = {
						{key = "savegame.mod.settings.time", 
						label = "Round Lenth", info="How long one round lasts", options = {{label = "05:00", value = 5*60},{label = "07:30", value = 7.5*60}, {label = "10:00", value=10*60}, {label = "03:00", value=3*60}}},
						{key = "savegame.mod.settings.joinHunters", 
						label = "Join Hunters", info="Makes the hiders join the hunters once found.", options = {{label = "Enable", value = true},{label = "Disable", value = false}}},
						{key = "savegame.mod.settings.randomTeams", 
						label = "Random Teams", info="Once the game is started the server will assign teams by random.", options = {{label = "Enable", value = true},{label = "Disable", value = false}}},
						{key = "savegame.mod.settings.hunters", 
						label = "Hunters Amount", info="The amount of hunters at the beginning of a game.", options = maxHunters}
					}
				}
			}
			if hudDrawGameSetup(settings) then
				ServerCall("server.start", { time = GetFloat("savegame.mod.settings.time") })
			end
		end
		return
	end
	eventlogDraw(dt, teamsGetPlayerColorsList())
end