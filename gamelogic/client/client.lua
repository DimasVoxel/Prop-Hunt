--[[
#include clientOnlyHelpers.lua
#include clientHider.lua
#include clientHunter.lua
#include clientHUD.lua
]]

client.state = {
	matchEnded = false
}

client.gameConfig = {
	tauntChargeTime = 0.5,
	hideCoolDown = 0.5
}


client.ui = {
	finalHiderRevealDelay = 0, -- Used for the white beams at the end
	finalRevealRectSize = 0,
	switchingMap = false,
	calculatedPaths = false,

	paths = {},
	hideUi = false,
	uiPathStartTime = 0,
    uiPathEndTime = 0,
	uiPathProgress = 0,

	lockCamera = false,
	dragging = false
}

client.hint = {
	tauntCooldown = 0
}

client.player = {
	hurtOutline = {},
	hider = {
		hidingAttempt = false
	},
	lookAtShape = -1,
	tauntChargeCount = 0,
	hideCoolDown = 0,

	grab = {
		grabbing = false, 
		grabBody = 0,
		dist = 0,
		localPos = 0
	},
	jumpTimer = 0
}

client.assets = {
	rect = nil,
	circle = nil,
	taunt = nil,
	propGuy = nil,
	grabHand = nil,
	openHand = nil
}

client.camera = {}
client.camera.Rotation = Vec() -- Using a Vec instead of a quat so it doesn't cause any roll by mistake.
client.camera.dist = 8
client.camera.SM = {
        pos = AutoSM_Define(Vec(), 2, 0.8, 1),      -- Inital Value, Frequency, Dampening, Response
        rot = AutoSM_DefineQuat(Quat(), 2, 0.8, 1), -- Inital Value, Frequency, Dampening, Response
}

client.hint = {
	closestPlayerHint = {
		message = "",
		timer = 0
	},
	tauntCooldown = 0
}


function client.init()
	client.assets.rect = LoadSprite("gfx/white.png")
	client.assets.circle = LoadSprite("gfx/ring.png")

	client.assets.taunt = {}
	client.assets.taunt[1] = LoadSound('MOD/assets/taunt1.ogg', 3)
	client.assets.taunt[2] = LoadSound('MOD/assets/taunt2.ogg', 3)
	client.assets.taunt[3] = LoadSound('MOD/assets/taunt3.ogg', 3)
	client.assets.taunt[4] = LoadSound('MOD/assets/taunt4.ogg', 3)

	client.assets.propGuy = {}
	client.assets.propGuy[1] = LoadSound('MOD/assets/propguy1.ogg', 3)
	client.assets.propGuy[2] = LoadSound('MOD/assets/propguy2.ogg', 3)
	client.assets.propGuy[3] = LoadSound('MOD/assets/propguy3.ogg', 3)
	client.assets.propGuy[4] = LoadSound('MOD/assets/propguy4.ogg', 3)

	client.assets.jumpSound = {}
	client.assets.jumpSound[1] = LoadSound('MOD/assets/jump1.ogg', 3)
	client.assets.jumpSound[2] = LoadSound('MOD/assets/jump2.ogg', 3)
	client.assets.jumpSound[3] = LoadSound('MOD/assets/jump3.ogg', 3)

	client.assets.grabHand = LoadSprite("MOD/assets/grab.png")
end

function client.tick()
	SetBool("game.disablemap", true)
	SetLowHealthBlurThreshold(0.01)

	client.state.matchEnded = shared.state.time <= 0.0

	if helperIsPlayerHider() and teamsIsSetup() then
		client.hiderTick()
	elseif helperIsPlayerHunter() and teamsIsSetup() then
		client.hunterTick()
	end
	local spectateList = {}
	for _,i in pairs(teamsGetTeamPlayers(2)) do
		table.insert(spectateList, i)
	end

	if helperIsPlayerSpectator() then 
		local hiders = teamsGetTeamPlayers(1)
		for i = 1, #hiders do
			table.insert(spectateList, hiders[i])
		end
	end
	spectateTick(spectateList)

	client.highlightHurtHider()
end

function client.update()
	client.hiderUpdate()
end

function client.render(dt)
    if client.state.matchEnded then return end
	spectateRender(dt)
end


function client.highlightHurtHider()
	
	-- If a hider gets damaged the server sends a ClientCall to highlight a player body.
	-- The code bellow handles drawing and removing the highlight.
	for i = 1, #client.player.hurtOutline do
		if client.player.hurtOutline[i].timer >= GetTime() then
			local intensity = math.max(0, 1 - 0.2/(client.player.hurtOutline[i].timer - GetTime())) 
			
			DrawBodyHighlight(helperGetPlayerPropBody(client.player.hurtOutline[i].id), intensity) 
			DrawBodyOutline(helperGetPlayerPropBody(client.player.hurtOutline[i].id),1,0,0, intensity/3)
		end
	end

	for i = 1, #client.player.hurtOutline do
		if client.player.hurtOutline[i].timer <= GetTime() then
			table.remove(client.player.hurtOutline, i)
			break
		end
	end
end

function client.showHint()
	if client.hint.closestPlayerHint.timer >= shared.serverTime then
		if client.hint.closestPlayerHint.detailed then detail =  client.hint.closestPlayerHint.detailed end
		hudDrawInformationMessage(client.hint.closestPlayerHint.message)
	end
--	AutoInspect(shared.hint.circleHint, 2, " ")
	-- Loop through all circle hints. Remove after they expire but not in the same loop
	for i=1, #shared.hint.circleHint do
		if shared.hint.circleHint[i].timer >= shared.serverTime then
			for j=1, 5 do
				local c = j
				if j % 2 == 0 then c = j*-1 end
				local rot = QuatRotateQuat(QuatAxisAngle(Vec(0,1,0), GetTime()*c), shared.hint.circleHint[i].transform.rot)
				local pos = VecAdd(shared.hint.circleHint[i].transform.pos, Vec(0, -j, 0))

				DrawSprite(client.assets.circle, Transform(pos, rot), shared.hint.circleHint[i].diameter, shared.hint.circleHint[i].diameter, 1 , 0, 0, AutoClamp(1 - 1/(shared.hint.circleHint[i].timer - shared.serverTime),0, 1) , false, false, false)
			end
		end
	end
end

function client.notify(text)
	hudShowBanner(text, {0,0,0}) 
end

function client.tauntBroadcast(pos, soundID, propguy)
	if propguy then 
		PlaySound(client.assets.propGuy[soundID],pos,2,true,1)
	else
		PlaySound(client.assets.taunt[soundID],pos,2,true,1)
	end
end

function client.highlightPlayer(id)
	client.player.hurtOutline[#client.player.hurtOutline+1] = { }
	client.player.hurtOutline[#client.player.hurtOutline].id = id
	client.player.hurtOutline[#client.player.hurtOutline].timer = GetTime() + 0.9
end

function client.hintShowMessage(message, timer)
	client.hint.closestPlayerHint = {}
	client.hint.closestPlayerHint.timer = timer + shared.serverTime
	client.hint.closestPlayerHint.message = message 
end

function client.friendlyFireWarning(amount)
	hudShowBanner("You killed " .. amount .. " players! If you kill more you will get kicked.", {amount/3,0,0})
end

function client.kick()
	Menu()
end

function client.jumpCloud(id, pos, soundID)
	if GetLocalPlayer() == id then return end
	DebugPrint("fart")
	ParticleReset()
	ParticleType("smoke")
	ParticleColor(0.8, 1, 0.8)
	--Spawn particle at world origo with upwards velocity and a lifetime of ten seconds
	SpawnParticle(pos, Vec(0, -0.5, 0), 2)
	PlaySound(client.assets.jumpSound[soundID], pos, 1, true, 1)
end
