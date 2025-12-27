--[[
#include clientHider.lua
#include clientHUD.lua
]]

client.state = {
	matchEnded = false
}

client.camera = {}

client.ui = {}

client.hints = {
	tauntCooldown = 0
	
}

-- client.game = {}
-- client.game.hider = {}
-- client.game.hider.lookAtShape = -1
-- client.game.hider.hiderOutline = {}
-- client.game.hider.triedHiding = false

-- client.hint = {}
-- client.hint.closestPlayerHint = {}
-- client.hint.closestPlayerHint.distance = 0
-- client.hint.closestPlayerHint.timer = 0
-- client.hint.closestPlayerHint.detailed = false

-- client.hint.closestPlayerArrowHint = {}
-- client.hint.closestPlayerArrowHint.transform = Transform()
-- client.hint.closestPlayerArrowHint.timer = 0
-- client.hint.closestPlayerArrowHint.player = 0

-- client.hint.meow = {}
-- client.hint.meow.timer = 0
-- client.hint.tauntCooldown = 0


client.player = {
	hurtOutline = {},
	hider = {
		hidingAttempt = false
	},
	lookAtShape = -1
}

function client.init()
	client.arrow = LoadSprite("assets/arrow.png")
	client.rect = LoadSprite("gfx/white.png")
	client.circle = LoadSprite("gfx/ring.png")
end

function client.tick()
	SetBool("game.disablemap", true)
	SetLowHealthBlurThreshold(0.01)

	client.state.matchEnded = shared.state.time <= 0.0

	if helperIsPlayerHider() and teamsIsSetup() then
		client.hiderTick()
	end

	spectateTick(GetAllPlayers())
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
		if client.player.hurtOutline[i].timer > 0 then
			client.player.hurtOutline[i].timer = client.player.hurtOutline[i].timer - GetTimeStep()
			DrawBodyHighlight(client.player.hurtOutline[i].body, client.player.hurtOutline[i].timer) 
			DrawBodyOutline(client.player.hurtOutline[i].body,1,0,0, client.player.hurtOutline[i].timer)
		end
	end

	for i = 1, #client.player.hurtOutline do
		if client.player.hurtOutline[i].timer < 0 then
			table.remove(client.player.hurtOutline, i)
			break
		end
	end
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
		DrawSprite(client.arrow, Transform(pos, rot), 0.7, 0.7, 0.7 ,0.7,1,1,1,false,false,false)


		if VecLength(VecSub(pos, client.hint.closestPlayerArrowHint.transform.pos)) < 40 then
			client.hint.closestPlayerArrowHint.timer = client.hint.closestPlayerArrowHint.timer - GetTimeStep()*10
		end

    	client.hint.closestPlayerArrowHint.timer = client.hint.closestPlayerArrowHint.timer - GetTimeStep()
    end

	-- Loop through all circle hints. Remove after they expire but not in the same loop
	for i=1, #shared.game.hint.circleHint do
		if shared.game.hint.circleHint[i].timer > 0 then
			for j=1, 5 do
				local c = j
				if j % 2 == 0 then c = j*-1 end
				local rot = QuatRotateQuat(QuatAxisAngle(Vec(0,1,0), GetTime()*c), shared.game.hint.circleHint[i].transform.rot)
				local pos = VecAdd(shared.game.hint.circleHint[i].transform.pos, Vec(0, -j, 0))
				DrawSprite(client.circle, Transform(pos, rot), shared.game.hint.circleHint[i].radius, shared.game.hint.circleHint[i].radius, 1 , 0, 0, shared.game.hint.circleHint[i].timer/30 , false, false, false)
			end
		end
	end
end


function client.highlightPlayer(body)
	client.player.hurtOutline[#client.player.hurtOutline+1] = { }
	client.player.hurtOutline[#client.player.hurtOutline].body = body
	client.player.hurtOutline[#client.player.hurtOutline].timer = 1
end

function client.hintShowMessage(message, timer)
	client.hint.closestPlayerHint = {}
	client.hint.closestPlayerHint.timer = timer
	client.hint.closestPlayerHint.message = message
end

function client.hintShowArrow(transform, player, timer)
	client.hint.closestPlayerArrowHint = {}
	client.hint.closestPlayerArrowHint.transform = transform
	client.hint.closestPlayerArrowHint.player = player
	client.hint.closestPlayerArrowHint.timer = timer
end

function client.friendlyFireWarning(amount)
	hudShowBanner("You killed " .. amount .. " players! If you kill more you will get kicked.", {amount/3,0,0})
end

function client.kick()
	Menu()
end


