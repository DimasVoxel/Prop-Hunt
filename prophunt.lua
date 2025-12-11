#version 2
#include "script/include/player.lua"
#include "Automatic.lua"

--------------------- Server ---------------------

function server.init()
    shared = {}
    shared.hiders = {}

    serverJoinRoutine()

    prophunt = {}
    prophunt.hiders = {}
    prophunt.hunters = {}
end

function serverJoinRoutine()
    for id in PlayersAdded() do 
        --- Data the Clients should also a have
        shared.hiders[id] = {}
        shared.hiders[id].lookAtShape = -1
        shared.hiders[id].propBody = -1
        shared.hiders[id].isPropClipping = false -- We only store a bool to keep the amount of shared data low
        shared.hiders[id].isPropPlaced = false 
        -- Server Side only0


        prophunt.hiders[id] = {}
        prophunt.hiders[id] = {}
        prophunt.hiders[id].propTransform = Transform()
    end
end

function server.tick()
    serverJoinRoutine()
    for id in Players() do 
        local playerTransform = GetPlayerCameraTransform(id)
        local playerFwd = VecNormalize(TransformToParentVec(playerTransform, Vec(0, 0, -1)))
        shared.hiders[id].lookAtShape = playerGetLookAtShape(playerTransform.pos,playerFwd,10)

        server.handlePlayerProp(id)

        local shapes = GetBodyShapes(GetToolBody(id))
        for i=1, #shapes do
            SetTag(shapes[i], "invisible")
        end

        SetLightEnabled(GetFlashlight(id),false)
    end

    Disablewaepon()
end

function server.startGame(id)
    if IsPlayerHost(id) then 
        local players = GetAllPlayers()
        local hunter = players[math.random(#players)]
        prophunt.hunters[#prophunt.hunters+1] = hunter
    end
end

function server.handlePlayerProp(id)

    local clippingProps = checkPropClipping(id)
    if #clippingProps == 0 then 
        shared.hiders[id].isPropClipping = false
    else
        shared.hiders[id].isPropClipping = true
    end

    if shared.hiders[id].propBody ~= -1 then
        if shared.hiders[id].isPropPlaced then
            server.disableBodyCollission(shared.hiders[id].propBody,false)

            local playerTransform = GetPlayerTransform(id)
            local propTransform = GetBodyTransform(shared.hiders[id].propBody)
            local distance = VecLength(VecSub(propTransform.pos,playerTransform.pos))

            if distance > 5 then 
                shared.hiders[id].isPropPlaced = false
            end
        else
            server.disableBodyCollission(shared.hiders[id].propBody,true)

            local shape = GetBodyShapes(shared.hiders[id].propBody)[1]
            local x,y,z = GetShapeSize(shape)

            local playerTransform = GetPlayerTransform(id)
            local playerBhnd = TransformToParentVec(playerTransform, Vec(0, 0.2, z / 10 / 2 + 1))
            SetBodyVelocity(shared.hiders[id].propBody, Vec(0,0,0))
            SetBodyTransform(shared.hiders[id].propBody,Transform(VecAdd(playerTransform.pos,playerBhnd),playerTransform.rot))
        end
    end
end

function server.clientHideRequest(playerid)
    if not shared.hiders[playerid].isPropClipping then 
        shared.hiders[playerid].isPropPlaced = true
    end
end

function server.clientPropSpawnRequest(playerid, propid)
    local string = "Player " .. GetPlayerName(playerid) .. " wants to spawn prop " .. propid
    Delete(shared.hiders[playerid].propBody)

    local newBody, newShape = server.cloneShape(propid)

    local bodyTransform = GetBodyTransform(newBody)
    local aa,bb = GetBodyBounds()


    SetBodyTransform(newBody,Transform(VecAdd(GetPlayerTransform().pos,Vec(0,0,2)),bodyTransform.rot))
    SetBodyDynamic(newBody,true)
    server.disableBodyCollission(newBody,true)

    shared.hiders[playerid].propBody = newBody
    SetTag(newBody, "unbreakable")
end

function server.disableBodyCollission(body, bool)
    local shapes = GetEntityChildren(body, "", true, "shape")
    local mask = 0 
    if bool then 
        mask = 253
    end

    for i = 1, #shapes do
        if bool then
            SetShapeCollisionFilter(shapes[i], 4, 4)
        else
            SetShapeCollisionFilter(shapes[i], 1, 255)
        end
    end
end

function server.cloneShape( shape )
    local newBody = Spawn('<body pos="0.0 0 0.0" dynamic="true"> <voxbox tags="deleteTempShape" size="1 1 1"/> </body>',Transform(),false)[1] -- Temo shape because empty bodies get rmoved?
    local save = CreateShape(newBody,Transform(),0)
    CopyShapeContent( shape, save )
    local x, y, z, scale = GetShapeSize( shape )
    local start = GetShapeWorldTransform( shape )
    local body = GetShapeBody(save)
    ResizeShape( shape, 0, 0, 0, x - 1, y - 1, z + 1 )
    SetBrush( "cube", 1, 1 )
    DrawShapeBox( shape, 0, 0, z + 1, 0, 0, z + 1 )
    local pieces = SplitShape( shape, false )
    local moved = VecScale( TransformToLocalPoint( GetShapeWorldTransform( shape ), start.pos ), 1 / scale )
    local mx, my, mz = math.floor( moved[1] + 0.5 ), math.floor( moved[2] + 0.5 ), math.floor( moved[3] + 0.5 )
    ResizeShape( shape, mx, my, mz, 1, 1, 1 )

    CopyShapeContent( save, shape )
    local splitoffset = VecScale( TransformToLocalPoint( GetShapeWorldTransform( pieces[1] ), start.pos ), 1 / scale )
    local sx, sy, sz = math.floor( splitoffset[1] + 0.5 ), math.floor( splitoffset[2] + 0.5 ),
                        math.floor( splitoffset[3] + 0.5 )
    ResizeShape( pieces[1], sx, sy, sz, 1, 1, 1 )
    CopyShapeContent( save, pieces[1] )
    Delete( save )
    for i = 2, #pieces do
        Delete( pieces[i] )
    end
    Delete(FindShape("deleteTempShape",true))

    SetShapeBody( pieces[1], newBody ,true)
    SetShapeLocalTransform( pieces[1], GetShapeLocalTransform(shape))

    return newBody, pieces[1]
end

--------------------- CLient ---------------------


function client.init()
    player = {}
    player.transform = GetPlayerTransform()
    player.camTransform = GetPlayerCameraTransform()
    player.fwd = VecNormalize(TransformToParentVec(player.camTransform, Vec(0, 0, -1)))
    player.id = GetLocalPlayer()
    

    prophunt = {}
    prophunt.playerLookAtShape = 0
    prophunt.propBody = -1
    prophunt.hiding = false
    prophunt.clippingShapes = {}
end

function client.UpdatePlayer()
    player.transform = GetPlayerTransform()
    player.camTransform = GetPlayerCameraTransform()
    player.fwd = VecNormalize(TransformToParentVec(player.camTransform, Vec(0, 0, -1)))

    if shared.hiders and shared.hiders[player.id] then -- Doing this because client script is running faster than shared table getting shared
        prophunt.propBody = shared.hiders[player.id].propBody
        prophunt.hiding   = shared.hiders[player.id].isPropPlaced
        prophunt.clippingShapes = checkPropClipping(player.id)

        if shared.hiders[player.id].isPropPlaced == false and prophunt.propBody ~= -1 then 
            RequestThirdPerson(true)
        else 
            RequestFirstPerson(true)
        end
    end 
end

function client.tick()
    makePlayerInvisible(true)
end

function client.update()
    client.UpdatePlayer()
    client.handleHidingLogic()

    for id in Players() do 
        local shapes = GetBodyShapes(GetToolBody(id))
        for i=1, #shapes do
            SetTag(shapes[i], "invisible")
        end
    end
end

function client.handleHidingLogic()
    client.SelectProp()
    makePlayerInvisible(true)
    client.highlightClippingProps()
    client.sendHideRequest()
end

function client.SelectProp()
    client.HighlightDynamicBodies()
    if prophunt.playerLookAtShape ~= -1 and prophunt.playerLookAtShape == shared.hiders[player.id].lookAtShape then
        if InputPressed("interact") then
            ServerCall("server.clientPropSpawnRequest", player.id, prophunt.playerLookAtShape)
        end
    end
end

function client.sendHideRequest()
    if InputPressed("f") then 
        if not shared.hiders[player.id].isPropClipping and shared.hiders[player.id].propBody ~= -1 then
            ServerCall("server.clientHideRequest", player.id)
        end
    end
end

function client.highlightClippingProps()
    if not prophunt.hiding and prophunt.propBody ~= -1 then
        for i = 1, #prophunt.clippingShapes do
            DrawShapeOutline(prophunt.clippingShapes[i], 1,0,0,1)
        end
    end
end

--------------------- Client UI ---------------------

function client.draw()
    client.DrawTransformPrompt()
    client.placePrompt()
 --   makePlayerInvisible(true)
end

function client.placePrompt()
    if prophunt.propBody ~= -1 and not prophunt.hiding then
        UiColor(1,1,1)
        UiTranslate(UiWidth()/2, UiHeight()-100)
        UiFont("bold.ttf",30)
        UiPush()
        UiAlign('center middle')
        if not shared.hiders[player.id].isPropClipping then
                UiText("Press F to hide and place prop (Activate Prop Physics)")
            else 
                UiText("Unable to place prop clipping " .. #prophunt.clippingShapes .. " shapes")
            end
        UiPop()
    else 
        UiColor(1,1,1)
        UiTranslate(UiWidth()/2, UiHeight()-100)
        UiFont("bold.ttf",30)
        UiPush()
            UiAlign('center middle')
            UiText("Grab the shape to adjust position, or move to a new location")
        UiPop()
    end
end

function client.DrawTransformPrompt()
    if prophunt.playerLookAtShape ~= -1 and prophunt.playerLookAtShape == shared.hiders[player.id].lookAtShape and GetShapeBody(shared.hiders[player.id].lookAtShape) ~= shared.hiders[player.id].propBody then
        local boundsAA, boundsBB = GetBodyBounds(GetShapeBody(prophunt.playerLookAtShape))
        local middle = VecLerp(boundsAA, boundsBB, 0.5)
        AutoTooltip("Transform Into Prop (E)", middle, false, 40, 1)
    end
end


function client.HighlightDynamicBodies()
    local aa = VecAdd(player.transform.pos, Vec(3,3,3))
    local bb = VecAdd(player.transform.pos, Vec(-3,-3,-3))

    QueryRequire("physical dynamic large")
    local bodies = QueryAabbBodies(bb, aa)

    prophunt.playerLookAtShape = -1

    for i = 1, #bodies do
        local body = bodies[i]
        if IsBodyVisible(body, 5, false) and body ~= shared.hiders[player.id].propBody then
            DrawBodyOutline(body, 1 ,1 ,1, 1)
            local shape = playerGetLookAtShape(player.camTransform.pos,player.fwd,10)
            if GetShapeBody(shape) == body then
                DrawBodyHighlight(body, 0.8)
                prophunt.playerLookAtShape = shape 
            end
        end
    end
end

--------------------- Helper ---------------------
-- Functions that are needed on both server and cleint
function makePlayerInvisible(bool)
    animators = FindAnimators("",true)
    for i = 1, #animators do
        local animator = animators[i]
        local shapes = GetEntityChildren(animator, "", true, "shape")

        for j = 1, #shapes do 
            local aa,bb = GetShapeBounds(shapes[j])
            local middle = VecLerp(aa,bb,0.5)
            if bool then
                SetTag(shapes[j],'invisible')
            else
                RemoveTag(shapes[j],'invisible')
            end
        end
    end
end

function playerGetLookAtShape(pos,fwd,dist)
    QueryRequire("physical dynamic large")
    local hit,_,_,shape = QueryRaycast(pos, fwd, dist, 0, false)
    if hit then 
        return shape 
    else 
        return -1
    end
end

function checkPropClipping(id)
    local body = shared.hiders[id].propBody
    local shape = GetBodyShapes(body)[1]
    local aa,bb = GetBodyBounds(body)

    QueryRequire("physical")
    local shapes = QueryAabbShapes(aa,bb)
   
    local clippingShapes = {}

    for i=1, #shapes do 
        if IsShapeTouching(shape,shapes[i]) and shapes[i] ~= shape then
            clippingShapes[#clippingShapes+1] = shapes[i]
        end
    end

    return clippingShapes
end

function Disablewaepon()
	for _, tool in ipairs(ListKeys("game.tool")) do
        if tool ~= "sledge" then
            SetBool("game.tool."..tool..".enabled",false)
            SetFloat("game.tool."..tool..".ammo",0)
        end
    end
end