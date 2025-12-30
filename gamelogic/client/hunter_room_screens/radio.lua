#version 2

function client.init()	
	radio = FindShape("radio")
	musicLoop = LoadLoop("music/about.ogg")
end

function client.tick()
	local pos = GetShapeWorldTransform(radio).pos
	PlayLoop(musicLoop, pos, 0.2)
end