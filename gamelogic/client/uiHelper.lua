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
-- @param[type=number] maxVal    Max value it can display (used for math, will not truncate bar).
-- @param[opt,type=number] opt_rounding     Rounding for corners of bar.
-- @param[opt,type=table] opt_barColor      Table of {r,g,b,a} to use for bar color. Default white.
-- @param[opt,type=number] opt_numDivisions Number of divisions to draw. Purely visual; You will need to make sure the other values align properly.
-- @param[opt,type=number] opt_smoothing    Exponential value of smoothing to occur.
-- @param[opt,type=number] opt_dt           Delta time; Required if using smoothing, can be left blank if not.
function ProgressBar(thickness, length, curVal, maxVal, opt_rounding, opt_barColor, opt_numDivisions, opt_smoothing, opt_dt)
    opt_rounding = opt_rounding or 0
    opt_barColor = opt_barColor or {1,1,1,1}
    opt_numDivisions = opt_numDivisions or false
    opt_smoothing = opt_smoothing or 0

    --used for smoothing
    if not curActualFill then
        curActualFill = 0
    end

    UiPush()
        UiAlign("left middle")

        UiColor(0,0,0,1)
        UiRoundedRect(length, thickness, opt_rounding)

        UiColor(opt_barColor[1],opt_barColor[2],opt_barColor[3],opt_barColor[4])
        if opt_smoothing == 0 then
            UiRoundedRect(length*(curVal/maxVal), thickness, opt_rounding)
        else
            curActualFill = expDecay(curActualFill, length*(curVal/maxVal), opt_smoothing, opt_dt)
            UiRoundedRect(curActualFill, thickness, opt_rounding)
        end

        if opt_numDivisions then
            UiAlign("center middle")
            UiColor(0,0,0,1)
            for i=1, opt_numDivisions-1 do
                UiTranslate(length/opt_numDivisions)
                UiRect(2, thickness)
            end
        end
    UiPop()
end