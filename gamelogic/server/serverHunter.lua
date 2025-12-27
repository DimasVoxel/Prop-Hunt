function server.hunterTick()

    server.moveHuntersDuringHideTime()
    server.friendlyFireRoutine()

    if server.timers.hunterBulletReloadTimer < 0 then
		server.timers.hunterBulletReloadTimer = server.gameConfig.hunterBulletReloadTimer
	end

	if server.timers.hunterPipebombReloadTimer < 0 then
		server.timers.hunterPipebombReloadTimer = server.gameConfig.hunterPipebombReloadTimer
	end

	if server.timers.hunterBluetideReloadTimer < 0 then
		server.timers.hunterBluetideReloadTimer = server.gameConfig.hunterBluetideReloadTimer
	end

    for id in Players() do
        if helperIsHuntersReleased() then
            if server.timers.hunterBulletReloadTimer < 0 then
                SetToolAmmo("gun", math.min(GetToolAmmo("gun", id) + 1, 10), id)
            end

            if server.timers.hunterPipebombReloadTimer < 0 then
                SetToolAmmo("pipebomb", math.min(GetToolAmmo("pipebomb", id) + 1, 3), id)
            end

            if server.timers.hunterBluetideReloadTimer < 0 then
                SetToolAmmo("steroid", math.min(GetToolAmmo("steroid", id) + 1, 3), id)
            end
        end
    end

	local dt = GetTimeStep()
	server.timers.hunterBulletReloadTimer = server.timers.hunterBulletReloadTimer - dt
	server.timers.hunterPipebombReloadTimer = server.timers.hunterPipebombReloadTimer - dt
	server.timers.hunterBluetideReloadTimer = server.timers.hunterBluetideReloadTimer - dt
end

function server.moveHuntersDuringHideTime()
    if not helperIsHuntersReleased() then
		local data, finished = GetEvent("countdownFinished", 1)
		local hunters = teamsGetTeamPlayers(2)
        for _, id in pairs(hunters) do
            if data == "hidersHiding" and finished then
                spawnRespawnPlayer(id)

                if server.state.hunterFreed then 
                    eventlogPostMessage({ "loc@EVENT_GLHF" })
                end

                server.state.hunterFreed = true
                shared.state.hunterFreed = true
            else
                -- While waiting we just teleport the hunters off the map.
                -- #TODO: make a waiting room or something while waiting.
                SetPlayerTransform(Transform(Vec(0, 10000, 0)), id)
                SetPlayerVelocity(Vec(0, 0, 0), id)
                DisablePlayer(id)
			end
		end
	end
end

function server.friendlyFireRoutine()
	local victim, attacker = GetEvent("playerdied", 1)
	if attacker and victim and helperIsPlayerHunter(attacker) and helperIsPlayerHunter(victim) and server.gameConfig.allowFriendlyFire == 1 and not IsPlayerHost(attacker) then -- Not sure what to do if the host is an ass. We could probably increase the respawn timer to 60 seconds
		-- Ensure entry exists
		server.moderation[attacker] = (server.moderation[attacker] or 0) + 1
		ClientCall(attacker, "client.friendlyFireWarning", server.moderation[attacker] )
		if server.moderation[attacker] == 4 then
			local name = GetPlayerName(attacker)
			ClientCall(attacker, "client.kick")
			eventlogPostMessage({ name .. " was kicked for friendly fire. Shame." }, 10)
		end
	end
end