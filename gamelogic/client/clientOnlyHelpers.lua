function client.helperGetTauntProgress() 
    return math.max(1 - math.max(client.player.tauntChargeCount - GetTime(),0) / client.gameConfig.tauntChargeTime,0)
end

function client.helperIsPlayerTaunting()
    return client.player.taunting
end