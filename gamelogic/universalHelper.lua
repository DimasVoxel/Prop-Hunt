-- Player ID or nothing for local player
function isPlayerHunter(id)
    id = id or GetLocalPlayer()
    if teamsGetTeamId(id) == 2 then
        return true
    end
    return false
end

-- Player ID or nothing for local player
function isPlayerHider(id)
    id = id or GetLocalPlayer()
    if teamsGetTeamId(id) == 1 then
        return true
    end
    return false
end

-- Player ID or nothing for local player
function isPlayerSpectator(id)
    id = id or GetLocalPlayer()
    if teamsGetTeamId(id) == 3 then
        return true
    end
    return false
end

function isHunterRelased()
    if shared.gameState.huntersFreed then
        return true
    end
    return false
end

function isGameEnded()
    
end