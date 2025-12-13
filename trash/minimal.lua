#version 2
#include "script/include/player.lua"
#include "/mplib/mp.lua"

function server.init()
	hudInit(true)
	hudAddUnstuckButton()
	teamsInit(2)
	teamsSetNames({"Team A", "Team B"})
	teamsSetColors{{0,1,1},{1,0,0}}
end

function server.tick(dt)
	if teamsTick(dt) then -- This handles the Join/Leave button in the join a team HUD
	end
end

function server.start(settings)
	shared.time = settings.time
	teamsStart(false)
end

function client.draw(dt)
	-- during countdown, display the title of the game mode.
	hudDrawTitle(dt, "Gamemode Name!")
	hudDrawBanner(dt)


	if not teamsIsSetup() then
		teamsDraw(dt)

		if not hudGameIsSetup() then
			local settings = {
			{
				title = "",
					items = {
						{key = "savegame.mod.settings.time", 
						label = "Round Lenth", info="How long one round lasts", options = {{label = "05:00", value = 5*60},{label = "07:30", value = 7.5*60}, {label = "10:00", value=10*60}, {label = "03:00", value=3*60}}},
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