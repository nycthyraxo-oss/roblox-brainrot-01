-- Brainrot Stealer: amusement park map builder.
-- Builds the whole park into the Workspace at runtime: glowing brainrot path
-- loop, tiled plaza, four player bases, Warehouse / Shop / Safe Zone
-- buildings, ferris wheel, roller coaster, carnival tents, leaderboard,
-- trees, balloons, perimeter wall and props. Returns the world table other
-- services read (Bases, LeaderboardRows, PathWaypoints).

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local MapBuilder = {}

-- Ground: the project baseplate top sits at y = -5. Everything rests on it.
local GROUND_Y = -5
-- Trilayer path: dark base slab 1.2 thick + neon core 0.25 on top.
local PATH_BASE_TOP_Y = GROUND_Y + 1.2
local PATH_TOP_Y = PATH_BASE_TOP_Y + 0.25 -- neon core surface
local PLAZA_TOP_Y = GROUND_Y + 0.3 -- plaza tile surface

-- Path loop geometry (centerline half-extent, width).
local PATH_HALF = 122
local PATH_WIDTH = 16
local PATH_OUTER = PATH_HALF + PATH_WIDTH / 2 -- 130
local PATH_INNER = PATH_HALF - PATH_WIDTH / 2 -- 114

-- Palette (bright, saturated, kid-friendly carnival colors).
local WHITE = Color3.fromRGB(245, 245, 250)
local BLACK = Color3.fromRGB(30, 30, 38)
local GRAY = Color3.fromRGB(150, 155, 165)
local DARK_GRAY = Color3.fromRGB(90, 95, 110)
local LIGHT_TILE = Color3.fromRGB(225, 228, 235)
local MID_TILE = Color3.fromRGB(190, 195, 208)
local PURPLE = Color3.fromRGB(170, 60, 255)
local RED = Color3.fromRGB(255, 60, 70)
local GREEN = Color3.fromRGB(60, 230, 110)
local YELLOW = Color3.fromRGB(255, 205, 40)
local BLUE = Color3.fromRGB(60, 140, 255)
local ORANGE = Color3.fromRGB(255, 140, 40)
local PINK = Color3.fromRGB(255, 110, 190)
local CYAN = Color3.fromRGB(60, 220, 240)
local BROWN = Color3.fromRGB(120, 80, 50)
local LEAF_GREEN = Color3.fromRGB(70, 200, 90)
local LEAF_PINK = Color3.fromRGB(255, 150, 210)
local PINE_GREEN = Color3.fromRGB(35, 140, 70)
local LIT_WINDOW = Color3.fromRGB(255, 225, 130)
local RIM_IDLE = Color3.fromRGB(140, 145, 155)
local PATH_BASE = Color3.fromRGB(24, 24, 30) -- near-black path base slab
local CONCRETE = Color3.fromRGB(168, 170, 176) -- plinth concrete

local partCount = 0

-- RGB lamp bulbs animated in the Heartbeat loop (bulb + optional light).
local rgbBulbs: { { bulb: BasePart, light: PointLight?, phase: number } } = {}

-- Create one anchored Part with explicit collision/touch/query flags.
-- Parent is set last, per Luau best practice.
local function makePart(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	collide: boolean,
	touch: boolean,
	query: boolean
): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = collide
	part.CanTouch = touch
	part.CanQuery = query
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	partCount += 1
	return part
end

-- Solid decorative part (collides, no touch/query needed).
local function solid(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return makePart(parent, size, cframe, color, material, true, false, false)
end

-- Non-collidable decor part.
local function decor(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return makePart(parent, size, cframe, color, material, false, false, false)
end

-- Ball part.
local function ball(parent: Instance, diameter: number, position: Vector3, color: Color3, material: Enum.Material, collide: boolean): Part
	local part = makePart(parent, Vector3.new(diameter, diameter, diameter), CFrame.new(position), color, material, collide, false, false)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Upright cylinder (axis along Y).
local function cylinder(parent: Instance, radius: number, height: number, position: Vector3, color: Color3, material: Enum.Material, collide: boolean): Part
	local part = makePart(
		parent,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		collide,
		false,
		false
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A sign board with a SurfaceGui text label on one face.
local function makeSign(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	boardColor: Color3,
	text: string,
	textColor: Color3,
	face: Enum.NormalId
): (Part, TextLabel)
	local board = decor(parent, size, cframe, boardColor, Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	return board, label
end

-- A box stretched between two points (track segments, spokes, slats).
-- lookAt orients the CFrame's -Z along from->to, so the box length runs
-- along local Z, widthAcross along local X, thicknessVertical along local Y.
local function beamBetween(parent: Instance, from: Vector3, to: Vector3, widthAcross: number, thicknessVertical: number, color: Color3, material: Enum.Material, collide: boolean): Part
	local mid = (from + to) / 2
	local length = (to - from).Magnitude
	local cf = CFrame.lookAt(mid, to)
	return makePart(parent, Vector3.new(widthAcross, thicknessVertical, length), cf, color, material, collide, false, false)
end

----------------------------------------------------------------------
-- The glowing Brainrot Path loop + waypoints
----------------------------------------------------------------------

local function buildPath(park: Instance): { Vector3 }
	local folder = Instance.new("Folder")
	folder.Name = "BrainrotPath"
	folder.Parent = park

	local sideColors = {
		North = GREEN,
		East = RED,
		South = PURPLE,
		West = PURPLE,
	}
	local edgeColor = WHITE

	-- Corner slabs first.
	local corners = {
		Vector3.new(-PATH_HALF, 0, -PATH_HALF),
		Vector3.new(PATH_HALF, 0, -PATH_HALF),
		Vector3.new(PATH_HALF, 0, PATH_HALF),
		Vector3.new(-PATH_HALF, 0, PATH_HALF),
	}
	local cornerColors = { GREEN, GREEN, RED, PURPLE }
	for i, corner in ipairs(corners) do
		-- Trilayer corner: dark base + neon core + white trim frame.
		solid(
			folder,
			Vector3.new(PATH_WIDTH, 1.2, PATH_WIDTH),
			CFrame.new(corner.X, GROUND_Y + 0.6, corner.Z),
			PATH_BASE,
			Enum.Material.SmoothPlastic
		)
		solid(
			folder,
			Vector3.new(10, 0.25, 10),
			CFrame.new(corner.X, PATH_BASE_TOP_Y + 0.125, corner.Z),
			cornerColors[i],
			Enum.Material.Neon
		)
		for _, spec in ipairs({
			{ Vector3.new(0, 0, -7.4), Vector3.new(16.4, 0.15, 1.6) },
			{ Vector3.new(0, 0, 7.4), Vector3.new(16.4, 0.15, 1.6) },
			{ Vector3.new(-7.4, 0, 0), Vector3.new(1.6, 0.15, 16.4) },
			{ Vector3.new(7.4, 0, 0), Vector3.new(1.6, 0.15, 16.4) },
		}) do
			local offset = spec[1] :: Vector3
			local size = spec[2] :: Vector3
			decor(
				folder,
				size,
				CFrame.new(corner.X + offset.X, PATH_BASE_TOP_Y + 0.075, corner.Z + offset.Z),
				edgeColor,
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- Side runs: trilayer segments of 6 studs between the corner slabs.
	-- Dark base (16 wide, 1.2 thick) + neon core (10 wide, 0.25 thick) +
	-- white trim strips along both edges, slightly wider than the base.
	local function buildSide(from: Vector3, to: Vector3, color: Color3)
		local direction = (to - from).Unit
		local totalLength = (to - from).Magnitude
		local slabLen = 6
		local count = math.floor(totalLength / slabLen)
		local yaw = math.atan2(-direction.Z, direction.X)
		for i = 0, count - 1 do
			local center = from + direction * (slabLen * (i + 0.5))
			solid(
				folder,
				Vector3.new(slabLen, 1.2, PATH_WIDTH),
				CFrame.new(center.X, GROUND_Y + 0.6, center.Z) * CFrame.Angles(0, yaw, 0),
				PATH_BASE,
				Enum.Material.SmoothPlastic
			)
			solid(
				folder,
				Vector3.new(slabLen, 0.25, 10),
				CFrame.new(center.X, PATH_BASE_TOP_Y + 0.125, center.Z) * CFrame.Angles(0, yaw, 0),
				color,
				Enum.Material.Neon
			)
			local sideOffset = Vector3.new(-direction.Z, 0, direction.X) * 7.4
			for _, sign in ipairs({ -1, 1 }) do
				local edgePos = center + sideOffset * sign
				decor(
					folder,
					Vector3.new(slabLen, 0.15, 1.6),
					CFrame.new(edgePos.X, PATH_BASE_TOP_Y + 0.075, edgePos.Z) * CFrame.Angles(0, yaw, 0),
					edgeColor,
					Enum.Material.SmoothPlastic
				)
			end
		end
	end

	local inner = PATH_HALF - PATH_WIDTH / 2 -- 114: side runs span between corners
	buildSide(Vector3.new(-inner, 0, -PATH_HALF), Vector3.new(inner, 0, -PATH_HALF), sideColors.North)
	buildSide(Vector3.new(PATH_HALF, 0, -inner), Vector3.new(PATH_HALF, 0, inner), sideColors.East)
	buildSide(Vector3.new(inner, 0, PATH_HALF), Vector3.new(-inner, 0, PATH_HALF), sideColors.South)
	buildSide(Vector3.new(-PATH_HALF, 0, inner), Vector3.new(-PATH_HALF, 0, -inner), sideColors.West)

	-- Waypoints: start under the north arch, walk east, south, west, north,
	-- ending one short leg west of the start (closed loop shape).
	local waypoints: { Vector3 } = {}
	local function addWaypoint(x: number, z: number)
		table.insert(waypoints, Vector3.new(x, PATH_TOP_Y, z))
	end
	-- North side, from arch (0,-122) east to corner (122,-122).
	for x = 0, PATH_HALF, 20 do
		addWaypoint(x, -PATH_HALF)
	end
	addWaypoint(PATH_HALF, -PATH_HALF)
	-- East side, south to (122,122).
	for z = -PATH_HALF + 20, PATH_HALF, 20 do
		addWaypoint(PATH_HALF, z)
	end
	addWaypoint(PATH_HALF, PATH_HALF)
	-- South side, west to (-122,122).
	for x = PATH_HALF - 20, -PATH_HALF, -20 do
		addWaypoint(x, PATH_HALF)
	end
	addWaypoint(-PATH_HALF, PATH_HALF)
	-- West side, north to (-122,-122).
	for z = PATH_HALF - 20, -PATH_HALF, -20 do
		addWaypoint(-PATH_HALF, z)
	end
	addWaypoint(-PATH_HALF, -PATH_HALF)
	-- North side west part, east toward the arch; stop one leg short.
	for x = -PATH_HALF + 20, -20, 20 do
		addWaypoint(x, -PATH_HALF)
	end

	-- Glowing chevrons along the walking direction, every other waypoint.
	for i = 1, #waypoints - 1, 2 do
		local a = waypoints[i]
		local b = waypoints[i + 1]
		local mid = (a + b) / 2
		local dir = (b - a).Unit
		local yaw = math.atan2(-dir.Z, dir.X)
		for _, sign in ipairs({ -1, 1 }) do
			local offset = Vector3.new(-dir.Z, 0, dir.X) * (2.2 * sign) + dir * -1.2
			local pos = mid + offset
			decor(
				folder,
				Vector3.new(4.4, 0.25, 1.1),
				CFrame.new(pos.X, PATH_TOP_Y + 0.15, pos.Z) * CFrame.Angles(0, yaw + math.rad(38) * sign, 0),
				WHITE,
				Enum.Material.Neon
			)
		end
	end

	return waypoints
end

----------------------------------------------------------------------
-- Tiled plaza floor inside the loop + walkways to the bases
----------------------------------------------------------------------

local function buildPlaza(park: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	folder.Parent = park

	local tile = 8
	local half = 92 -- tiles from -92 to +92
	for ix = -half, half - tile, tile do
		for iz = -half, half - tile, tile do
			local checker = ((ix / tile) + (iz / tile)) % 2 == 0
			local color = if checker then LIGHT_TILE else MID_TILE
			solid(
				folder,
				Vector3.new(tile, 0.3, tile),
				CFrame.new(ix + tile / 2, GROUND_Y + 0.15, iz + tile / 2),
				color,
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- Neon border trim around the plaza.
	local borderLen = half * 2 + 2
	for _, spec in ipairs({
		{ Vector3.new(0, 0, -half - 1), Vector3.new(borderLen, 0.5, 2) },
		{ Vector3.new(0, 0, half + 1), Vector3.new(borderLen, 0.5, 2) },
		{ Vector3.new(-half - 1, 0, 0), Vector3.new(2, 0.5, borderLen) },
		{ Vector3.new(half + 1, 0, 0), Vector3.new(2, 0.5, borderLen) },
	}) do
		local pos = spec[1] :: Vector3
		local size = spec[2] :: Vector3
		decor(folder, size, CFrame.new(pos.X, GROUND_Y + 0.25, pos.Z), CYAN, Enum.Material.Neon)
	end

	-- Walkways from plaza corners across the raised path to each base
	-- gateway: flat, ramp up, flat crossing over the path, ramp down, flat.
	local walkColor = Color3.fromRGB(255, 240, 200)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local dir = Vector3.new(sx, 0, sz).Unit
			local yaw = math.atan2(-dir.Z, dir.X)
			local function pointAt(t: number, y: number): Vector3
				return Vector3.new(sx * (92 + t), y, sz * (92 + t))
			end
			local lowTop = GROUND_Y + 0.35
			local highTop = PATH_TOP_Y + 0.1
			-- Inner flat (t 0..18) and outer flat (t 42..56).
			for _, span in ipairs({ { 0, 18 }, { 42, 56 } }) do
				local a = pointAt(span[1], lowTop - 0.18)
				local b = pointAt(span[2], lowTop - 0.18)
				local mid = (a + b) / 2
				solid(
					folder,
					Vector3.new((b - a).Magnitude, 0.35, 7),
					CFrame.new(mid.X, mid.Y, mid.Z) * CFrame.Angles(0, yaw, 0),
					walkColor,
					Enum.Material.SmoothPlastic
				)
			end
			-- Crossing flat over the path band (t 22..38).
			local ca = pointAt(22, highTop - 0.18)
			local cb = pointAt(38, highTop - 0.18)
			local cmid = (ca + cb) / 2
			solid(
				folder,
				Vector3.new((cb - ca).Magnitude, 0.35, 7),
				CFrame.new(cmid.X, cmid.Y, cmid.Z) * CFrame.Angles(0, yaw, 0),
				walkColor,
				Enum.Material.SmoothPlastic
			)
			-- Ramps up and down.
			beamBetween(folder, pointAt(18, lowTop - 0.18), pointAt(22, highTop - 0.18), 7, 0.35, walkColor, Enum.Material.SmoothPlastic, true)
			beamBetween(folder, pointAt(38, highTop - 0.18), pointAt(42, lowTop - 0.18), 7, 0.35, walkColor, Enum.Material.SmoothPlastic, true)
		end
	end
end

----------------------------------------------------------------------
-- Spawn portal arch over the north path
----------------------------------------------------------------------

local function buildArch(park: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "SpawnArch"
	folder.Parent = park

	local z = -PATH_HALF
	-- Striped pillars either side of the path, on concrete plinths.
	for _, sx in ipairs({ -1, 1 }) do
		solid(folder, Vector3.new(3.6, 1.5, 3.6), CFrame.new(sx * 11, GROUND_Y + 0.75, z), CONCRETE, Enum.Material.SmoothPlastic)
		for i = 0, 4 do
			local color = if i % 2 == 0 then RED else WHITE
			solid(
				folder,
				Vector3.new(2.4, 2.6, 2.4),
				CFrame.new(sx * 11, GROUND_Y + 2.8 + i * 2.6, z),
				color,
				Enum.Material.SmoothPlastic
			)
		end
		ball(folder, 3, Vector3.new(sx * 11, GROUND_Y + 15.9, z), YELLOW, Enum.Material.Neon, false)
	end
	-- Top beam + sign.
	solid(folder, Vector3.new(27, 3, 3), CFrame.new(0, GROUND_Y + 16, z), PURPLE, Enum.Material.SmoothPlastic)
	makeSign(
		folder,
		Vector3.new(24, 4.5, 1),
		CFrame.new(0, GROUND_Y + 16, z + 1.6),
		BLACK,
		"BRAINROT PATH",
		WHITE,
		Enum.NormalId.Front
	)
	-- Hanging star bulbs under the beam.
	for i = -3, 3 do
		ball(folder, 1.4, Vector3.new(i * 3.4, GROUND_Y + 13.9, z), if i % 2 == 0 then CYAN else PINK, Enum.Material.Neon, false)
	end
end

----------------------------------------------------------------------
-- Spawn plaza disc + the single SpawnLocation
----------------------------------------------------------------------

local function buildSpawnPlaza(park: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "SpawnPlaza"
	folder.Parent = park

	local center = Vector3.new(0, GROUND_Y, 55)
	-- Raised plaza discs (plinth-height, no z-fighting with the grass).
	cylinder(folder, 15, 1.5, center + Vector3.new(0, 0.75, 0), Color3.fromRGB(255, 230, 170), Enum.Material.SmoothPlastic, true)
	cylinder(folder, 11, 1.7, center + Vector3.new(0, 0.85, 0), Color3.fromRGB(255, 200, 220), Enum.Material.SmoothPlastic, true)

	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(9, 1, 9)
	spawn.CFrame = CFrame.new(center + Vector3.new(0, 2.2, 0))
	spawn.Color = WHITE
	spawn.Material = Enum.Material.Neon
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Parent = folder
	partCount += 1

	-- Ring of small glowing posts around the disc, on concrete bases.
	for i = 0, 7 do
		local angle = (i / 8) * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * 17, 0, math.sin(angle) * 17)
		solid(folder, Vector3.new(1.1, 1.5, 1.1), CFrame.new(pos + Vector3.new(0, 0.75, 0)), CONCRETE, Enum.Material.SmoothPlastic)
		solid(folder, Vector3.new(0.7, 3, 0.7), CFrame.new(pos + Vector3.new(0, 3, 0)), DARK_GRAY, Enum.Material.SmoothPlastic)
		ball(folder, 1.3, pos + Vector3.new(0, 4.9, 0), CYAN, Enum.Material.Neon, false)
	end
end

----------------------------------------------------------------------
-- Player bases (4, one per quadrant, outside the path loop)
----------------------------------------------------------------------

local function buildBase(park: Instance, center: Vector3, baseColor: Color3, gatewaySign: number): any
	-- gatewaySign: +1 gateway on the +Z side, -1 on the -Z side (faces path).
	local folder = Instance.new("Folder")
	folder.Name = "Base"
	folder.Parent = park

	local cx, cz = center.X, center.Z
	-- Concrete plinth 33 x 27, 1.5 tall; colored floor slab sits on top.
	solid(folder, Vector3.new(33, 1.5, 27), CFrame.new(cx, GROUND_Y + 0.75, cz), CONCRETE, Enum.Material.SmoothPlastic)
	local floorY = GROUND_Y + 1.7

	-- Floor slab 32 x 26 (matches the inside-base half-extents 16 x 13).
	solid(folder, Vector3.new(32, 0.4, 26), CFrame.new(cx, floorY, cz), baseColor, Enum.Material.SmoothPlastic)
	-- Inner floor inlay.
	decor(folder, Vector3.new(29, 0.15, 23), CFrame.new(cx, floorY + 0.28, cz), WHITE, Enum.Material.SmoothPlastic)

	-- PlaceZone: invisible touch volume over the whole floor.
	local placeZone = makePart(
		folder,
		Vector3.new(32, 4, 26),
		CFrame.new(cx, floorY + 2, cz),
		WHITE,
		Enum.Material.SmoothPlastic,
		false,
		true,
		false
	)
	placeZone.Transparency = 1
	placeZone.Name = "PlaceZone"

	-- Pink runway down the middle, from gateway to back fence.
	decor(
		folder,
		Vector3.new(6, 0.2, 24),
		CFrame.new(cx, floorY + 0.32, cz),
		Color3.fromRGB(255, 170, 215),
		Enum.Material.SmoothPlastic
	)

	-- 8 pedestals in two rows of 4, each with a neon rim on top.
	local pedestals: { Part } = {}
	local rims: { Part } = {}
	local slot = 0
	for _, rowZ in ipairs({ -6.5, 6.5 }) do
		for _, colX in ipairs({ -12, -4, 4, 12 }) do
			slot += 1
			local px, pz = cx + colX, cz + rowZ
			local pedestal = makePart(
				folder,
				Vector3.new(3.4, 1.2, 3.4),
				CFrame.new(px, floorY + 0.8, pz),
				DARK_GRAY,
				Enum.Material.SmoothPlastic,
				true,
				true,
				false
			)
			pedestal.Name = "Pedestal" .. slot
			local rim = decor(
				folder,
				Vector3.new(3.9, 0.35, 3.9),
				CFrame.new(px, floorY + 1.55, pz),
				RIM_IDLE,
				Enum.Material.Neon
			)
			rim.Name = "Rim" .. slot
			pedestals[slot] = pedestal
			rims[slot] = rim
		end
	end

	-- 6 white canopy posts.
	local postTopY = floorY + 9.5
	for _, px in ipairs({ -15, 0, 15 }) do
		for _, pz in ipairs({ -12, 12 }) do
			solid(
				folder,
				Vector3.new(1, 9.5, 1),
				CFrame.new(cx + px, floorY + 4.95, cz + pz),
				WHITE,
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- Striped canopy roof: alternating white / base-color slabs.
	local stripeCount = 8
	local roofDepth = 28
	local stripeDepth = roofDepth / stripeCount
	for i = 0, stripeCount - 1 do
		local color = if i % 2 == 0 then WHITE else baseColor
		decor(
			folder,
			Vector3.new(34, 0.7, stripeDepth),
			CFrame.new(cx, postTopY + 0.35, cz - roofDepth / 2 + stripeDepth * (i + 0.5)),
			color,
			Enum.Material.SmoothPlastic
		)
	end
	-- Ridge beam + corner finials.
	decor(folder, Vector3.new(34.5, 0.8, 1.2), CFrame.new(cx, postTopY + 1, cz), baseColor, Enum.Material.Neon)
	for _, fx in ipairs({ -16.5, 16.5 }) do
		for _, fz in ipairs({ -13.5, 13.5 }) do
			ball(folder, 1.6, Vector3.new(cx + fx, postTopY + 1.1, cz + fz), YELLOW, Enum.Material.SmoothPlastic, false)
		end
	end

	-- Low white fence on three sides; gateway side stays open.
	-- Railing top rail sits ~1.1 above the floor surface.
	local fenceY = floorY + 0.9
	local function fenceRun(from: Vector3, to: Vector3)
		local dir = (to - from).Unit
		local length = (to - from).Magnitude
		local yaw = math.atan2(-dir.Z, dir.X)
		local mid = (from + to) / 2
		solid(folder, Vector3.new(length, 0.5, 0.4), CFrame.new(mid.X, fenceY + 0.4, mid.Z) * CFrame.Angles(0, yaw, 0), WHITE, Enum.Material.SmoothPlastic)
		solid(folder, Vector3.new(length, 0.5, 0.4), CFrame.new(mid.X, fenceY - 0.3, mid.Z) * CFrame.Angles(0, yaw, 0), WHITE, Enum.Material.SmoothPlastic)
		local posts = math.max(2, math.floor(length / 4))
		for i = 0, posts do
			local p = from + dir * (length * i / posts)
			solid(folder, Vector3.new(0.5, 1.4, 0.5), CFrame.new(p.X, fenceY, p.Z), WHITE, Enum.Material.SmoothPlastic)
		end
	end
	local gx0, gx1 = cx - 16, cx + 16
	local gz0, gz1 = cz - 13, cz + 13
	-- Back fence (opposite the gateway).
	local backZ = if gatewaySign > 0 then gz0 else gz1
	fenceRun(Vector3.new(gx0, 0, backZ), Vector3.new(gx1, 0, backZ))
	-- Side fences.
	fenceRun(Vector3.new(gx0, 0, gz0), Vector3.new(gx0, 0, gz1))
	fenceRun(Vector3.new(gx1, 0, gz0), Vector3.new(gx1, 0, gz1))
	-- Gateway side: two short fence stubs leaving a wide opening.
	local gateZ = if gatewaySign > 0 then gz1 else gz0
	fenceRun(Vector3.new(gx0, 0, gateZ), Vector3.new(cx - 6, 0, gateZ))
	fenceRun(Vector3.new(cx + 6, 0, gateZ), Vector3.new(gx1, 0, gateZ))

	-- Gateway ramp from the grass up to the raised floor.
	beamBetween(
		folder,
		Vector3.new(cx, GROUND_Y + 0.2, gateZ + gatewaySign * 5),
		Vector3.new(cx, floorY + 0.2, gateZ),
		10,
		0.4,
		baseColor,
		Enum.Material.SmoothPlastic,
		true
	)

	-- Sign board above the gateway (carries the SignLabel).
	local signFace = if gatewaySign > 0 then Enum.NormalId.Back else Enum.NormalId.Front
	local _, signLabel = makeSign(
		folder,
		Vector3.new(16, 3.4, 0.8),
		CFrame.new(cx, postTopY - 0.6, gateZ + gatewaySign * 0.6),
		baseColor,
		"EMPTY BASE",
		WHITE,
		signFace
	)
	-- Gold beam under the sign.
	decor(folder, Vector3.new(17, 0.6, 1), CFrame.new(cx, postTopY - 2.5, gateZ + gatewaySign * 0.6), YELLOW, Enum.Material.Neon)

	-- Trophy shelf on the back fence with three gold stars.
	local shelfZ = backZ - (if gatewaySign > 0 then -1.2 else 1.2)
	decor(folder, Vector3.new(10, 0.5, 1.6), CFrame.new(cx, floorY + 3.4, shelfZ), BROWN, Enum.Material.WoodPlanks)
	for i = -1, 1 do
		ball(folder, 1.5, Vector3.new(cx + i * 3, floorY + 4.4, shelfZ), YELLOW, Enum.Material.SmoothPlastic, false)
	end

	-- Corner crystals + a mini round tree inside the base.
	for _, sx in ipairs({ -1, 1 }) do
		local crystal = decor(
			folder,
			Vector3.new(1.2, 3.2, 1.2),
			CFrame.new(cx + sx * 14, floorY + 1.8, cz - gatewaySign * 10.5) * CFrame.Angles(math.rad(12), 0, math.rad(8) * sx),
			CYAN,
			Enum.Material.SmoothPlastic
		)
		crystal.Name = "Crystal"
	end
	local treeX, treeZ = cx - 13.5, cz + gatewaySign * 9.5
	cylinder(folder, 0.5, 2.6, Vector3.new(treeX, floorY + 1.3, treeZ), BROWN, Enum.Material.Wood, true)
	ball(folder, 4, Vector3.new(treeX, floorY + 4.4, treeZ), LEAF_PINK, Enum.Material.SmoothPlastic, false)

	return {
		Center = Vector3.new(cx, floorY, cz),
		PlaceZone = placeZone,
		Pedestals = pedestals,
		Rims = rims,
		SignLabel = signLabel,
	}
end

----------------------------------------------------------------------
-- Buildings: Warehouse, Shop, Safe Zone
----------------------------------------------------------------------

-- A row of inset lit windows on a wall face. `center` sits ON the wall
-- face; yaw orients the row so local +Z points out of the wall. Each window
-- is a dark interior box proud of the wall with a thin glowing pane recessed
-- behind its front face, plus a white sill — reads as a real inset window.
local function windowRow(parent: Instance, center: Vector3, count: number, spacing: number, yaw: number, y: number)
	local normal = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
	for i = 0, count - 1 do
		local offset = (i - (count - 1) / 2) * spacing
		local pos = center + Vector3.new(math.cos(yaw) * offset, 0, -math.sin(yaw) * offset)
		-- Dark interior box.
		decor(
			parent,
			Vector3.new(3.6, 4, 0.4),
			CFrame.new(pos + normal * 0.1 + Vector3.new(0, y - pos.Y, 0)) * CFrame.Angles(0, yaw, 0),
			Color3.fromRGB(35, 38, 48),
			Enum.Material.SmoothPlastic
		)
		-- Glowing pane, recessed behind the dark box front.
		decor(
			parent,
			Vector3.new(3, 3.4, 0.1),
			CFrame.new(pos + normal * 0.12 + Vector3.new(0, y - pos.Y, 0)) * CFrame.Angles(0, yaw, 0),
			LIT_WINDOW,
			Enum.Material.Neon
		)
		-- White sill under the window.
		decor(
			parent,
			Vector3.new(3.9, 0.35, 0.6),
			CFrame.new(pos + normal * 0.2 + Vector3.new(0, y - pos.Y - 2.1, 0)) * CFrame.Angles(0, yaw, 0),
			WHITE,
			Enum.Material.SmoothPlastic
		)
	end
end

local function buildWarehouse(park: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Warehouse"
	folder.Parent = park

	local cx, cz = 0, -168
	local wallColor = Color3.fromRGB(120, 135, 165)
	local baseY = GROUND_Y

	-- Main block 44 x 18 x 28 with a roof slab and trim.
	solid(folder, Vector3.new(44, 18, 28), CFrame.new(cx, baseY + 9, cz), wallColor, Enum.Material.SmoothPlastic)
	-- Concrete plinth band at the bottom (~15% of height).
	solid(folder, Vector3.new(45, 2.7, 29), CFrame.new(cx, baseY + 1.35, cz), CONCRETE, Enum.Material.SmoothPlastic)
	-- Crown band: cornice strip + thin neon accent + roof slab.
	solid(folder, Vector3.new(46, 0.6, 30), CFrame.new(cx, baseY + 16.9, cz), WHITE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(47, 1.6, 31), CFrame.new(cx, baseY + 18.8, cz), DARK_GRAY, Enum.Material.SmoothPlastic)
	decor(folder, Vector3.new(47, 0.8, 31), CFrame.new(cx, baseY + 17.6, cz), CYAN, Enum.Material.Neon)
	-- Corner pillars.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			solid(folder, Vector3.new(2.4, 18, 2.4), CFrame.new(cx + sx * 21.5, baseY + 9, cz + sz * 13.5), WHITE, Enum.Material.SmoothPlastic)
		end
	end

	-- Sign on the front (south) face.
	makeSign(folder, Vector3.new(30, 5, 1), CFrame.new(cx, baseY + 15.5, cz + 14.4), BLACK, "Brainrot Warehouse", WHITE, Enum.NormalId.Front)

	-- Pink brain logo: a cluster of pink spheres on the front wall.
	local brainCenter = Vector3.new(cx - 15, baseY + 10, cz + 14.6)
	ball(folder, 5, brainCenter, PINK, Enum.Material.SmoothPlastic, false)
	ball(folder, 3.4, brainCenter + Vector3.new(2.2, 1.2, 0.4), PINK, Enum.Material.SmoothPlastic, false)
	ball(folder, 3, brainCenter + Vector3.new(-2.1, 1.4, 0.4), Color3.fromRGB(255, 140, 205), Enum.Material.SmoothPlastic, false)
	ball(folder, 2.6, brainCenter + Vector3.new(0.4, 2.4, 0.4), Color3.fromRGB(255, 140, 205), Enum.Material.SmoothPlastic, false)
	ball(folder, 2.2, brainCenter + Vector3.new(-0.8, -1.6, 0.5), Color3.fromRGB(240, 90, 170), Enum.Material.SmoothPlastic, false)

	-- Lit windows: two rows on the front, one row each side.
	windowRow(folder, Vector3.new(cx + 8, 0, cz + 14), 4, 6, 0, baseY + 10)
	windowRow(folder, Vector3.new(cx, 0, cz + 14), 6, 6.5, 0, baseY + 5.5)
	windowRow(folder, Vector3.new(cx - 22, 0, cz), 3, 7, math.rad(-90), baseY + 10)
	windowRow(folder, Vector3.new(cx + 22, 0, cz), 3, 7, math.rad(90), baseY + 10)

	-- Open loading bay: dark inset + stacked crates in front.
	decor(folder, Vector3.new(14, 8, 0.6), CFrame.new(cx + 8, baseY + 4, cz + 14.1), BLACK, Enum.Material.SmoothPlastic)
	decor(folder, Vector3.new(15, 1, 1.4), CFrame.new(cx + 8, baseY + 8.4, cz + 14.3), YELLOW, Enum.Material.Neon)
	local crateColors = { BROWN, Color3.fromRGB(160, 115, 70), Color3.fromRGB(100, 70, 45) }
	for i = 0, 5 do
		local px = cx + 3.5 + (i % 3) * 3.4
		local py = baseY + 1.5 + math.floor(i / 3) * 3
		solid(folder, Vector3.new(3, 3, 3), CFrame.new(px, py, cz + 16.5), crateColors[(i % 3) + 1], Enum.Material.WoodPlanks)
	end
	solid(folder, Vector3.new(3, 3, 3), CFrame.new(cx + 6.9, baseY + 7.5, cz + 16.5), crateColors[2], Enum.Material.WoodPlanks)

	-- Roof vents and a flag.
	for _, vx in ipairs({ -12, 0, 12 }) do
		solid(folder, Vector3.new(4, 2.4, 4), CFrame.new(cx + vx, baseY + 20.8, cz), GRAY, Enum.Material.SmoothPlastic)
	end
	solid(folder, Vector3.new(0.5, 7, 0.5), CFrame.new(cx, baseY + 23, cz), DARK_GRAY, Enum.Material.SmoothPlastic)
	decor(folder, Vector3.new(4, 2.2, 0.3), CFrame.new(cx + 2.2, baseY + 25.4, cz), PINK, Enum.Material.SmoothPlastic)
end

local function buildShop(park: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Shop"
	folder.Parent = park

	local cx, cz = 168, -45
	local baseY = GROUND_Y

	-- Orange block 36 x 14 x 24 (front faces west, toward the path).
	solid(folder, Vector3.new(24, 14, 36), CFrame.new(cx, baseY + 7, cz), ORANGE, Enum.Material.SmoothPlastic)
	-- Concrete plinth band (~15% of height) + crown band.
	solid(folder, Vector3.new(25, 2.1, 37), CFrame.new(cx, baseY + 1.05, cz), CONCRETE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(26, 0.5, 38), CFrame.new(cx, baseY + 12.9, cz), WHITE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(27, 1.4, 39), CFrame.new(cx, baseY + 14.7, cz), Color3.fromRGB(200, 90, 30), Enum.Material.SmoothPlastic)
	decor(folder, Vector3.new(27, 0.7, 39), CFrame.new(cx, baseY + 13.6, cz), YELLOW, Enum.Material.Neon)

	-- Sign on the west face.
	makeSign(folder, Vector3.new(1, 5, 20), CFrame.new(cx - 12.4, baseY + 11.5, cz), BLACK, "Shop", WHITE, Enum.NormalId.Left)

	-- Striped awning over the front: angled slabs.
	for i = 0, 5 do
		local color = if i % 2 == 0 then WHITE else RED
		decor(
			folder,
			Vector3.new(6, 0.4, 5.4),
			CFrame.new(cx - 14.5, baseY + 8.6, cz - 13.5 + i * 5.4) * CFrame.Angles(0, 0, math.rad(28)),
			color,
			Enum.Material.SmoothPlastic
		)
	end
	-- Display windows under the awning (dark frame + inset glowing pane).
	for i = 0, 3 do
		decor(folder, Vector3.new(0.4, 5, 6.6), CFrame.new(cx - 12.1, baseY + 4.6, cz - 12 + i * 8), Color3.fromRGB(35, 38, 48), Enum.Material.SmoothPlastic)
		decor(folder, Vector3.new(0.1, 4.4, 6), CFrame.new(cx - 12.25, baseY + 4.6, cz - 12 + i * 8), LIT_WINDOW, Enum.Material.Neon)
	end
	-- Door, human scale: 5.5 wide x 10 tall, with a gold handle.
	decor(folder, Vector3.new(0.5, 10, 5.5), CFrame.new(cx - 12.3, baseY + 5, cz + 14), DARK_GRAY, Enum.Material.SmoothPlastic)
	ball(folder, 0.8, Vector3.new(cx - 12.7, baseY + 5, cz + 12.2), YELLOW, Enum.Material.SmoothPlastic, false)
	-- Side windows.
	windowRow(folder, Vector3.new(cx, 0, cz - 18), 3, 6, math.rad(180), baseY + 9)
	windowRow(folder, Vector3.new(cx, 0, cz + 18), 3, 6, 0, baseY + 9)

	-- Crates and a barrel by the door.
	solid(folder, Vector3.new(3, 3, 3), CFrame.new(cx - 15, baseY + 1.5, cz + 17), BROWN, Enum.Material.WoodPlanks)
	solid(folder, Vector3.new(2.4, 2.4, 2.4), CFrame.new(cx - 15, baseY + 4.2, cz + 17), Color3.fromRGB(160, 115, 70), Enum.Material.WoodPlanks)
	cylinder(folder, 1.6, 3.4, Vector3.new(cx - 15, baseY + 1.7, cz - 16), BLUE, Enum.Material.SmoothPlastic, true)
end

local function buildSafeZone(park: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "SafeZone"
	folder.Parent = park

	local cx, cz = 168, 35
	local baseY = GROUND_Y

	-- Blue block 36 x 14 x 24 with multicolored block-panel walls.
	solid(folder, Vector3.new(24, 14, 36), CFrame.new(cx, baseY + 7, cz), BLUE, Enum.Material.SmoothPlastic)
	-- Concrete plinth band (~15% of height) + crown band.
	solid(folder, Vector3.new(25, 2.1, 37), CFrame.new(cx, baseY + 1.05, cz), CONCRETE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(26, 0.5, 38), CFrame.new(cx, baseY + 12.9, cz), WHITE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(27, 1.4, 39), CFrame.new(cx, baseY + 14.7, cz), Color3.fromRGB(40, 90, 200), Enum.Material.SmoothPlastic)
	decor(folder, Vector3.new(27, 0.7, 39), CFrame.new(cx, baseY + 13.6, cz), CYAN, Enum.Material.Neon)

	-- Multicolored panels on the west (front) wall: a grid of bright blocks.
	local panelColors = { RED, YELLOW, GREEN, PINK, ORANGE, CYAN }
	local idx = 0
	for row = 0, 2 do
		for col = 0, 5 do
			idx += 1
			decor(
				folder,
				Vector3.new(0.5, 3.6, 5.2),
				CFrame.new(cx - 12.2, baseY + 4 + row * 3.8, cz - 14.5 + col * 5.8),
				panelColors[((idx - 1) % #panelColors) + 1],
				Enum.Material.SmoothPlastic
			)
		end
	end
	-- Panels on the south wall too.
	for row = 0, 2 do
		for col = 0, 3 do
			idx += 1
			decor(
				folder,
				Vector3.new(5.2, 3.6, 0.5),
				CFrame.new(cx - 8 + col * 5.8, baseY + 4 + row * 3.8, cz + 18.2),
				panelColors[((idx - 1) % #panelColors) + 1],
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- Sign on the west face.
	makeSign(folder, Vector3.new(1, 5, 24), CFrame.new(cx - 12.4, baseY + 11.5, cz), BLACK, "Safe Zone", WHITE, Enum.NormalId.Left)

	-- Lit windows on the north wall + door on the west.
	windowRow(folder, Vector3.new(cx, 0, cz - 18), 3, 6, math.rad(180), baseY + 9)
	-- Door, human scale: 5.5 wide x 10 tall.
	decor(folder, Vector3.new(0.5, 10, 5.5), CFrame.new(cx - 12.3, baseY + 5, cz + 15), DARK_GRAY, Enum.Material.SmoothPlastic)
	-- Shield emblem: gold ball over the door.
	ball(folder, 3, Vector3.new(cx - 13, baseY + 11.5, cz + 15), YELLOW, Enum.Material.SmoothPlastic, false)
end

----------------------------------------------------------------------
-- Ferris wheel (north-west corner, slowly rotating)
----------------------------------------------------------------------

local function buildFerrisWheel(park: Instance): (Model, CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "FerrisWheel"
	folder.Parent = park

	local center = Vector3.new(-178, GROUND_Y + 27, -178)
	local radius = 22
	local yaw = math.rad(45) -- face the park center
	local baseCFrame = CFrame.new(center) * CFrame.Angles(0, yaw, 0)

	-- A-frame legs (solid, static) on concrete foot plinths.
	for _, side in ipairs({ -1, 1 }) do
		local footA = center + Vector3.new(math.cos(yaw) * 3 * side + math.sin(yaw) * 10, -27, -math.sin(yaw) * 3 * side + math.cos(yaw) * 10)
		local footB = center + Vector3.new(math.cos(yaw) * 3 * side - math.sin(yaw) * 10, -27, -math.sin(yaw) * 3 * side - math.cos(yaw) * 10)
		solid(folder, Vector3.new(3, 1.5, 3), CFrame.new(footA + Vector3.new(0, 0.75, 0)), CONCRETE, Enum.Material.SmoothPlastic)
		solid(folder, Vector3.new(3, 1.5, 3), CFrame.new(footB + Vector3.new(0, 0.75, 0)), CONCRETE, Enum.Material.SmoothPlastic)
		beamBetween(folder, footA, center + Vector3.new(math.cos(yaw) * 3 * side, 0, -math.sin(yaw) * 3 * side), 1.4, 1.4, DARK_GRAY, Enum.Material.SmoothPlastic, true)
		beamBetween(folder, footB, center + Vector3.new(math.cos(yaw) * 3 * side, 0, -math.sin(yaw) * 3 * side), 1.4, 1.4, DARK_GRAY, Enum.Material.SmoothPlastic, true)
	end
	-- Axle.
	local axle = cylinder(folder, 1.2, 9, center, GRAY, Enum.Material.SmoothPlastic, false)
	axle.CFrame = baseCFrame * CFrame.Angles(0, 0, math.rad(90))

	-- Rotating wheel model; hub is the PrimaryPart.
	local wheel = Instance.new("Model")
	wheel.Name = "Wheel"
	wheel.Parent = folder
	local hub = makePart(wheel, Vector3.new(2.5, 2.5, 2.5), baseCFrame, YELLOW, Enum.Material.Neon, false, false, false)
	hub.Shape = Enum.PartType.Ball
	wheel.PrimaryPart = hub

	-- Outer ring: 24 tangent segments.
	local segments = 24
	for i = 0, segments - 1 do
		local a0 = (i / segments) * math.pi * 2
		local a1 = ((i + 1) / segments) * math.pi * 2
		local p0 = baseCFrame:PointToWorldSpace(Vector3.new(math.cos(a0) * radius, math.sin(a0) * radius, 0))
		local p1 = baseCFrame:PointToWorldSpace(Vector3.new(math.cos(a1) * radius, math.sin(a1) * radius, 0))
		beamBetween(wheel, p0, p1, 1.1, 1.1, PURPLE, Enum.Material.SmoothPlastic, false)
		-- Inner ring segment (radius 13).
		local q0 = baseCFrame:PointToWorldSpace(Vector3.new(math.cos(a0) * 13, math.sin(a0) * 13, 0))
		local q1 = baseCFrame:PointToWorldSpace(Vector3.new(math.cos(a1) * 13, math.sin(a1) * 13, 0))
		beamBetween(wheel, q0, q1, 0.7, 0.7, CYAN, Enum.Material.SmoothPlastic, false)
	end
	-- Spokes every 3 segments.
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2
		local rim = baseCFrame:PointToWorldSpace(Vector3.new(math.cos(a) * radius, math.sin(a) * radius, 0))
		beamBetween(wheel, center, rim, 0.6, 0.6, WHITE, Enum.Material.SmoothPlastic, false)
	end
	-- 10 gondolas around the rim.
	local gondolaColors = { RED, YELLOW, GREEN, BLUE, PINK, ORANGE, CYAN, PURPLE, WHITE, RED }
	for i = 0, 9 do
		local a = (i / 10) * math.pi * 2
		local rimPos = baseCFrame:PointToWorldSpace(Vector3.new(math.cos(a) * radius, math.sin(a) * radius, 0))
		local gondolaPos = rimPos + Vector3.new(0, -2.6, 0)
		beamBetween(wheel, rimPos, gondolaPos + Vector3.new(0, 1.6, 0), 0.4, 0.4, DARK_GRAY, Enum.Material.SmoothPlastic, false)
		decor(wheel, Vector3.new(3.4, 3, 3.4), CFrame.new(gondolaPos) * CFrame.Angles(0, yaw, 0), gondolaColors[i + 1], Enum.Material.SmoothPlastic)
		decor(wheel, Vector3.new(3.9, 0.5, 3.9), CFrame.new(gondolaPos + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, yaw, 0), WHITE, Enum.Material.SmoothPlastic)
	end

	return wheel, baseCFrame
end

----------------------------------------------------------------------
-- Roller coaster along the north edge
----------------------------------------------------------------------

local function buildCoaster(park: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "RollerCoaster"
	folder.Parent = park

	-- Full circuit: a circular ring around the whole park, inside the
	-- perimeter wall and outside the path loop, clearing the ferris
	-- wheel (its rim stays ~229+ studs from the center).
	local ringRadius = 198
	local segments = 84
	local function trackPoint(i: number): Vector3
		local a = (i / segments) * math.pi * 2
		local y = GROUND_Y + 24 + 6 * math.sin(a * 3)
		return Vector3.new(math.cos(a) * ringRadius, y, math.sin(a) * ringRadius)
	end

	-- Pillars skip the four base footprints and the tent discs.
	local function pillarBlocked(x: number, z: number): boolean
		for _, bx in ipairs({ -150, 150 }) do
			for _, bz in ipairs({ -150, 150 }) do
				if math.abs(x - bx) < 20 and math.abs(z - bz) < 17 then
					return true
				end
			end
		end
		for _, tent in ipairs({ { -70, 185 }, { 75, 190 }, { -190, 30 } }) do
			local dx, dz = x - tent[1], z - tent[2]
			if dx * dx + dz * dz < 144 then
				return true
			end
		end
		return false
	end

	-- Track segments (twin rails) + support pillars every other point.
	for i = 0, segments - 1 do
		local p0 = trackPoint(i)
		local p1 = trackPoint(i + 1)
		local dir = (p1 - p0).Unit
		local perp = Vector3.new(-dir.Z, 0, dir.X) * 2.4
		beamBetween(folder, p0, p1, 2.2, 1, RED, Enum.Material.SmoothPlastic, false)
		beamBetween(folder, p0 + perp, p1 + perp, 0.7, 0.7, Color3.fromRGB(200, 40, 50), Enum.Material.SmoothPlastic, false)
		if i % 2 == 0 and not pillarBlocked(p0.X, p0.Z) then
			local base = p0 + perp * 0.5
			local h = p0.Y - GROUND_Y
			solid(folder, Vector3.new(3, 1.5, 3), CFrame.new(base.X, GROUND_Y + 0.75, base.Z), CONCRETE, Enum.Material.SmoothPlastic)
			solid(folder, Vector3.new(1.6, h, 1.6), CFrame.new(base.X, GROUND_Y + h / 2, base.Z), GRAY, Enum.Material.SmoothPlastic)
			decor(folder, Vector3.new(3.4, 0.8, 4), CFrame.new(base.X, p0.Y - 0.6, base.Z), DARK_GRAY, Enum.Material.SmoothPlastic)
		end
	end

	-- Loop-the-loop on the east side, standing in the tangent plane.
	local eastPoint = trackPoint(0)
	local loopCenter = Vector3.new(eastPoint.X, eastPoint.Y + 11, eastPoint.Z)
	local loopRadius = 12
	local loopSegments = 16
	for i = 0, loopSegments - 1 do
		local a0 = (i / loopSegments) * math.pi * 2
		local a1 = ((i + 1) / loopSegments) * math.pi * 2
		local p0 = loopCenter + Vector3.new(0, math.sin(a0) * loopRadius, math.cos(a0) * loopRadius)
		local p1 = loopCenter + Vector3.new(0, math.sin(a1) * loopRadius, math.cos(a1) * loopRadius)
		beamBetween(folder, p0, p1, 2.2, 1, RED, Enum.Material.SmoothPlastic, false)
	end
	solid(folder, Vector3.new(3, 1.5, 3), CFrame.new(eastPoint.X, GROUND_Y + 0.75, eastPoint.Z), CONCRETE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(1.6, 13, 1.6), CFrame.new(eastPoint.X, GROUND_Y + 6.5, eastPoint.Z), GRAY, Enum.Material.SmoothPlastic)

	-- A parked coaster car on the north hill.
	local carPoint = trackPoint(63)
	local carPos = carPoint + Vector3.new(0, 1.4, 0)
	decor(folder, Vector3.new(5, 1.6, 3), CFrame.new(carPos), YELLOW, Enum.Material.SmoothPlastic)
	decor(folder, Vector3.new(4.4, 1.2, 2.6), CFrame.new(carPos + Vector3.new(0, 1.3, 0)), BLUE, Enum.Material.SmoothPlastic)
end

----------------------------------------------------------------------
-- Carnival tents (striped cone roofs)
----------------------------------------------------------------------

local function buildTent(park: Instance, center: Vector3, colorA: Color3, colorB: Color3)
	local folder = Instance.new("Folder")
	folder.Name = "Tent"
	folder.Parent = park

	local cx, cz = center.X, center.Z
	-- Concrete plinth disc; the tent wall sits on top of it.
	cylinder(folder, 9, 1.5, Vector3.new(cx, GROUND_Y + 0.75, cz), CONCRETE, Enum.Material.SmoothPlastic, true)
	local wallTop = GROUND_Y + 7.5
	-- Cylindrical wall with a colored stripe ring.
	cylinder(folder, 8, 6, Vector3.new(cx, GROUND_Y + 4.5, cz), WHITE, Enum.Material.SmoothPlastic, true)
	cylinder(folder, 8.15, 1.2, Vector3.new(cx, GROUND_Y + 6.1, cz), colorA, Enum.Material.SmoothPlastic, false)
	-- Door opening (dark inset) + entrance mat on the grass.
	decor(folder, Vector3.new(3.4, 4.6, 0.5), CFrame.new(cx, GROUND_Y + 3.8, cz + 7.9), BLACK, Enum.Material.SmoothPlastic)
	decor(folder, Vector3.new(5, 0.25, 3), CFrame.new(cx, GROUND_Y + 0.15, cz + 10.2), colorA, Enum.Material.SmoothPlastic)

	-- Cone roof: 8 slats from rim to apex, alternating colors.
	local apex = Vector3.new(cx, wallTop + 7, cz)
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2
		local rim = Vector3.new(cx + math.cos(a) * 8.6, wallTop, cz + math.sin(a) * 8.6)
		local color = if i % 2 == 0 then colorA else colorB
		beamBetween(folder, rim, apex, 6.4, 0.5, color, Enum.Material.SmoothPlastic, false)
	end
	-- Apex ball, flag pole and flag.
	ball(folder, 1.6, apex + Vector3.new(0, 0.4, 0), YELLOW, Enum.Material.SmoothPlastic, false)
	solid(folder, Vector3.new(0.35, 4.5, 0.35), CFrame.new(cx, wallTop + 9, cz), DARK_GRAY, Enum.Material.SmoothPlastic)
	decor(folder, Vector3.new(3, 1.7, 0.25), CFrame.new(cx + 1.6, wallTop + 10.4, cz), colorA, Enum.Material.SmoothPlastic)
end

----------------------------------------------------------------------
-- Leaderboard board + DANGER signs
----------------------------------------------------------------------

local function buildLeaderboard(park: Instance): { TextLabel }
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboard"
	folder.Parent = park

	local cx, cz = 0, 84
	-- Concrete plinth slab + two posts + big dark board facing north.
	solid(folder, Vector3.new(24, 1.5, 3), CFrame.new(cx, GROUND_Y + 0.75, cz), CONCRETE, Enum.Material.SmoothPlastic)
	for _, sx in ipairs({ -1, 1 }) do
		solid(folder, Vector3.new(1.2, 12, 1.2), CFrame.new(cx + sx * 9, GROUND_Y + 7.5, cz), DARK_GRAY, Enum.Material.SmoothPlastic)
	end
	local board = decor(folder, Vector3.new(26, 15, 1), CFrame.new(cx, GROUND_Y + 13, cz), BLACK, Enum.Material.SmoothPlastic)
	decor(folder, Vector3.new(27, 0.8, 1.4), CFrame.new(cx, GROUND_Y + 20.8, cz), YELLOW, Enum.Material.Neon)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.22, 0)
	title.BackgroundTransparency = 1
	title.Text = "MOST BRAINROT STOLEN"
	title.TextColor3 = YELLOW
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = gui

	local rows: { TextLabel } = {}
	for i = 1, 4 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(0.92, 0, 0.17, 0)
		row.Position = UDim2.new(0.04, 0, 0.24 + (i - 1) * 0.18, 0)
		row.BackgroundTransparency = 1
		row.Text = i .. ". ---"
		row.TextColor3 = WHITE
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Parent = gui
		rows[i] = row
	end
	return rows
end

local function buildDangerSign(park: Instance, position: Vector3, faceYaw: number)
	local folder = Instance.new("Folder")
	folder.Name = "DangerSign"
	folder.Parent = park
	solid(folder, Vector3.new(1.6, 1.5, 1.6), CFrame.new(position + Vector3.new(0, 0.75, 0)), CONCRETE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(0.6, 4.4, 0.6), CFrame.new(position + Vector3.new(0, 3.7, 0)), DARK_GRAY, Enum.Material.SmoothPlastic)
	makeSign(
		folder,
		Vector3.new(5.5, 3, 0.5),
		CFrame.new(position + Vector3.new(0, 7.1, 0)) * CFrame.Angles(0, faceYaw, 0),
		YELLOW,
		"DANGER Zone",
		BLACK,
		Enum.NormalId.Front
	)
end

----------------------------------------------------------------------
-- Trees, pines, hot air balloons
----------------------------------------------------------------------

local function buildTree(park: Instance, position: Vector3, canopyColor: Color3, canopySize: number)
	local folder = Instance.new("Folder")
	folder.Name = "Tree"
	folder.Parent = park
	-- Round grass patch.
	cylinder(folder, canopySize * 0.75, 0.35, position + Vector3.new(0, 0.18, 0), Color3.fromRGB(90, 210, 110), Enum.Material.Grass, false)
	-- Trunk (solid) + big ball canopy (non-collidable).
	cylinder(folder, 0.7, 4.5, position + Vector3.new(0, 2.4, 0), BROWN, Enum.Material.Wood, true)
	ball(folder, canopySize, position + Vector3.new(0, 4.6 + canopySize / 2, 0), canopyColor, Enum.Material.SmoothPlastic, false)
	ball(folder, canopySize * 0.6, position + Vector3.new(canopySize * 0.32, 4.2 + canopySize / 2, canopySize * 0.2), canopyColor, Enum.Material.SmoothPlastic, false)
end

local function buildPine(park: Instance, position: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "Pine"
	folder.Parent = park
	cylinder(folder, 0.6, 3, position + Vector3.new(0, 1.5, 0), BROWN, Enum.Material.Wood, true)
	-- Three stacked cone tiers (slats from rim to apex, like the tents).
	local tiers = {
		{ radius = 4.2, baseY = 2.6, height = 4.5 },
		{ radius = 3.2, baseY = 5.6, height = 4 },
		{ radius = 2.1, baseY = 8.2, height = 3.6 },
	}
	for _, tier in ipairs(tiers) do
		local apex = position + Vector3.new(0, tier.baseY + tier.height, 0)
		for i = 0, 7 do
			local a = (i / 8) * math.pi * 2
			local rim = position + Vector3.new(math.cos(a) * tier.radius, tier.baseY, math.sin(a) * tier.radius)
			beamBetween(folder, rim, apex, tier.radius * 0.78, 0.4, PINE_GREEN, Enum.Material.SmoothPlastic, false)
		end
	end
	ball(folder, 1, position + Vector3.new(0, 12.1, 0), YELLOW, Enum.Material.Neon, false)
end

local function buildBalloon(park: Instance, position: Vector3, colorA: Color3, colorB: Color3): Model
	local model = Instance.new("Model")
	model.Name = "HotAirBalloon"
	model.Parent = park

	local envelope = ball(model, 9, position, colorA, Enum.Material.SmoothPlastic, false)
	model.PrimaryPart = envelope
	-- Colored band around the envelope.
	local band = makePart(model, Vector3.new(9.3, 2.6, 9.3), CFrame.new(position), colorB, Enum.Material.SmoothPlastic, false, false, false)
	band.Shape = Enum.PartType.Ball
	-- Ropes + basket.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			beamBetween(
				model,
				position + Vector3.new(sx * 2.6, -3.4, sz * 2.6),
				position + Vector3.new(sx * 1.3, -6.6, sz * 1.3),
				0.18,
				0.18,
				DARK_GRAY,
				Enum.Material.SmoothPlastic,
				false
			)
		end
	end
	decor(model, Vector3.new(3, 2.4, 3), CFrame.new(position + Vector3.new(0, -7.8, 0)), BROWN, Enum.Material.WoodPlanks)
	return model
end

----------------------------------------------------------------------
-- Perimeter wall, lamps, benches, crates, balloon bunches
----------------------------------------------------------------------

local function buildPerimeter(park: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Perimeter"
	folder.Parent = park

	local edge = 240
	local segLen = 12
	local colors = { RED, YELLOW, BLUE, WHITE }
	local idx = 0
	local function wallRun(from: Vector3, to: Vector3)
		local dir = (to - from).Unit
		local length = (to - from).Magnitude
		local yaw = math.atan2(-dir.Z, dir.X)
		local count = math.floor(length / segLen)
		for i = 0, count - 1 do
			idx += 1
			local center = from + dir * (segLen * (i + 0.5))
			solid(
				folder,
				Vector3.new(segLen, 6, 1.2),
				CFrame.new(center.X, GROUND_Y + 3, center.Z) * CFrame.Angles(0, yaw, 0),
				colors[((idx - 1) % #colors) + 1],
				Enum.Material.SmoothPlastic
			)
			-- White cap on each segment.
			decor(
				folder,
				Vector3.new(segLen, 0.6, 1.6),
				CFrame.new(center.X, GROUND_Y + 6.3, center.Z) * CFrame.Angles(0, yaw, 0),
				WHITE,
				Enum.Material.SmoothPlastic
			)
		end
	end
	wallRun(Vector3.new(-edge, 0, -edge), Vector3.new(edge, 0, -edge))
	wallRun(Vector3.new(edge, 0, -edge), Vector3.new(edge, 0, edge))
	wallRun(Vector3.new(edge, 0, edge), Vector3.new(-edge, 0, edge))
	wallRun(Vector3.new(-edge, 0, edge), Vector3.new(-edge, 0, -edge))
end

local function buildLamp(park: Instance, position: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "Lamp"
	folder.Parent = park
	-- Concrete base + 18-stud pole (human scale) + glowing head.
	solid(folder, Vector3.new(1.6, 1.5, 1.6), CFrame.new(position + Vector3.new(0, 0.75, 0)), CONCRETE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(0.9, 18, 0.9), CFrame.new(position + Vector3.new(0, 10.5, 0)), DARK_GRAY, Enum.Material.SmoothPlastic)
	ball(folder, 2, position + Vector3.new(0, 20.1, 0), LIT_WINDOW, Enum.Material.Neon, false)
	decor(folder, Vector3.new(2.4, 0.5, 2.4), CFrame.new(position + Vector3.new(0, 21.2, 0)), BLACK, Enum.Material.SmoothPlastic)
end

-- RGB night-market lamp: same post as buildLamp, but the bulb is a
-- bright neon ball whose color cycles in the Heartbeat loop. Every
-- other lamp (up to 12) also carries a real PointLight.
local RGB_PALETTE = { RED, GREEN, BLUE, PINK, CYAN, YELLOW, PURPLE, ORANGE }

local function buildRgbLamp(park: Instance, position: Vector3, index: number, withLight: boolean)
	local folder = Instance.new("Folder")
	folder.Name = "RgbLamp"
	folder.Parent = park
	local color = RGB_PALETTE[(index - 1) % #RGB_PALETTE + 1]
	solid(folder, Vector3.new(1.6, 1.5, 1.6), CFrame.new(position + Vector3.new(0, 0.75, 0)), CONCRETE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(0.9, 18, 0.9), CFrame.new(position + Vector3.new(0, 10.5, 0)), DARK_GRAY, Enum.Material.SmoothPlastic)
	local bulb = ball(folder, 2.2, position + Vector3.new(0, 20.1, 0), color, Enum.Material.Neon, false)
	decor(folder, Vector3.new(2.4, 0.5, 2.4), CFrame.new(position + Vector3.new(0, 21.2, 0)), BLACK, Enum.Material.SmoothPlastic)
	local light: PointLight? = nil
	if withLight then
		local pointLight = Instance.new("PointLight")
		pointLight.Range = 28
		pointLight.Brightness = 1.2
		pointLight.Color = color
		pointLight.Parent = bulb
		light = pointLight
	end
	table.insert(rgbBulbs, { bulb = bulb, light = light, phase = index * 0.13 })
end

-- Dense RGB lamp ring: plaza edge, path midpoints/edges, base gateways.
local function buildRgbLamps(park: Instance)
	local positions = {
		-- Plaza ring (just inside the path inner edge).
		{ -105, -105 }, { 105, -105 }, { -105, 105 }, { 105, 105 },
		{ 0, -108 }, { 0, 108 }, { -108, 0 }, { 108, 0 },
		-- Plaza inner diagonals.
		{ -70, -70 }, { 70, -70 }, { -70, 70 }, { 70, 70 },
		-- Path midpoints (just outside the path outer edge).
		{ 0, -138 }, { 0, 138 }, { -138, 0 }, { 138, 0 },
		-- Path edge pairs.
		{ -138, -100 }, { 138, -100 }, { -138, 100 }, { 138, 100 },
		{ -100, -138 }, { 100, -138 }, { -100, 138 }, { 100, 138 },
		-- Base gateways (grass strip between path and each base).
		{ -150, -132 }, { 150, -132 }, { -150, 132 }, { 150, 132 },
	}
	local lightCount = 0
	for i, pos in ipairs(positions) do
		local withLight = i % 2 == 1 and lightCount < 12
		if withLight then
			lightCount += 1
		end
		buildRgbLamp(park, Vector3.new(pos[1], GROUND_Y, pos[2]), i, withLight)
	end
end

-- Carousel (merry-go-round) on the east plaza edge: striped canopy,
-- cycling rim bulbs, eight bobbing horses. Returns the rotating
-- model, its hub CFrame, and the horse list for the Heartbeat loop.
local function buildCarousel(park: Instance): (Model, CFrame, { { model: Model, localCF: CFrame, phase: number } })
	local folder = Instance.new("Folder")
	folder.Name = "Carousel"
	folder.Parent = park

	local cx, cz = 82, 0
	local hubCF = CFrame.new(cx, GROUND_Y + 2, cz)

	-- Static plinth + fence ring.
	cylinder(folder, 15, 1.5, Vector3.new(cx, GROUND_Y + 0.75, cz), CONCRETE, Enum.Material.SmoothPlastic, true)
	local fenceTops: { Vector3 } = {}
	for i = 0, 11 do
		local a = (i / 12) * math.pi * 2
		local px, pz = cx + math.cos(a) * 16, cz + math.sin(a) * 16
		solid(folder, Vector3.new(0.5, 3, 0.5), CFrame.new(px, GROUND_Y + 1.5, pz), DARK_GRAY, Enum.Material.SmoothPlastic)
		fenceTops[i + 1] = Vector3.new(px, GROUND_Y + 2.8, pz)
	end
	for i = 1, 12 do
		beamBetween(folder, fenceTops[i], fenceTops[i % 12 + 1], 0.35, 0.35, YELLOW, Enum.Material.SmoothPlastic, false)
	end

	-- Rotating model; the hub ball is the PrimaryPart (spin axis).
	local carousel = Instance.new("Model")
	carousel.Name = "CarouselRide"
	carousel.Parent = folder
	local hub = makePart(carousel, Vector3.new(2.5, 2.5, 2.5), hubCF, YELLOW, Enum.Material.Neon, false, false, false)
	hub.Shape = Enum.PartType.Ball
	carousel.PrimaryPart = hub

	cylinder(carousel, 14, 1, Vector3.new(cx, GROUND_Y + 2.5, cz), Color3.fromRGB(255, 200, 220), Enum.Material.SmoothPlastic, true)
	cylinder(carousel, 2.5, 11, Vector3.new(cx, GROUND_Y + 8.5, cz), WHITE, Enum.Material.SmoothPlastic, false)
	cylinder(carousel, 3.2, 3, Vector3.new(cx, GROUND_Y + 6.5, cz), CYAN, Enum.Material.SmoothPlastic, false)
	cylinder(carousel, 3.3, 0.6, Vector3.new(cx, GROUND_Y + 8.2, cz), CYAN, Enum.Material.Neon, false)

	-- Striped cone canopy + finial.
	local apex = Vector3.new(cx, GROUND_Y + 19, cz)
	for i = 0, 9 do
		local a = (i / 10) * math.pi * 2
		local rim = Vector3.new(cx + math.cos(a) * 13.5, GROUND_Y + 13, cz + math.sin(a) * 13.5)
		local color = if i % 2 == 0 then RED else WHITE
		beamBetween(carousel, rim, apex, 8.6, 0.5, color, Enum.Material.SmoothPlastic, false)
	end
	cylinder(carousel, 0.25, 2.5, Vector3.new(cx, GROUND_Y + 20, cz), GRAY, Enum.Material.SmoothPlastic, false)
	ball(carousel, 1.4, Vector3.new(cx, GROUND_Y + 21.5, cz), YELLOW, Enum.Material.Neon, false)

	-- Rim bulbs join the RGB cycle.
	for i = 0, 15 do
		local a = (i / 16) * math.pi * 2
		local bulbPos = Vector3.new(cx + math.cos(a) * 13.5, GROUND_Y + 12.3, cz + math.sin(a) * 13.5)
		local bulb = ball(carousel, 1.2, bulbPos, RGB_PALETTE[i % #RGB_PALETTE + 1], Enum.Material.Neon, false)
		table.insert(rgbBulbs, { bulb = bulb, light = nil, phase = 2.5 + i * 0.39 })
	end

	-- Eight chunky horses on poles, facing the direction of travel.
	local horses: { { model: Model, localCF: CFrame, phase: number } } = {}
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2
		local hx, hz = cx + math.cos(a) * 9.5, cz + math.sin(a) * 9.5
		cylinder(carousel, 0.3, 9, Vector3.new(hx, GROUND_Y + 7.5, hz), GRAY, Enum.Material.SmoothPlastic, false)
		local horse = Instance.new("Model")
		horse.Name = "Horse"
		horse.Parent = carousel
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		local bodyPos = Vector3.new(hx, GROUND_Y + 6.5, hz)
		local bodyCF = CFrame.lookAt(bodyPos, bodyPos + tangent) * CFrame.Angles(0, math.pi / 2, 0)
		local bodyColor = RGB_PALETTE[i % #RGB_PALETTE + 1]
		local saddleColor = RGB_PALETTE[(i + 3) % #RGB_PALETTE + 1]
		local body = makePart(horse, Vector3.new(3.2, 1.6, 1.2), bodyCF, bodyColor, Enum.Material.SmoothPlastic, false, false, false)
		horse.PrimaryPart = body
		makePart(horse, Vector3.new(1.1, 1.5, 0.9), bodyCF * CFrame.new(1.8, 0.8, 0) * CFrame.Angles(0, 0, -0.25), bodyColor, Enum.Material.SmoothPlastic, false, false, false)
		makePart(horse, Vector3.new(0.7, 1.3, 0.5), bodyCF * CFrame.new(-1.8, 0.2, 0) * CFrame.Angles(0, 0, 0.3), saddleColor, Enum.Material.SmoothPlastic, false, false, false)
		makePart(horse, Vector3.new(1.4, 0.5, 1.5), bodyCF * CFrame.new(-0.1, 1.0, 0), saddleColor, Enum.Material.SmoothPlastic, false, false, false)
		makePart(horse, Vector3.new(0.5, 1.1, 0.5), bodyCF * CFrame.new(1.1, -1.2, 0), bodyColor, Enum.Material.SmoothPlastic, false, false, false)
		makePart(horse, Vector3.new(0.5, 1.1, 0.5), bodyCF * CFrame.new(-1.1, -1.2, 0), bodyColor, Enum.Material.SmoothPlastic, false, false, false)
		horses[i + 1] = { model = horse, localCF = hubCF:Inverse() * bodyCF, phase = i * 0.8 }
	end

	return carousel, hubCF, horses
end

-- Giant Tung Tung Sahur statue: wooden log character with a bat,
-- landmark just inside the north portal arch, facing the spawn.
local function buildTungTungStatue(park: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "TungTungStatue"
	folder.Parent = park

	local cx, cz = 0, -88
	local darkWood = Color3.fromRGB(90, 60, 35)
	local lightWood = Color3.fromRGB(210, 180, 130)

	-- Plinth + step + corner bulbs (join the RGB cycle).
	solid(folder, Vector3.new(10, 1.5, 10), CFrame.new(cx, GROUND_Y + 0.75, cz), CONCRETE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(8, 1, 8), CFrame.new(cx, GROUND_Y + 2, cz), CONCRETE, Enum.Material.SmoothPlastic)
	for i, corner in ipairs({ { -4.4, -4.4 }, { 4.4, -4.4 }, { -4.4, 4.4 }, { 4.4, 4.4 } }) do
		local bulb = ball(folder, 0.9, Vector3.new(cx + corner[1], GROUND_Y + 1.9, cz + corner[2]), RGB_PALETTE[i % #RGB_PALETTE + 1], Enum.Material.Neon, false)
		table.insert(rgbBulbs, { bulb = bulb, light = nil, phase = 5 + i * 0.5 })
	end

	-- Log body with darker rings and a cut-log top.
	cylinder(folder, 3.5, 18, Vector3.new(cx, GROUND_Y + 11.5, cz), BROWN, Enum.Material.Wood, true)
	for _, ringY in ipairs({ 6.5, 11.5, 16.5 }) do
		cylinder(folder, 3.6, 0.5, Vector3.new(cx, GROUND_Y + ringY, cz), darkWood, Enum.Material.Wood, false)
	end
	cylinder(folder, 3.4, 0.4, Vector3.new(cx, GROUND_Y + 20.6, cz), lightWood, Enum.Material.Wood, false)
	for _, knot in ipairs({ { -2.8, 9, 2 }, { 3, 13, -1.5 }, { -1.5, 18.5, -3 } }) do
		ball(folder, 0.6, Vector3.new(cx + knot[1], GROUND_Y + knot[2], cz + knot[3]), darkWood, Enum.Material.Wood, false)
	end

	-- Face on the front (+Z, toward spawn).
	ball(folder, 1.2, Vector3.new(cx - 1.3, GROUND_Y + 17.5, cz + 3.2), WHITE, Enum.Material.SmoothPlastic, false)
	ball(folder, 1.2, Vector3.new(cx + 1.3, GROUND_Y + 17.5, cz + 3.2), WHITE, Enum.Material.SmoothPlastic, false)
	ball(folder, 0.6, Vector3.new(cx - 1.3, GROUND_Y + 17.5, cz + 3.7), BLACK, Enum.Material.SmoothPlastic, false)
	ball(folder, 0.6, Vector3.new(cx + 1.3, GROUND_Y + 17.5, cz + 3.7), BLACK, Enum.Material.SmoothPlastic, false)
	ball(folder, 0.7, Vector3.new(cx, GROUND_Y + 16.6, cz + 3.6), darkWood, Enum.Material.Wood, false)
	decor(folder, Vector3.new(1.8, 0.6, 0.4), CFrame.new(cx, GROUND_Y + 15.8, cz + 3.45), BLACK, Enum.Material.SmoothPlastic)

	-- Stick arms angled down-out, ball hands, feet at the base.
	local handL = Vector3.new(cx - 6.5, GROUND_Y + 9.5, cz + 0.5)
	local handR = Vector3.new(cx + 6.5, GROUND_Y + 9.5, cz + 0.5)
	beamBetween(folder, Vector3.new(cx - 3.3, GROUND_Y + 14, cz), handL, 0.9, 0.9, BROWN, Enum.Material.Wood, false)
	beamBetween(folder, Vector3.new(cx + 3.3, GROUND_Y + 14, cz), handR, 0.9, 0.9, BROWN, Enum.Material.Wood, false)
	ball(folder, 1.1, handL, BROWN, Enum.Material.Wood, false)
	ball(folder, 1.1, handR, BROWN, Enum.Material.Wood, false)
	solid(folder, Vector3.new(1.8, 1, 2.6), CFrame.new(cx - 1.7, GROUND_Y + 3, cz + 0.8), darkWood, Enum.Material.Wood)
	solid(folder, Vector3.new(1.8, 1, 2.6), CFrame.new(cx + 1.7, GROUND_Y + 3, cz + 0.8), darkWood, Enum.Material.Wood)

	-- Baseball bat in the right hand (handle + barrel).
	local batDir = Vector3.new(0.45, 1, 0.15).Unit
	beamBetween(folder, handR, handR + batDir * 2.5, 0.7, 0.7, lightWood, Enum.Material.Wood, false)
	beamBetween(folder, handR + batDir * 2.5, handR + batDir * 7.5, 1.5, 1.5, lightWood, Enum.Material.Wood, false)

	-- Small drum beside the plinth, with two sticks resting on top.
	cylinder(folder, 2, 2.5, Vector3.new(cx + 7.5, GROUND_Y + 1.55, cz + 3), BROWN, Enum.Material.Wood, true)
	cylinder(folder, 2, 0.3, Vector3.new(cx + 7.5, GROUND_Y + 2.9, cz + 3), WHITE, Enum.Material.SmoothPlastic, false)
	beamBetween(folder, Vector3.new(cx + 6.8, GROUND_Y + 3.2, cz + 2.2), Vector3.new(cx + 7.4, GROUND_Y + 3.05, cz + 3.2), 0.25, 0.25, lightWood, Enum.Material.Wood, false)
	beamBetween(folder, Vector3.new(cx + 8.2, GROUND_Y + 3.2, cz + 2.2), Vector3.new(cx + 7.6, GROUND_Y + 3.05, cz + 3.2), 0.25, 0.25, lightWood, Enum.Material.Wood, false)

	-- Name sign on the plinth front.
	makeSign(folder, Vector3.new(8, 2, 0.5), CFrame.new(cx, GROUND_Y + 1.6, cz + 5.3), BLACK, "TUNG TUNG SAHUR", WHITE, Enum.NormalId.Back)
end

-- Chair swing ride (chair-o-plane) on the NW plaza quadrant: center
-- pole + rotating disc with eight hanging chairs on chains, tilted
-- outward like centrifugal force. Rim bulbs join the RGB cycle.
-- Returns the rotating model + hub CFrame for the Heartbeat loop.
local function buildChairSwing(park: Instance): (Model, CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "ChairSwing"
	folder.Parent = park

	local cx, cz = -52, -52
	local hubCF = CFrame.new(cx, GROUND_Y + 16, cz)

	-- Static plinth + center pole + fence ring.
	cylinder(folder, 18, 1.5, Vector3.new(cx, GROUND_Y + 0.75, cz), CONCRETE, Enum.Material.SmoothPlastic, true)
	cylinder(folder, 1.2, 16, Vector3.new(cx, GROUND_Y + 8.75, cz), DARK_GRAY, Enum.Material.SmoothPlastic, true)
	cylinder(folder, 2.2, 1.2, Vector3.new(cx, GROUND_Y + 3.2, cz), RED, Enum.Material.SmoothPlastic, false)
	local fenceTops: { Vector3 } = {}
	for i = 0, 15 do
		local a = (i / 16) * math.pi * 2
		local px, pz = cx + math.cos(a) * 19, cz + math.sin(a) * 19
		solid(folder, Vector3.new(0.5, 3, 0.5), CFrame.new(px, GROUND_Y + 1.5, pz), DARK_GRAY, Enum.Material.SmoothPlastic)
		fenceTops[i + 1] = Vector3.new(px, GROUND_Y + 2.8, pz)
	end
	for i = 1, 16 do
		beamBetween(folder, fenceTops[i], fenceTops[i % 16 + 1], 0.35, 0.35, CYAN, Enum.Material.SmoothPlastic, false)
	end

	-- Rotating model; the hub ball is the PrimaryPart (spin axis).
	local ride = Instance.new("Model")
	ride.Name = "ChairSwingRide"
	ride.Parent = folder
	local hub = makePart(ride, Vector3.new(2.5, 2.5, 2.5), hubCF, YELLOW, Enum.Material.Neon, false, false, false)
	hub.Shape = Enum.PartType.Ball
	ride.PrimaryPart = hub

	-- Top disc + striped cone cap + finial.
	cylinder(ride, 13, 1, Vector3.new(cx, GROUND_Y + 16, cz), PURPLE, Enum.Material.SmoothPlastic, false)
	cylinder(ride, 13.4, 0.5, Vector3.new(cx, GROUND_Y + 15.4, cz), CYAN, Enum.Material.Neon, false)
	local apex = Vector3.new(cx, GROUND_Y + 21.5, cz)
	for i = 0, 9 do
		local a = (i / 10) * math.pi * 2
		local rim = Vector3.new(cx + math.cos(a) * 12.5, GROUND_Y + 16.6, cz + math.sin(a) * 12.5)
		local color = if i % 2 == 0 then PINK else WHITE
		beamBetween(ride, rim, apex, 8, 0.5, color, Enum.Material.SmoothPlastic, false)
	end
	ball(ride, 1.6, Vector3.new(cx, GROUND_Y + 22.5, cz), YELLOW, Enum.Material.Neon, false)

	-- Rim bulbs join the RGB cycle.
	for i = 0, 15 do
		local a = (i / 16) * math.pi * 2
		local bulbPos = Vector3.new(cx + math.cos(a) * 13.2, GROUND_Y + 15.2, cz + math.sin(a) * 13.2)
		local bulb = ball(ride, 1.2, bulbPos, RGB_PALETTE[i % #RGB_PALETTE + 1], Enum.Material.Neon, false)
		table.insert(rgbBulbs, { bulb = bulb, light = nil, phase = 7.5 + i * 0.39 })
	end

	-- Eight chairs hanging from the disc edge on chains, tilted
	-- outward. Chains + chair are rigid parts of the rotating model.
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local anchor = Vector3.new(cx, GROUND_Y + 15.5, cz) + out * 12
		local seatPos = Vector3.new(cx, GROUND_Y + 6, cz) + out * 15.5
		local seatColor = RGB_PALETTE[i % #RGB_PALETTE + 1]
		beamBetween(ride, anchor, seatPos + Vector3.new(0, 1.6, 0), 0.22, 0.22, GRAY, Enum.Material.SmoothPlastic, false)
		local seatCF = CFrame.lookAt(seatPos, seatPos + out) * CFrame.Angles(-0.35, 0, 0)
		makePart(ride, Vector3.new(2.2, 0.4, 2), seatCF, seatColor, Enum.Material.SmoothPlastic, false, false, false)
		makePart(ride, Vector3.new(2.2, 2.2, 0.4), seatCF * CFrame.new(0, 1.1, 1), seatColor, Enum.Material.SmoothPlastic, false, false, false)
		makePart(ride, Vector3.new(0.35, 1.8, 0.35), seatCF * CFrame.new(-1, 0.9, -0.6), GRAY, Enum.Material.SmoothPlastic, false, false, false)
		makePart(ride, Vector3.new(0.35, 1.8, 0.35), seatCF * CFrame.new(1, 0.9, -0.6), GRAY, Enum.Material.SmoothPlastic, false, false, false)
	end

	return ride, hubCF
end

-- Bumper cars arena on the NE plaza quadrant: low-walled rectangle
-- with six chunky cars, striped canopy on four posts, edge bulbs in
-- the RGB cycle. Decorative only.
local function buildBumperCars(park: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "BumperCars"
	folder.Parent = park

	local cx, cz = 52, -52
	local halfX, halfZ = 18, 13

	-- Plinth + arena floor.
	solid(folder, Vector3.new(halfX * 2 + 3, 1.5, halfZ * 2 + 3), CFrame.new(cx, GROUND_Y + 0.75, cz), CONCRETE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(halfX * 2, 0.6, halfZ * 2), CFrame.new(cx, GROUND_Y + 1.8, cz), Color3.fromRGB(45, 50, 70), Enum.Material.SmoothPlastic)

	-- Low walls with a gap on the south side as the entrance.
	local wallY = GROUND_Y + 3.1
	solid(folder, Vector3.new(halfX * 2 + 1, 2, 1), CFrame.new(cx, wallY, cz - halfZ - 0.5), RED, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(1, 2, halfZ * 2 + 1), CFrame.new(cx - halfX - 0.5, wallY, cz), BLUE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(1, 2, halfZ * 2 + 1), CFrame.new(cx + halfX + 0.5, wallY, cz), BLUE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(13, 2, 1), CFrame.new(cx - 11.5, wallY, cz + halfZ + 0.5), RED, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(13, 2, 1), CFrame.new(cx + 11.5, wallY, cz + halfZ + 0.5), RED, Enum.Material.SmoothPlastic)

	-- Six bumper cars: chunky body, bumper ring, seat, power pole.
	local carSpots = {
		{ -11, -6, 0.4 }, { 0, -7, 2.2 }, { 11, -5, 1.1 },
		{ -9, 6, 2.8 }, { 3, 7, 0.2 }, { 12, 5, 1.9 },
	}
	for i, spot in ipairs(carSpots) do
		local carCF = CFrame.new(cx + spot[1], GROUND_Y + 3.1, cz + spot[2]) * CFrame.Angles(0, spot[3], 0)
		local carColor = RGB_PALETTE[(i - 1) % #RGB_PALETTE + 1]
		makePart(folder, Vector3.new(4.4, 1.4, 2.8), carCF, carColor, Enum.Material.SmoothPlastic, true, false, false)
		makePart(folder, Vector3.new(4.8, 0.7, 3.2), carCF * CFrame.new(0, -0.45, 0), BLACK, Enum.Material.SmoothPlastic, true, false, false)
		makePart(folder, Vector3.new(2, 1, 1.8), carCF * CFrame.new(-0.4, 1.1, 0), WHITE, Enum.Material.SmoothPlastic, false, false, false)
		makePart(folder, Vector3.new(1, 0.8, 1.6), carCF * CFrame.new(-1.3, 1.6, 0), carColor, Enum.Material.SmoothPlastic, false, false, false)
		makePart(folder, Vector3.new(0.25, 5, 0.25), carCF * CFrame.new(-1.8, 3.4, 0) * CFrame.Angles(0, 0, 0.35), GRAY, Enum.Material.SmoothPlastic, false, false, false)
	end

	-- Striped canopy roof on four corner posts + edge bulbs.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			solid(folder, Vector3.new(1.2, 13, 1.2), CFrame.new(cx + sx * (halfX + 1), GROUND_Y + 6.5, cz + sz * (halfZ + 1)), DARK_GRAY, Enum.Material.SmoothPlastic)
		end
	end
	local roofY = GROUND_Y + 13.5
	for i = 0, 7 do
		local stripX = cx - halfX - 2 + (i + 0.5) * ((halfX * 2 + 4) / 8)
		local color = if i % 2 == 0 then YELLOW else RED
		decor(folder, Vector3.new((halfX * 2 + 4) / 8, 0.6, halfZ * 2 + 4), CFrame.new(stripX, roofY, cz), color, Enum.Material.SmoothPlastic)
	end
	local bulbIndex = 0
	for _, sz in ipairs({ -1, 1 }) do
		for i = 0, 9 do
			bulbIndex += 1
			local bx = cx - halfX - 2 + (i / 9) * (halfX * 2 + 4)
			local bulb = ball(folder, 1.1, Vector3.new(bx, roofY - 0.8, cz + sz * (halfZ + 2)), RGB_PALETTE[bulbIndex % #RGB_PALETTE + 1], Enum.Material.Neon, false)
			table.insert(rgbBulbs, { bulb = bulb, light = nil, phase = 12 + bulbIndex * 0.31 })
		end
	end

	makeSign(folder, Vector3.new(16, 3, 0.5), CFrame.new(cx, GROUND_Y + 11, cz + halfZ + 2.4), BLACK, "BUMPER CARS", WHITE, Enum.NormalId.Back)
end

-- Drop tower on the SW plaza quadrant: tall lattice tower with a
-- passenger gondola ring that slowly rises and drops (sine motion
-- in the Heartbeat loop). Vertical bulb strip joins the RGB cycle.
-- Returns the gondola model, its base CFrame, and the travel height.
local function buildDropTower(park: Instance): (Model, CFrame, number)
	local folder = Instance.new("Folder")
	folder.Name = "DropTower"
	folder.Parent = park

	local cx, cz = -52, 52
	local towerTop = GROUND_Y + 55
	local travel = 38

	-- Plinth + tower shaft + cross braces.
	solid(folder, Vector3.new(14, 1.5, 14), CFrame.new(cx, GROUND_Y + 0.75, cz), CONCRETE, Enum.Material.SmoothPlastic)
	solid(folder, Vector3.new(3.5, 55, 3.5), CFrame.new(cx, GROUND_Y + 28.25, cz), Color3.fromRGB(70, 90, 160), Enum.Material.SmoothPlastic)
	for i = 1, 6 do
		local braceY = GROUND_Y + 6 + i * 7.5
		decor(folder, Vector3.new(5.4, 0.8, 5.4), CFrame.new(cx, braceY, cz), CYAN, Enum.Material.Neon)
	end
	-- Crown + beacon.
	solid(folder, Vector3.new(7, 2, 7), CFrame.new(cx, towerTop + 1, cz), RED, Enum.Material.SmoothPlastic)
	ball(folder, 2, Vector3.new(cx, towerTop + 3.2, cz), YELLOW, Enum.Material.Neon, false)

	-- Vertical RGB bulb strip up the front face.
	for i = 0, 9 do
		local bulbY = GROUND_Y + 8 + i * 4.6
		local bulb = ball(folder, 1.1, Vector3.new(cx, bulbY, cz + 2.2), RGB_PALETTE[i % #RGB_PALETTE + 1], Enum.Material.Neon, false)
		table.insert(rgbBulbs, { bulb = bulb, light = nil, phase = 18 + i * 0.45 })
	end

	-- Fence ring around the base.
	local fenceTops: { Vector3 } = {}
	for i = 0, 11 do
		local a = (i / 12) * math.pi * 2
		local px, pz = cx + math.cos(a) * 10, cz + math.sin(a) * 10
		solid(folder, Vector3.new(0.5, 3, 0.5), CFrame.new(px, GROUND_Y + 1.5, pz), DARK_GRAY, Enum.Material.SmoothPlastic)
		fenceTops[i + 1] = Vector3.new(px, GROUND_Y + 2.8, pz)
	end
	for i = 1, 12 do
		beamBetween(folder, fenceTops[i], fenceTops[i % 12 + 1], 0.35, 0.35, ORANGE, Enum.Material.SmoothPlastic, false)
	end

	-- Gondola: seat ring around the shaft, rides up/down the tower.
	local gondola = Instance.new("Model")
	gondola.Name = "DropGondola"
	gondola.Parent = folder
	local gondolaBase = CFrame.new(cx, GROUND_Y + 5, cz)
	local hub = makePart(gondola, Vector3.new(2, 2, 2), gondolaBase, YELLOW, Enum.Material.Neon, false, false, false)
	hub.Shape = Enum.PartType.Ball
	gondola.PrimaryPart = hub
	cylinder(gondola, 5.5, 1, Vector3.new(cx, GROUND_Y + 4.2, cz), RED, Enum.Material.SmoothPlastic, false)
	cylinder(gondola, 5.8, 0.5, Vector3.new(cx, GROUND_Y + 7.6, cz), CYAN, Enum.Material.Neon, false)
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local seatPos = Vector3.new(cx, GROUND_Y + 5.6, cz) + out * 4.6
		local seatCF = CFrame.lookAt(seatPos, seatPos + out)
		local seatColor = RGB_PALETTE[i % #RGB_PALETTE + 1]
		makePart(gondola, Vector3.new(1.8, 2.4, 0.8), seatCF, seatColor, Enum.Material.SmoothPlastic, false, false, false)
		makePart(gondola, Vector3.new(1.8, 0.4, 1.4), seatCF * CFrame.new(0, -0.9, 0.4), seatColor, Enum.Material.SmoothPlastic, false, false, false)
		beamBetween(gondola, seatPos + Vector3.new(0, 2, 0), Vector3.new(cx, GROUND_Y + 7.6, cz) + out * 2.6, 0.3, 0.3, GRAY, Enum.Material.SmoothPlastic, false)
	end

	makeSign(folder, Vector3.new(12, 2.6, 0.5), CFrame.new(cx, GROUND_Y + 9, cz + 7.4), BLACK, "DROP TOWER", WHITE, Enum.NormalId.Back)

	return gondola, gondolaBase, travel
end

local function buildBench(park: Instance, position: Vector3, yaw: number)
	local folder = Instance.new("Folder")
	folder.Name = "Bench"
	folder.Parent = park
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	solid(folder, Vector3.new(5, 0.5, 1.6), cf * CFrame.new(0, 1.2, 0), BROWN, Enum.Material.WoodPlanks)
	solid(folder, Vector3.new(5, 1.6, 0.4), cf * CFrame.new(0, 2.2, -0.7), BROWN, Enum.Material.WoodPlanks)
	for _, sx in ipairs({ -1, 1 }) do
		solid(folder, Vector3.new(0.5, 1.2, 1.4), cf * CFrame.new(sx * 2, 0.6, 0), DARK_GRAY, Enum.Material.SmoothPlastic)
	end
end

local function buildCrateStack(park: Instance, position: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "Crates"
	folder.Parent = park
	local colors = { BROWN, Color3.fromRGB(160, 115, 70), Color3.fromRGB(100, 70, 45) }
	for i = 0, 3 do
		local px = position.X + (i % 2) * 3.2
		local py = GROUND_Y + 1.5 + math.floor(i / 2) * 3
		solid(folder, Vector3.new(3, 3, 3), CFrame.new(px, py, position.Z), colors[(i % 3) + 1], Enum.Material.WoodPlanks)
	end
	solid(folder, Vector3.new(2.4, 2.4, 2.4), CFrame.new(position.X + 1.6, GROUND_Y + 7.2, position.Z), colors[2], Enum.Material.WoodPlanks)
end

local function buildBalloonBunch(park: Instance, position: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "BalloonBunch"
	folder.Parent = park
	local colors = { RED, PINK, CYAN, YELLOW, PURPLE }
	for i = 1, 5 do
		local offset = Vector3.new((i - 3) * 0.9, 3.6 + (i % 2) * 0.7, ((i * 7) % 3 - 1) * 0.8)
		ball(folder, 1.6, position + offset, colors[i], Enum.Material.SmoothPlastic, false)
		beamBetween(folder, position + Vector3.new(0, 0.4, 0), position + offset - Vector3.new(0, 0.8, 0), 0.08, 0.08, WHITE, Enum.Material.SmoothPlastic, false)
	end
	solid(folder, Vector3.new(0.8, 0.8, 0.8), CFrame.new(position + Vector3.new(0, 0.4, 0)), DARK_GRAY, Enum.Material.SmoothPlastic)
end

----------------------------------------------------------------------
-- Prop clusters (density audit: fill sparse 50x50 chunks)
----------------------------------------------------------------------

local function buildPropCluster(park: Instance, position: Vector3, yaw: number)
	local folder = Instance.new("Folder")
	folder.Name = "PropCluster"
	folder.Parent = park
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	-- Planter: concrete box + round bush balls.
	solid(folder, Vector3.new(6, 1.5, 3), cf * CFrame.new(0, 0.75, 0), CONCRETE, Enum.Material.SmoothPlastic)
	ball(folder, 3.4, (cf * CFrame.new(-1.6, 2.6, 0)).Position, LEAF_GREEN, Enum.Material.SmoothPlastic, false)
	ball(folder, 2.8, (cf * CFrame.new(1.4, 2.4, 0.3)).Position, LEAF_PINK, Enum.Material.SmoothPlastic, false)
	ball(folder, 2.2, (cf * CFrame.new(0, 3, -0.4)).Position, LEAF_GREEN, Enum.Material.SmoothPlastic, false)
	-- Bench facing the planter + crates + lamp + balloon bunch nearby.
	buildBench(folder, (cf * CFrame.new(0, 0, 5)).Position, yaw + math.pi)
	buildCrateStack(folder, (cf * CFrame.new(5.5, 0, -1)).Position)
	buildLamp(folder, (cf * CFrame.new(-5.5, 0, 2)).Position)
	buildBalloonBunch(folder, (cf * CFrame.new(4, 0, 4.5)).Position)
end

----------------------------------------------------------------------
-- Lighting (golden hour, Future technology)
----------------------------------------------------------------------

local function applyLighting()
	-- NOTE: Lighting.Technology is set in default.project.json; it is not
	-- settable from a script at runtime, so it must not be assigned here.
	Lighting.ClockTime = 19.5
	Lighting.Brightness = 2.1
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.Ambient = Color3.fromRGB(95, 95, 115)
	Lighting.OutdoorAmbient = Color3.fromRGB(125, 120, 140)
	Lighting.FogEnd = 1200

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 0.85
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.15
	cc.Saturation = 0.2
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.1
	rays.Spread = 0.6
	rays.Parent = Lighting
end

----------------------------------------------------------------------
-- Resilience helpers: every build section runs under pcall so one
-- failure can never empty the whole park. Fallbacks keep the world
-- interface contract intact for the services that read it.
----------------------------------------------------------------------

-- Run one build section under pcall; warn and continue on failure.
local function safeBuild(name: string, fn: (...any) -> ...any, ...: any)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("MapBuilder: " .. name .. " failed: " .. tostring(err))
	end
end

-- Force an existing Baseplate to the transform the park assumes
-- (top exactly at GROUND_Y), wherever Studio or the user left it.
local function forceBaseplate(baseplate: Instance)
	local part = baseplate :: BasePart
	part.Size = Vector3.new(512, 2, 512)
	part.CFrame = CFrame.new(0, GROUND_Y - 1, 0)
	part.Anchored = true
	part.CanCollide = true
end

-- Minimal waypoint loop (4 corners + side midpoints at path height),
-- used if buildPath fails so the spawner still has a closed loop.
local function fallbackWaypoints(): { Vector3 }
	return {
		Vector3.new(-PATH_HALF, PATH_TOP_Y, -PATH_HALF),
		Vector3.new(0, PATH_TOP_Y, -PATH_HALF),
		Vector3.new(PATH_HALF, PATH_TOP_Y, -PATH_HALF),
		Vector3.new(PATH_HALF, PATH_TOP_Y, 0),
		Vector3.new(PATH_HALF, PATH_TOP_Y, PATH_HALF),
		Vector3.new(0, PATH_TOP_Y, PATH_HALF),
		Vector3.new(-PATH_HALF, PATH_TOP_Y, PATH_HALF),
		Vector3.new(-PATH_HALF, PATH_TOP_Y, 0),
	}
end

-- Minimal placeholder base with the full interface contract, used if
-- buildBase fails so BaseService never sees a nil base.
local function fallbackBase(park: Instance, center: Vector3, baseColor: Color3): any
	local folder = Instance.new("Folder")
	folder.Name = "BaseFallback"
	folder.Parent = park

	local placeZone = Instance.new("Part")
	placeZone.Name = "PlaceZone"
	placeZone.Size = Vector3.new(32, 1, 26)
	placeZone.CFrame = CFrame.new(center.X, GROUND_Y + 0.5, center.Z)
	placeZone.Color = baseColor
	placeZone.Material = Enum.Material.SmoothPlastic
	placeZone.Anchored = true
	placeZone.CanCollide = true
	placeZone.CanTouch = true
	placeZone.CanQuery = true
	placeZone.Parent = folder

	local pedestals: { Part } = {}
	local rims: { Part } = {}
	for i = 1, 8 do
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)
		local px = center.X - 12 + col * 8
		local pz = center.Z - 6 + row * 12
		local pedestal = Instance.new("Part")
		pedestal.Name = "Pedestal_" .. i
		pedestal.Size = Vector3.new(3, 1, 3)
		pedestal.CFrame = CFrame.new(px, GROUND_Y + 1.5, pz)
		pedestal.Color = WHITE
		pedestal.Material = Enum.Material.SmoothPlastic
		pedestal.Anchored = true
		pedestal.CanCollide = true
		pedestal.CanTouch = true
		pedestal.CanQuery = true
		pedestal.Parent = folder
		pedestals[i] = pedestal
		local rim = Instance.new("Part")
		rim.Name = "PedestalRim_" .. i
		rim.Size = Vector3.new(3.4, 0.3, 3.4)
		rim.CFrame = CFrame.new(px, GROUND_Y + 2.15, pz)
		rim.Color = RIM_IDLE
		rim.Material = Enum.Material.SmoothPlastic
		rim.Anchored = true
		rim.CanCollide = false
		rim.CanTouch = false
		rim.CanQuery = false
		rim.Parent = folder
		rims[i] = rim
	end

	local sign = Instance.new("Part")
	sign.Name = "BaseSign"
	sign.Size = Vector3.new(8, 3, 0.5)
	sign.CFrame = CFrame.new(center.X, GROUND_Y + 6, center.Z - 13)
	sign.Color = baseColor
	sign.Material = Enum.Material.SmoothPlastic
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanTouch = false
	sign.CanQuery = false
	sign.Parent = folder

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "BASE"
	signLabel.TextColor3 = WHITE
	signLabel.Font = Enum.Font.GothamBold
	signLabel.TextScaled = true
	signLabel.Parent = gui

	return {
		Center = Vector3.new(center.X, GROUND_Y + 1, center.Z),
		PlaceZone = placeZone,
		Pedestals = pedestals,
		Rims = rims,
		SignLabel = signLabel,
	}
end

-- Dummy leaderboard rows on a hidden part, used if buildLeaderboard
-- fails so the progress service still has labels to write to.
local function fallbackLeaderboardRows(park: Instance): { TextLabel }
	local holder = Instance.new("Part")
	holder.Name = "LeaderboardFallback"
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(0, GROUND_Y - 10, 0)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.Parent = park

	local gui = Instance.new("SurfaceGui")
	gui.Parent = holder

	local rows: { TextLabel } = {}
	for i = 1, 4 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(1, 0.25)
		row.Position = UDim2.fromScale(0, (i - 1) * 0.25)
		row.BackgroundTransparency = 1
		row.Text = i .. ". ---"
		row.Parent = gui
		rows[i] = row
	end
	return rows
end

----------------------------------------------------------------------
-- Init: build the whole park, return the world table
----------------------------------------------------------------------

function MapBuilder.Init()
	safeBuild("applyLighting", applyLighting)

	local park = Instance.new("Folder")
	park.Name = "Park"
	park.Parent = Workspace

	-- Ground: the park is built for a Baseplate whose top sits at
	-- GROUND_Y. If the place already has one, force it to that
	-- transform (Studio or the user may have left it elsewhere);
	-- if not, lay one (top at GROUND_Y).
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		safeBuild("forceBaseplate", forceBaseplate, baseplate)
	else
		local ground = Instance.new("Part")
		ground.Name = "Baseplate"
		ground.Size = Vector3.new(512, 2, 512)
		ground.CFrame = CFrame.new(0, GROUND_Y - 1, 0)
		ground.Color = Color3.fromRGB(95, 200, 105)
		ground.Material = Enum.Material.Grass
		ground.Anchored = true
		ground.CanCollide = true
		ground.Parent = Workspace
		partCount += 1
	end

	-- Core layout. Each section is pcall-wrapped: a failure warns and
	-- the build continues, so the park can never come up empty.
	local waypoints: { Vector3 }
	local pathOk, pathResult = pcall(buildPath, park)
	if pathOk and pathResult then
		waypoints = pathResult
	else
		warn("MapBuilder: buildPath failed (" .. tostring(pathResult) .. "); using fallback waypoint loop")
		waypoints = fallbackWaypoints()
	end
	safeBuild("buildPlaza", buildPlaza, park)
	safeBuild("buildArch", buildArch, park)
	safeBuild("buildSpawnPlaza", buildSpawnPlaza, park)

	-- Four player bases, one per quadrant, gateways facing the path.
	local bases = {}
	local baseSpecs = {
		{ center = Vector3.new(-150, GROUND_Y, -150), color = BLUE, gatewaySign = 1 },
		{ center = Vector3.new(150, GROUND_Y, -150), color = RED, gatewaySign = 1 },
		{ center = Vector3.new(-150, GROUND_Y, 150), color = GREEN, gatewaySign = -1 },
		{ center = Vector3.new(150, GROUND_Y, 150), color = PURPLE, gatewaySign = -1 },
	}
	for i, spec in ipairs(baseSpecs) do
		local baseOk, baseResult = pcall(buildBase, park, spec.center, spec.color, spec.gatewaySign)
		if baseOk and baseResult then
			bases[i] = baseResult
		else
			warn("MapBuilder: buildBase " .. i .. " failed (" .. tostring(baseResult) .. "); using fallback base")
			bases[i] = fallbackBase(park, spec.center, spec.color)
		end
	end

	-- Buildings + attractions.
	safeBuild("buildWarehouse", buildWarehouse, park)
	safeBuild("buildShop", buildShop, park)
	safeBuild("buildSafeZone", buildSafeZone, park)
	local wheel: Model? = nil
	local wheelBase: CFrame? = nil
	local wheelOk, wheelModel, wheelCf = pcall(buildFerrisWheel, park)
	if wheelOk then
		wheel, wheelBase = wheelModel, wheelCf
	else
		warn("MapBuilder: buildFerrisWheel failed (" .. tostring(wheelModel) .. ")")
	end
	safeBuild("buildCoaster", buildCoaster, park)

	local carousel: Model? = nil
	local carouselBase: CFrame? = nil
	local carouselHorses: { { model: Model, localCF: CFrame, phase: number } }? = nil
	local carouselOk, carouselModel, carouselCf, carouselHorseList = pcall(buildCarousel, park)
	if carouselOk then
		carousel, carouselBase, carouselHorses = carouselModel, carouselCf, carouselHorseList
	else
		warn("MapBuilder: buildCarousel failed (" .. tostring(carouselModel) .. ")")
	end

	-- Center-plaza night-market rides (quadrants; center stays clear).
	local swingRide: Model? = nil
	local swingBase: CFrame? = nil
	local swingOk, swingModel, swingCf = pcall(buildChairSwing, park)
	if swingOk then
		swingRide, swingBase = swingModel, swingCf
	else
		warn("MapBuilder: buildChairSwing failed (" .. tostring(swingModel) .. ")")
	end
	safeBuild("buildBumperCars", buildBumperCars, park)
	local dropGondola: Model? = nil
	local dropBase: CFrame? = nil
	local dropTravel = 0
	local dropOk, dropModel, dropCf, dropLift = pcall(buildDropTower, park)
	if dropOk then
		dropGondola, dropBase, dropTravel = dropModel, dropCf, dropLift
	else
		warn("MapBuilder: buildDropTower failed (" .. tostring(dropModel) .. ")")
	end
	safeBuild("buildTungTungStatue", buildTungTungStatue, park)
	safeBuild("buildTent", buildTent, park, Vector3.new(-70, GROUND_Y, 185), RED, WHITE)
	safeBuild("buildTent", buildTent, park, Vector3.new(75, GROUND_Y, 190), BLUE, WHITE)
	safeBuild("buildTent", buildTent, park, Vector3.new(-190, GROUND_Y, 30), PURPLE, YELLOW)
	local leaderboardRows: { TextLabel }
	local lbOk, lbResult = pcall(buildLeaderboard, park)
	if lbOk and lbResult then
		leaderboardRows = lbResult
	else
		warn("MapBuilder: buildLeaderboard failed (" .. tostring(lbResult) .. "); using fallback rows")
		leaderboardRows = fallbackLeaderboardRows(park)
	end

	-- DANGER signs at the four path corners + near each base gateway.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			safeBuild("buildDangerSign", buildDangerSign, park, Vector3.new(sx * 136, GROUND_Y, sz * 136), math.atan2(-sx, -sz))
			safeBuild("buildDangerSign", buildDangerSign, park, Vector3.new(sx * 140, GROUND_Y, sz * 150), math.atan2(-sx, 0))
		end
	end

	-- Trees (16 big round ones) + pines, kept clear of path and plaza.
	local treeSpecs = {
		{ -60, -100, LEAF_GREEN, 8 }, { 60, -100, LEAF_PINK, 7 }, { -60, 100, LEAF_PINK, 8 }, { 60, 100, LEAF_GREEN, 7 },
		{ -100, -60, LEAF_GREEN, 9 }, { 100, -60, LEAF_PINK, 8 }, { -100, 60, LEAF_GREEN, 7 }, { 100, 60, LEAF_PINK, 9 },
		{ -170, -60, LEAF_PINK, 10 }, { -170, 110, LEAF_GREEN, 9 }, { 205, -110, LEAF_GREEN, 8 }, { 205, 90, LEAF_PINK, 10 },
		{ -40, -205, LEAF_GREEN, 9 }, { 40, -205, LEAF_PINK, 8 }, { -120, 205, LEAF_GREEN, 10 }, { 130, 205, LEAF_PINK, 9 },
		{ -205, -120, LEAF_GREEN, 8 }, { 60, 160, LEAF_PINK, 7 },
	}
	for _, spec in ipairs(treeSpecs) do
		safeBuild("buildTree", buildTree, park, Vector3.new(spec[1], GROUND_Y, spec[2]), spec[3], spec[4])
	end
	for _, pos in ipairs({ { -205, 160 }, { 205, 160 }, { -205, -200 }, { 110, -185 }, { -110, -185 }, { 0, 215 } }) do
		safeBuild("buildPine", buildPine, park, Vector3.new(pos[1], GROUND_Y, pos[2]))
	end

	-- Hot air balloons (animated below).
	local balloons = {}
	local balloonSpecs = {
		{ pos = Vector3.new(-120, GROUND_Y + 42, -60), a = RED, b = YELLOW },
		{ pos = Vector3.new(90, GROUND_Y + 48, 120), a = BLUE, b = WHITE },
		{ pos = Vector3.new(160, GROUND_Y + 38, -160), a = PURPLE, b = PINK },
	}
	for i, spec in ipairs(balloonSpecs) do
		local balloonOk, balloonModel = pcall(buildBalloon, park, spec.pos, spec.a, spec.b)
		if balloonOk and balloonModel then
			balloons[i] = { model = balloonModel, base = spec.pos, phase = i * 1.7 }
		else
			warn("MapBuilder: buildBalloon " .. i .. " failed (" .. tostring(balloonModel) .. ")")
		end
	end

	safeBuild("buildPerimeter", buildPerimeter, park)

	-- Lamps around the plaza and along the outer strip.
	for _, pos in ipairs({
		{ -95, -95 }, { 95, -95 }, { -95, 95 }, { 95, 95 },
		{ 0, -100 }, { 0, 100 }, { -100, 0 }, { 100, 0 },
		{ -145, -145 }, { 145, -145 }, { -145, 145 }, { 145, 145 },
	}) do
		safeBuild("buildLamp", buildLamp, park, Vector3.new(pos[1], GROUND_Y, pos[2]))
	end

	-- RGB night-market lamps (dense ring; bulbs cycle in Heartbeat).
	safeBuild("buildRgbLamps", buildRgbLamps, park)

	-- Prop clusters filling the sparse outer chunks (density audit).
	for _, spec in ipairs({
		{ -200, -60, 0.4 }, { -200, 120, 1.2 }, { 60, -200, 2.1 }, { -60, -200, 0.9 },
		{ 200, -140, 1.7 }, { 200, 140, 0.2 }, { -140, 205, 2.6 }, { 140, 205, 1.1 },
		{ -205, -160, 0.7 }, { 205, 20, 2.9 }, { -30, 160, 1.9 }, { 30, -160, 0.5 },
	}) do
		safeBuild("buildPropCluster", buildPropCluster, park, Vector3.new(spec[1], GROUND_Y, spec[2]), spec[3])
	end

	-- Extra benches + crates + balloon bunches near the plaza edges.
	for _, spec in ipairs({ { -30, -98, 0 }, { 30, 98, math.pi }, { -98, 30, math.pi / 2 }, { 98, -30, -math.pi / 2 } }) do
		safeBuild("buildBench", buildBench, park, Vector3.new(spec[1], GROUND_Y, spec[2]), spec[3])
	end
	safeBuild("buildCrateStack", buildCrateStack, park, Vector3.new(-40, GROUND_Y, -150))
	safeBuild("buildCrateStack", buildCrateStack, park, Vector3.new(40, GROUND_Y, -150))
	safeBuild("buildBalloonBunch", buildBalloonBunch, park, Vector3.new(-12, GROUND_Y, 40))
	safeBuild("buildBalloonBunch", buildBalloonBunch, park, Vector3.new(12, GROUND_Y, 40))

	------------------------------------------------------------------
	-- Runtime sanity checks (warn-only: never kill Init)
	------------------------------------------------------------------
	if #bases ~= 4 then
		warn("MapBuilder: expected 4 bases, got " .. #bases)
	end
	for i, base in ipairs(bases) do
		if not (base.Center and base.PlaceZone and base.SignLabel) then
			warn("MapBuilder: base " .. i .. " missing fields")
		end
		if #base.Pedestals ~= 8 then
			warn("MapBuilder: base " .. i .. " must have 8 pedestals, got " .. #base.Pedestals)
		end
		if #base.Rims ~= 8 then
			warn("MapBuilder: base " .. i .. " must have 8 rims, got " .. #base.Rims)
		end
	end
	if #leaderboardRows ~= 4 then
		warn("MapBuilder: expected 4 leaderboard rows, got " .. #leaderboardRows)
	end
	if #waypoints < 8 then
		warn("MapBuilder: expected at least 8 path waypoints, got " .. #waypoints)
	end

	local spawnCount = 0
	for _, descendant in ipairs(park:GetDescendants()) do
		if descendant:IsA("SpawnLocation") then
			spawnCount += 1
		end
	end
	if spawnCount ~= 1 then
		warn("MapBuilder: expected exactly 1 SpawnLocation, got " .. spawnCount)
	end

	-- No building footprint may intersect the path band rects.
	local function intersectsPath(cx: number, cz: number, halfX: number, halfZ: number): boolean
		local bands = {
			{ -PATH_OUTER, -PATH_OUTER, PATH_OUTER, -PATH_INNER }, -- north band
			{ -PATH_OUTER, PATH_INNER, PATH_OUTER, PATH_OUTER }, -- south band
			{ -PATH_OUTER, -PATH_INNER, -PATH_INNER, PATH_INNER }, -- west band
			{ PATH_INNER, -PATH_INNER, PATH_OUTER, PATH_INNER }, -- east band
		}
		for _, band in ipairs(bands) do
			if cx + halfX > band[1] and cx - halfX < band[3] and cz + halfZ > band[2] and cz - halfZ < band[4] then
				return true
			end
		end
		return false
	end
	if intersectsPath(0, -168, 22, 14) then
		warn("MapBuilder: Warehouse intersects path")
	end
	if intersectsPath(168, -45, 12, 18) then
		warn("MapBuilder: Shop intersects path")
	end
	if intersectsPath(168, 35, 12, 18) then
		warn("MapBuilder: Safe Zone intersects path")
	end
	if intersectsPath(-52, -52, 19, 19) then
		warn("MapBuilder: Chair Swing intersects path")
	end
	if intersectsPath(52, -52, 20, 15) then
		warn("MapBuilder: Bumper Cars intersects path")
	end
	if intersectsPath(-52, 52, 10, 10) then
		warn("MapBuilder: Drop Tower intersects path")
	end

	if partCount < 2000 then
		warn("MapBuilder: part count " .. partCount .. " below 2000 target")
	end
	print("MapBuilder: park built, " .. partCount .. " parts")

	------------------------------------------------------------------
	-- Animation: ferris wheel spin + balloon bobbing
	------------------------------------------------------------------
	local angle = 0
	-- Visual animation is throttled to ~15 Hz: setting ~44 bulb colors
	-- and PivotTo-ing several models every frame caused visible
	-- stutter. Gameplay timing (spawner/storm/economy) runs on its
	-- own task.wait loops and is unaffected.
	local lastAnimAt = os.clock()
	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		if now - lastAnimAt < 1 / 15 then
			return
		end
		local stepDt = math.min(now - lastAnimAt, 0.25)
		lastAnimAt = now
		pcall(function()
			angle += stepDt * 0.15
			if wheel and wheelBase then
				wheel:PivotTo(wheelBase * CFrame.Angles(0, 0, angle))
			end
			local t = now
			for _, balloon in ipairs(balloons) do
				if balloon.model then
					local bob = math.sin(t * 0.5 + balloon.phase) * 2
					balloon.model:PivotTo(CFrame.new(balloon.base + Vector3.new(0, bob, 0)))
				end
			end
			for _, entry in ipairs(rgbBulbs) do
				local c = Color3.fromHSV((t * 0.08 + entry.phase) % 1, 0.85, 1)
				entry.bulb.Color = c
				if entry.light then
					entry.light.Color = c
				end
			end
			if carousel and carouselBase then
				local carouselCF = carouselBase * CFrame.Angles(0, t * 0.25, 0)
				carousel:PivotTo(carouselCF)
				if carouselHorses then
					for _, horse in ipairs(carouselHorses) do
						if horse.model then
							local bob = math.sin(t * 2 + horse.phase) * 0.8
							horse.model:PivotTo(carouselCF * horse.localCF * CFrame.new(0, bob, 0))
						end
					end
				end
			end
			if swingRide and swingBase then
				swingRide:PivotTo(swingBase * CFrame.Angles(0, t * 0.5, 0))
			end
			if dropGondola and dropBase then
				local lift = (math.sin(t * 0.4) * 0.5 + 0.5) * dropTravel
				dropGondola:PivotTo(dropBase * CFrame.new(0, lift, 0))
			end
		end)
	end)

	return {
		Bases = bases,
		LeaderboardRows = leaderboardRows,
		PathWaypoints = waypoints,
	}
end

return MapBuilder
