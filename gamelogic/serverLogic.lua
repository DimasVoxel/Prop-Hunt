server.gameConfig = {}

server.game = {}

server.timers = {}

server.systems = {}

server.assets = {}
server.assets.taunt = 0

shared.gameState = {}
shared.gameState.huntersFreed = false

shared.ui = {}
shared.ui.currentCountDownName = ""

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
	server.game.time = settings.time
	shared.game.time = math.floor(server.game.time)

	server.gameConfig.roundLength = settings.time 
	server.gameConfig.amountHunters = settings.amountHunters 

	server.gameConfig.hunterBulletTimer = settings.bulletTimer
	server.gameConfig.pipeBombTimer = settings.pipeBombTimer
	server.gameConfig.bluetideTimer = settings.bluetideTimer
	server.gameConfig.hunterHinttimer = settings.hunterHinttimer
	server.gameConfig.tauntReloadTimer = settings.tauntReload
	server.gameConfig.hunterHinttimer = settings.hunterHinttimer

	-- The gameConfig function doesnt support bools? Therefor I am converting them here
	server.gameConfig.midGameJoin = settings.midGameJoin == 1
	server.gameConfig.hiderHunters = settings.hiderHunters == 1
	server.gameConfig.friendlyFire = settings.friendlyFire == 1
	server.gameConfig.enforceLimit = settings.enforceLimit == 1
	server.gameConfig.forceTeams = settings.forceTeams == 1
	server.gameConfig.randomTeams = settings.randomTeams == 1
	server.gameConfig.hints = settings.hints == 1
	server.gameConfig.enableSizeLimits = settings.enableSizeLimits == 1

	if settings.pipeBombTimer == -1 then
		server.gameConfig.hunterPipeBombEnabled = false
	else
		server.gameConfig.hunterPipeBombEnabled = true
	end

	if settings.bluetideTimer == -1 then
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
		shared.hiders[id] = {}
		shared.hiders[id].propBody = -1
		shared.hiders[id].propBackupShape = -1
		shared.hiders[id].isPropPlaced = false
		shared.hiders[id].isHider = true
		shared.hiders[id].dead = false

		server.hunters[id] = {}
	end
end

function server.tick(dt)
	if teamsTick(dt) then -- This handles the Join/Leave button in the join a team HUD
	end
end