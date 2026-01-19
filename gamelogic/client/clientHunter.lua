function client.hunterTick()
    client.hunterDoubleJump()
end

function client.hunterDoubleJump()
    if IsPlayerGrounded() and not IsPlayerJumping() then 
		client.player.jumpTimer = client.player.jumpTimer - GetTimeStep() * 10
	end

    local bool = GetPlayerTool() == "doublejump" and InputPressed("usetool") or InputPressed("jump")

	if IsPlayerJumping() and client.player.jumpTimer < GetTime() then 
		client.player.jumpTimer = GetTime() + 2
	elseif bool and GetToolAmmo("doublejump", GetLocalPlayer()) ~= 0 and client.player.jumpTimer > GetTime() and not IsPlayerGrounded() then
		ServerCall("server.doubleJump", GetLocalPlayer())
		client.player.jumpTimer = 0

        local pos = GetPlayerTransform().pos
        client.jumpCloud(-1, pos)
        ServerCall("server.broadCastJump", GetLocalPlayer(), pos)
	end
end