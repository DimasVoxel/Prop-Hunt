server.game = {}
server.game.assets = {}
server.assets = {}
server.assets.tauntSounds = 0

function server.init()
    DebugPrint("Server Init")
	RegisterTool("taunt", "taunt", "", 1)
	server.assets.tauntSounds = LoadSound('MOD/assets/taunt0.ogg')

	hudInit(true)
	hudAddUnstuckButton()
	teamsInit(2)
	teamsSetNames({ "Hiders", "Hunters" })
	teamsSetColors { { 0, 0.95, 0.85 }, { 1, 0, 0 } }

	statsInit()

	spawnInit()
	toolsSetDropToolsOnDeath(false)
	spawnSetDefaultLoadoutForTeam(1, { {"taunt", 1} })                  -- Hiders
	spawnSetDefaultLoadoutForTeam(2, {{ "gun", 3 }, { "pipebomb", 0 }, { "steroid", 0 }}) -- Hunters

	spawnSetRespawnTime (10)
end

function server.tick(dt)
	if teamsTick(dt) then -- This handles the Join/Leave button in the join a team HUD
	end
end