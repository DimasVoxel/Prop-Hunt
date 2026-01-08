function RoundedBlurredRect(w, h, rnd, blur, col)
    UiPush()
        UiBackgroundBlur(blur)
        UiRoundedRect(w, h, rnd)        
    UiPop()
    UiPush()
        UiColor(col[1],col[2],col[3],col[4])
        UiRoundedRect(w, h, rnd)   
    UiPop()
end

--- Draw a progress bar with the specified values.
--
-- Disregards previous uialignment; will start from cursor and go out to the right.
-- Use UiRotate() before it to change the direction it faces.
-- Sorry this function has so many parameters (which is the only reason I bothered to do this param stuff).
--
-- @param[type=number] thickness Thickness of the bar to draw as a whole.
-- @param[type=number] length    Length of the bar to draw as a whole.
-- @param[type=number] curVal    Current value to display.
-- @param[type=number] maxVal    Max value it can display (used for math, will not truncate bar and does not normalize curVal).
-- @param[opt,type=number] opt_rounding     Rounding for corners of bar.
-- @param[opt,type=table] opt_barColor      Table of {r,g,b,a} to use for bar color. Default white.
-- @param[opt,type=number] opt_numDivisions Number of divisions to draw. Purely visual; You will need to make sure the other values align properly.
-- @param[opt,type=number] opt_flashAmount  Make a certain length at the end of the bar flash. For example if the maxVal is 10 and you set this to 1, 1/10th of the end of the bar will flash white.
function ProgressBar(thickness, length, curVal, maxVal, opt_rounding, opt_barColor, opt_numDivisions, opt_flashAmount)
    opt_rounding = opt_rounding or 0
    opt_barColor = opt_barColor or {1,1,1,1}
    opt_numDivisions = opt_numDivisions or 0
    opt_flashAmount = opt_flashAmount or 0

    UiPush()
        UiAlign("left middle")

        --bg
        UiColor(0,0,0,1)
        UiRoundedRect(length, thickness, opt_rounding)

        --fill
        UiColor(opt_barColor[1],opt_barColor[2],opt_barColor[3],opt_barColor[4])
        UiRoundedRect(length*(curVal/maxVal), thickness, opt_rounding)

        --divs
        UiPush()
            if opt_numDivisions > 1 then
                UiAlign("center middle")
                UiColor(0,0,0,1)
                for i=1, opt_numDivisions-1 do
                    UiTranslate(length/opt_numDivisions)
                    UiRect(2, thickness)
                end
            end
        UiPop()

        --flash
        UiPush()
            if opt_flashAmount > 0 then
                UiTranslate(length*(curVal/maxVal))
                UiAlign("right middle")
                local alpha = (math.sin((GetTime()*7))/2)+0.5
                UiColor(1,1,1,alpha)
                UiRoundedRect(length*(opt_flashAmount/maxVal), thickness, opt_rounding)
            end
        UiPop()
    UiPop()
end