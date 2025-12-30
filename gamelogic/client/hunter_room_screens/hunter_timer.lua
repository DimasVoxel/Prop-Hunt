#version 2

function draw()
    UiAlign("center middle")
    UiTextAlignment("center")
    UiTranslate(UiCenter(), UiMiddle())

    UiPush()
        UiColor(0.068,0.076,0.044)
        UiRect(UiWidth(), UiHeight())
    UiPop()

    UiPush()
        UiTranslate(0, -80)
        UiFont("MOD/assets/hunter_room/seven_seg.ttf", 35)
        UiText("Hunters start in:")
    UiPop()

    UiPush()
        local currSeconds = math.ceil(GetFloat("level.hunterTimerForRelease"))
        UiFont("MOD/assets/hunter_room/seven_seg.ttf", 2000)
        UiText(currSeconds)
    UiPop()

    UiPush()
        UiTranslate(0, 80)
        UiFont("MOD/assets/hunter_room/seven_seg.ttf", 35)
        UiText("seconds")
    UiPop()

    UiImageBox("MOD/assets/hunter_room/scanlines.png", UiWidth()*4, UiHeight()*4)
end