#version 2

function draw()
    --local path_to_img = GetTagValue(UiGetScreen(), "path") for some reason this aint working so ig use diff script for each screen :/
	UiImageBox("MOD/assets/hunter_room/stock_img.png", UiWidth(), UiHeight())
end