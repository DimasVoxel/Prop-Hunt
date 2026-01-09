function client.helperGetTauntProgress() 
    return 1 - math.max(client.player.tauntChargeCount - GetTime(),0) / client.gameConfig.tauntChargeTime
end

function client.helperIsPlayerTaunting()
    return client.player.taunting
end