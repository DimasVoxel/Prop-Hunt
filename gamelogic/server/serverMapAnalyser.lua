function server.isLandAtXZ(x, z)
    local origin = Vec(x, 100, z)
    local dir = Vec(0, -1, 0)
    local maxDist = 2000

    local hitWorld, landDist = QueryRaycast(origin, dir, maxDist)
    local hitWater, waterDist = QueryRaycastWater(origin, dir, maxDist)

    if hitWorld and (not hitWater or landDist < waterDist) then
		DebugCross(Vec(x, 100 - landDist, z), 1,1,1)
        return true
    end

    return false
end

function server.samplePlayableAreaGrid(gridStep)
    gridStep = gridStep or 10

    local worldAA, worldBB = GetBodyBounds(GetWorldBody())

    local Xpos, Xneg, Zpos, Zneg = nil, nil, nil, nil
    local landSamples = 0
    local waterSamples = 0

    for x = worldAA[1], worldBB[1], gridStep do
        for z = worldAA[3], worldBB[3], gridStep do
            local p = Vec(x, 0, z)

            if select(1, IsPointInBoundaries(p)) then
                -- Track playable extents
                if not Xpos or x > Xpos[1] then Xpos = Vec(x, 0, z) end
                if not Xneg or x < Xneg[1] then Xneg = Vec(x, 0, z) end
                if not Zpos or z > Zpos[3] then Zpos = Vec(x, 0, z) end
                if not Zneg or z < Zneg[3] then Zneg = Vec(x, 0, z) end

                -- Land vs water
                if server.isLandAtXZ(x, z) then
                    landSamples = landSamples + 1
                else
                    waterSamples = waterSamples + 1
                end
            end
        end
    end

    return {
        Xpos = Xpos,
        Xneg = Xneg,
        Zpos = Zpos,
        Zneg = Zneg,
        landSamples = landSamples,
        waterSamples = waterSamples
    }
end


function server.detectLevelsGaussian(heights, binSize, threshold)
    binSize = binSize or 4      -- vertical bin size
    threshold = threshold or 10   -- minimum number of props to count as a level

    -- 1. Find min/max
    local minY, maxY = math.huge, -math.huge
    for i=1,#heights do
        if heights[i] < minY then minY = heights[i] end
        if heights[i] > maxY then maxY = heights[i] end
    end

    local numBins = math.ceil((maxY - minY) / binSize)
    local bins = {}
    for i = 1, numBins do bins[i] = 0 end

    -- 2. Fill bins
    for i = 1, #heights do
        local binIndex = math.floor((heights[i] - minY) / binSize) + 1
        binIndex = math.min(binIndex, numBins)
        bins[binIndex] = bins[binIndex] + 1
    end

    -- 3. Count levels (bins above threshold)
    local levels = {}
    local inLevel = false
    local levelCount = 0
    for i = 1, numBins do
        if bins[i] >= threshold then
            if not inLevel then
                levelCount = levelCount + 1
                inLevel = true
            end
        else
            inLevel = false
        end
    end

    return levelCount, bins
end

function server.collectPropHeightsWithRefs()
    local props = {}

	local vehicle = FindVehicles("", true)
	for i = 1, #vehicle do
		QueryRejectVehicle(vehicle[i])
	end


    local aa, bb = GetBodyBounds(GetWorldBody())
	QueryRequire("physical dynamic large")
    local bodies = QueryAabbBodies(aa, bb)

    for i = 1, #bodies do
        local body = bodies[i]
        if IsBodyDynamic(body) then
            local shapes = GetBodyShapes(body)
            for j = 1, #shapes do
                local shape = shapes[j]
                if not IsShapeBroken(shape) then
                    local t = GetShapeWorldTransform(shape)
                    props[#props + 1] = {
                        shape = shape,
                        body = body,
                        y = t.pos[2],
                        pos = t.pos
                    }
                end
            end
        end
    end

    return props
end

function server.buildHeightHistogram(heights, binSize)
    binSize = binSize or 1

    local minY, maxY = math.huge, -math.huge
    for i = 1, #heights do
        minY = math.min(minY, heights[i])
        maxY = math.max(maxY, heights[i])
    end

    local binCount = math.ceil((maxY - minY) / binSize)
    local bins = {}
    for i = 1, binCount do bins[i] = 0 end

    for i = 1, #heights do
        local idx = math.floor((heights[i] - minY) / binSize) + 1
        idx = math.min(idx, binCount)
        bins[idx] = bins[idx] + 1
    end

    return bins, minY, binSize
end

function server.smoothHistogram(bins, radius)
    radius = radius or 3
    local smoothed = {}

    for i = 1, #bins do
        local sum, weight = 0, 0
        for k = -radius, radius do
            local idx = i + k
            if idx >= 1 and idx <= #bins then
                local w = math.exp(-(k * k) / (2 * radius * radius))
                sum = sum + bins[idx] * w
                weight = weight + w
            end
        end
        smoothed[i] = sum / weight
    end

    return smoothed
end

function server.detectDensityLevels(density)
    local avg = 0
    for i = 1, #density do avg = avg + density[i] end
    avg = avg / math.max(1, #density)

    local levelBins = {}
    local inLevel = false

    for i = 1, #density do
        if density[i] > avg then
            if not inLevel then
                levelBins[#levelBins + 1] = i
                inLevel = true
            end
        else
            inLevel = false
        end
    end

    return levelBins
end

function server.detectPropLevelsWithProps(binSize, smoothRadius)
    binSize = binSize or 1
    smoothRadius = smoothRadius or 3

    local props = server.collectPropHeightsWithRefs()
    if #props == 0 then
        return {
            levelCount = 0,
            levels = {}
        }
    end

    -- Extract heights
    local heights = {}
    for i = 1, #props do
        heights[i] = props[i].y
    end

    -- Density analysis
    local bins, minY, binSize = server.buildHeightHistogram(heights, binSize)
    local density = server.smoothHistogram(bins, smoothRadius)
    local levelBins = server.detectDensityLevels(density)

    -- Convert level bins to Y positions
    local levels = {}
    for i = 1, #levelBins do
        levels[i] = {
            y = minY + (levelBins[i] - 0.5) * binSize,
            props = {}
        }
    end

    -- Assign each prop to nearest level
    for i = 1, #props do
        local bestLevel = nil
        local bestDist = math.huge

        for j = 1, #levels do
            local d = math.abs(props[i].y - levels[j].y)
            if d < bestDist then
                bestDist = d
                bestLevel = j
            end
        end

        table.insert(levels[bestLevel].props, props[i])
    end

    return {
        levelCount = #levels,
        levels = levels,
        density = density
    }
end

function server.analysis()
    local area = server.samplePlayableAreaGrid(3)
    if not area then return end

    local aa = Vec(area.Xneg[1], 0, area.Zneg[3])
    local bb = Vec(area.Xpos[1], 0, area.Zpos[3])

    local worldAA, worldBB = GetBodyBounds(GetWorldBody())
    aa[2] = worldAA[2]
    bb[2] = worldBB[2]

    analysis = {
        Name = GetString("game.mod.title"),
        SizeSmall = 0,
        SizeMedium = 0,
        SizeLarge = 0,
        HeightLowestProp = Vec(0, math.huge, 0),
        HeightHighestProp = Vec(0, -math.huge, 0),
        HeightHighLowDiff = 0,
        propHightDiffAvarage = 0,
        Mapaa = aa,
        Mapbb = bb,
        Mapsize = VecLength(VecSub(Vec(bb[1], 0, bb[3]), Vec(aa[1], 0, aa[3]))),
		MapArea = 0,
        propSpread = 0,
        LandRatio = area.landSamples / math.max(1, (area.landSamples + area.waterSamples)),
        WaterRatio = 1 - (area.landSamples / math.max(1, (area.landSamples + area.waterSamples))),
		PropToLandRatio = 0,

        -- Shape bounds
        PropAA = Vec(math.huge, math.huge, math.huge),
        PropBB = Vec(-math.huge, -math.huge, -math.huge),
        PropSize = Vec(0, 0, 0)
    }


	local vehicle = FindVehicles("", true)
	for i = 1, #vehicle do
		QueryRejectVehicle(vehicle[i])
	end

    QueryRequire("physical dynamic large visible")

    local bodies = QueryAabbBodies(aa, bb)

    local heights = {}
    local heightSum = 0
    local count = 0

    for i = 1, #bodies do
        local body = bodies[i]
        if IsBodyDynamic(body) then
            local shapes = GetBodyShapes(body)
            for j = 1, #shapes do
                local shape = shapes[j]
                if not IsShapeBroken(shape) then
                    local t = GetShapeWorldTransform(shape)
                    local pos = t.pos
                    local x, y, z = GetShapeSize(shape)
                    local vox = GetShapeVoxelCount(shape)

                    -- Size classification
                    if vox < 20 or not ((x > 1 and y > 1) or (x > 1 and z > 1) or (y > 1 and z > 1)) then
                        analysis.SizeSmall = analysis.SizeSmall + 1
                    elseif (x > 70 or y > 70 or z > 70) then
                        analysis.SizeLarge = analysis.SizeLarge + 1
                    else
                        analysis.SizeMedium = analysis.SizeMedium + 1
                    end

                    -- Height stats
                    local h = pos[2]
                    heights[#heights + 1] = h
                    heightSum = heightSum + h
                    count = count + 1

                    if h < analysis.HeightLowestProp[2] then
                        analysis.HeightLowestProp = pos
                    end
                    if h > analysis.HeightHighestProp[2] then
                        analysis.HeightHighestProp = pos
                    end

                    -- Shape AA / BB
                    if pos[1] < analysis.PropAA[1] then analysis.PropAA[1] = pos[1] end
                    if pos[2] < analysis.PropAA[2] then analysis.PropAA[2] = pos[2] end
                    if pos[3] < analysis.PropAA[3] then analysis.PropAA[3] = pos[3] end

                    if pos[1] > analysis.PropBB[1] then analysis.PropBB[1] = pos[1] end
                    if pos[2] > analysis.PropBB[2] then analysis.PropBB[2] = pos[2] end
                    if pos[3] > analysis.PropBB[3] then analysis.PropBB[3] = pos[3] end
                end
            end
        end
    end

    if count > 0 then
        local mean = heightSum / count
        local dev = 0
        for i = 1, #heights do
            dev = dev + math.abs(heights[i] - mean)
        end
        analysis.propHightDiffAvarage = dev / count
        analysis.HeightHighLowDiff =
            analysis.HeightHighestProp[2] - analysis.HeightLowestProp[2]
    end

	
	local width = math.abs(analysis.Mapbb[1] - analysis.Mapaa[1])
	local depth = math.abs(analysis.Mapbb[3] - analysis.Mapaa[3])
	analysis.MapArea = width * depth * analysis.LandRatio / 100

	local totalProps = analysis.SizeMedium
	if analysis.MapArea > 0 then
		analysis.PropToLandRatio = totalProps / analysis.MapArea
	else
		analysis.PropToLandRatio = 0
	end


    -- Prop size
    analysis.PropSize = Vec(
        math.abs(analysis.PropBB[1] - analysis.PropAA[1]),
        math.abs(analysis.PropBB[2] - analysis.PropAA[2]),
        math.abs(analysis.PropBB[3] - analysis.PropAA[3])
    )

    analysis.Mapaa[2] = analysis.HeightLowestProp[2]
    analysis.Mapbb[2] = analysis.HeightHighestProp[2]

    -- DebugWatch("Name", analysis.Name)
    -- DebugWatch("SizeSmall", analysis.SizeSmall)
    -- DebugWatch("SizeMedium", analysis.SizeMedium)
    -- DebugWatch("SizeLarge", analysis.SizeLarge)
    -- DebugWatch("HeightLowestProp", analysis.HeightLowestProp)
    -- DebugWatch("HeightHighestProp", analysis.HeightHighestProp)
    -- DebugWatch("HeightHighLowDiff", analysis.HeightHighLowDiff)
    -- DebugWatch("propHightDiffAvarage", analysis.propHightDiffAvarage)
    -- DebugWatch("Mapaa", analysis.Mapaa)
    -- DebugWatch("Mapbb", analysis.Mapbb)
    -- DebugWatch("Mapsize", analysis.Mapsize)
	-- DebugWatch("MapArea", analysis.MapArea)
    -- DebugWatch("MapHeight", analysis.Mapbb[2] - analysis.Mapaa[2])
    -- DebugWatch("LandRatio", analysis.LandRatio)
    -- DebugWatch("WaterRatio", analysis.WaterRatio)
	-- DebugWatch("PropToAreaRatio", analysis.PropToLandRatio)

	local result = server.detectPropLevelsWithProps(1, 3)
    analysis.levels = result.levels

    server.mapdata = analysis
end

