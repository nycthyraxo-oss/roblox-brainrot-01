-- Brainrot Stealer: builds every character model from plain primitives.
-- Each model is a Model whose PrimaryPart is "Body"; every other part is
-- welded to Body, so moving Body moves the whole character. The server
-- factory adds the floating label; the client codex uses these same models
-- inside ViewportFrames. Tint modes: normal, gold, cyan, dim, silhouette.

local BrainrotCatalog = require(script.Parent.BrainrotCatalog)

local BrainrotModelBuilder = {}

local WHITE = Color3.fromRGB(250, 250, 250)
local BLACK = Color3.fromRGB(25, 25, 30)
local GOLD = Color3.fromRGB(255, 200, 60)
local CYAN = Color3.fromRGB(90, 230, 255)
local DIM = Color3.fromRGB(70, 70, 80)
local SILHOUETTE = Color3.fromRGB(14, 14, 22)

local function makePart(parent: Instance, name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function weldTo(body: Part, part: Part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
end

local function place(body: Part, part: Part, offset: CFrame)
	part.CFrame = body.CFrame * offset
	weldTo(body, part)
end

local function addEyes(model: Model, body: Part, y: number, spread: number, z: number, scale: number)
	for _, side in ipairs({ -1, 1 }) do
		local eye = makePart(model, "Eye", Vector3.new(0.5, 0.5, 0.5) * scale, WHITE, Enum.PartType.Ball)
		place(body, eye, CFrame.new(spread * side, y, z))
		local pupil = makePart(model, "Pupil", Vector3.new(0.24, 0.24, 0.24) * scale, BLACK, Enum.PartType.Ball)
		place(body, pupil, CFrame.new(spread * side, y, z - 0.2 * scale))
	end
end

local function addFeet(model: Model, body: Part, y: number, spread: number, color: Color3, size: Vector3?)
	for _, side in ipairs({ -1, 1 }) do
		local foot = makePart(model, "Foot", size or Vector3.new(0.7, 0.4, 1.1), color)
		place(body, foot, CFrame.new(spread * side, y, -0.1))
	end
end

local function addMouth(model: Model, body: Part, y: number, z: number, width: number)
	local mouth = makePart(model, "Mouth", Vector3.new(width, 0.16, 0.12), BLACK)
	place(body, mouth, CFrame.new(0, y, z))
end

local function uprightCylinder(model: Model, body: Part, name: string, diameter: number, height: number, color: Color3, offset: CFrame)
	local part = makePart(model, name, Vector3.new(height, diameter, diameter), color, Enum.PartType.Cylinder)
	place(body, part, offset * CFrame.Angles(0, 0, math.rad(90)))
	return part
end

-- Signature-prop builders, one per propKind in the catalog. -------------------

local builders: { [string]: (Model, Part, any) -> () } = {}

builders.bat = function(model, body, def)
	-- A wooden log with a baseball bat.
	local ring = uprightCylinder(model, body, "LogRing", 2.1, 0.3, def.accentColor, CFrame.new(0, 1.2, 0))
	ring.Transparency = 0.15
	local bat = makePart(model, "Bat", Vector3.new(0.35, 2.4, 0.35), Color3.fromRGB(200, 160, 100))
	place(body, bat, CFrame.new(1.5, 0.2, 0) * CFrame.Angles(0, 0, math.rad(-25)))
	local knob = makePart(model, "BatKnob", Vector3.new(0.55, 0.3, 0.55), def.accentColor)
	place(body, knob, CFrame.new(2.0, -0.85, 0))
	addEyes(model, body, 0.7, 0.5, -1.0, 1)
	addMouth(model, body, -0.1, -1.05, 0.7)
	addFeet(model, body, -1.85, 0.55, def.accentColor)
end

builders.shark = function(model, body, def)
	-- A shark in sneakers: belly, dorsal fin, tail fin, shoes.
	local belly = makePart(model, "Belly", Vector3.new(1.9, 1.5, 0.4), WHITE)
	place(body, belly, CFrame.new(0, -0.2, -1.15))
	local snout = makePart(model, "Snout", Vector3.new(1.6, 0.8, 0.8), def.bodyColor)
	place(body, snout, CFrame.new(0, 0.2, -1.5))
	local fin = makePart(model, "DorsalFin", Vector3.new(0.25, 1.1, 1.2), def.accentColor, Enum.PartType.Wedge)
	place(body, fin, CFrame.new(0, 1.5, 0.2))
	local tail = makePart(model, "TailFin", Vector3.new(0.25, 1.3, 1.0), def.accentColor, Enum.PartType.Wedge)
	place(body, tail, CFrame.new(0, 0.6, 1.7) * CFrame.Angles(math.rad(180), 0, 0))
	for _, side in ipairs({ -1, 1 }) do
		local shoe = makePart(model, "Sneaker", Vector3.new(0.8, 0.45, 1.3), WHITE)
		place(body, shoe, CFrame.new(0.6 * side, -1.2, -0.2))
		local stripe = makePart(model, "ShoeStripe", Vector3.new(0.82, 0.18, 0.5), def.bodyColor)
		place(body, stripe, CFrame.new(0.6 * side, -1.15, -0.55))
	end
	addEyes(model, body, 0.65, 0.55, -1.35, 1)
	addMouth(model, body, -0.25, -1.95, 0.9)
end

builders.coffee = function(model, body, def)
	-- A coffee cup ninja: coffee top, handle, mask band, katana.
	uprightCylinder(model, body, "CoffeeTop", 2.0, 0.25, def.accentColor, CFrame.new(0, 1.35, 0))
	local mask = makePart(model, "Mask", Vector3.new(2.3, 0.55, 2.3), BLACK)
	place(body, mask, CFrame.new(0, 0.55, 0))
	local handle = makePart(model, "Handle", Vector3.new(0.25, 1.1, 0.25), WHITE)
	place(body, handle, CFrame.new(1.35, 0, 0))
	local katana = makePart(model, "Katana", Vector3.new(0.12, 2.6, 0.3), Color3.fromRGB(200, 205, 215))
	place(body, katana, CFrame.new(-0.9, 0.6, 1.0) * CFrame.Angles(math.rad(35), 0, math.rad(20)))
	addEyes(model, body, 0.55, 0.5, -1.12, 0.9)
	addFeet(model, body, -1.45, 0.55, BLACK)
end

builders.banana = function(model, body, def)
	-- A banana monkey: bent tip, stem, ears, tan face.
	local tip = makePart(model, "BananaTip", Vector3.new(1.7, 1.1, 1.5), def.bodyColor)
	place(body, tip, CFrame.new(0, 1.6, 0.25) * CFrame.Angles(math.rad(30), 0, 0))
	uprightCylinder(model, body, "Stem", 0.35, 0.7, def.accentColor, CFrame.new(0, 2.3, 0.5))
	local face = makePart(model, "Face", Vector3.new(1.5, 1.2, 0.3), Color3.fromRGB(240, 205, 160))
	place(body, face, CFrame.new(0, 0.3, -0.85))
	for _, side in ipairs({ -1, 1 }) do
		local ear = makePart(model, "Ear", Vector3.new(0.55, 0.55, 0.3), def.accentColor, Enum.PartType.Ball)
		place(body, ear, CFrame.new(1.0 * side, 0.6, 0))
	end
	addEyes(model, body, 0.55, 0.45, -1.0, 0.95)
	addMouth(model, body, -0.05, -1.02, 0.6)
	addFeet(model, body, -1.5, 0.55, def.accentColor)
end

builders.bearfish = function(model, body, def)
	-- A bear with a fish tail and fins.
	for _, side in ipairs({ -1, 1 }) do
		local ear = makePart(model, "BearEar", Vector3.new(0.6, 0.6, 0.35), def.bodyColor, Enum.PartType.Ball)
		place(body, ear, CFrame.new(0.75 * side, 1.45, 0))
	end
	local snout = makePart(model, "Snout", Vector3.new(1.1, 0.7, 0.6), Color3.fromRGB(240, 205, 160))
	place(body, snout, CFrame.new(0, -0.1, -1.05))
	local tail = makePart(model, "FishTail", Vector3.new(0.25, 1.4, 1.1), def.accentColor, Enum.PartType.Wedge)
	place(body, tail, CFrame.new(0, 0.4, 1.6) * CFrame.Angles(math.rad(180), 0, 0))
	local fin = makePart(model, "BackFin", Vector3.new(0.2, 0.9, 1.0), def.accentColor, Enum.PartType.Wedge)
	place(body, fin, CFrame.new(0, 1.5, 0.3))
	addEyes(model, body, 0.6, 0.5, -0.95, 1)
	addFeet(model, body, -1.5, 0.55, def.accentColor)
end

builders.elephant = function(model, body, def)
	-- An elephant with a cactus arm and sandals.
	for _, side in ipairs({ -1, 1 }) do
		local ear = makePart(model, "BigEar", Vector3.new(0.3, 1.6, 1.4), def.bodyColor)
		place(body, ear, CFrame.new(1.5 * side, 0.5, 0))
	end
	local trunk1 = makePart(model, "Trunk", Vector3.new(0.55, 1.4, 0.55), def.bodyColor)
	place(body, trunk1, CFrame.new(0, 0.2, -1.4) * CFrame.Angles(math.rad(25), 0, 0))
	local trunk2 = makePart(model, "TrunkTip", Vector3.new(0.45, 0.9, 0.45), def.bodyColor)
	place(body, trunk2, CFrame.new(0, -0.7, -1.75) * CFrame.Angles(math.rad(-15), 0, 0))
	local cactus = makePart(model, "CactusArm", Vector3.new(0.5, 1.6, 0.5), def.accentColor)
	place(body, cactus, CFrame.new(1.7, 0.6, -0.4))
	local cactusArm = makePart(model, "CactusBend", Vector3.new(0.4, 0.8, 0.4), def.accentColor)
	place(body, cactusArm, CFrame.new(1.95, 1.1, -0.4))
	addEyes(model, body, 0.8, 0.6, -1.12, 1)
	addFeet(model, body, -1.45, 0.7, Color3.fromRGB(180, 130, 80), Vector3.new(0.9, 0.3, 1.4))
end

builders.ballerina = function(model, body, def)
	-- A cappuccino ballerina: tutu disc, bow, pointe shoes.
	uprightCylinder(model, body, "FoamTop", 1.9, 0.3, WHITE, CFrame.new(0, 1.35, 0))
	uprightCylinder(model, body, "Tutu", 3.6, 0.35, def.accentColor, CFrame.new(0, -0.5, 0))
	for _, side in ipairs({ -1, 1 }) do
		local bow = makePart(model, "Bow", Vector3.new(0.7, 0.4, 0.25), def.accentColor, Enum.PartType.Wedge)
		place(body, bow, CFrame.new(0.45 * side, 1.75, 0) * CFrame.Angles(0, 0, math.rad(30 * side)))
	end
	local shoeL = makePart(model, "PointeShoe", Vector3.new(0.6, 0.35, 1.0), def.accentColor)
	place(body, shoeL, CFrame.new(-0.55, -1.5, -0.1))
	local shoeR = makePart(model, "PointeShoe", Vector3.new(0.6, 0.35, 1.0), def.accentColor)
	place(body, shoeR, CFrame.new(0.55, -1.35, 0.3) * CFrame.Angles(math.rad(-40), 0, 0))
	addEyes(model, body, 0.6, 0.5, -1.05, 0.95)
	addMouth(model, body, 0.0, -1.08, 0.5)
end

builders.smoothie = function(model, body, def)
	-- A fruit smoothie: whipped top, straw, fruit slices, cherry.
	local whip = makePart(model, "WhippedTop", Vector3.new(1.9, 1.1, 1.9), WHITE, Enum.PartType.Ball)
	place(body, whip, CFrame.new(0, 1.45, 0))
	local cherry = makePart(model, "Cherry", Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(220, 40, 60), Enum.PartType.Ball)
	place(body, cherry, CFrame.new(0.3, 2.05, 0))
	local straw = makePart(model, "Straw", Vector3.new(0.22, 1.8, 0.22), def.accentColor)
	place(body, straw, CFrame.new(-0.6, 1.9, 0) * CFrame.Angles(0, 0, math.rad(18)))
	local sliceColors = { Color3.fromRGB(255, 120, 80), Color3.fromRGB(140, 230, 120), Color3.fromRGB(255, 220, 90) }
	for i, sliceColor in ipairs(sliceColors) do
		local angle = math.rad(i * 120)
		local slice = uprightCylinder(model, body, "FruitSlice", 0.85, 0.18, sliceColor, CFrame.new(math.sin(angle) * 1.15, 0.9, math.cos(angle) * 1.15))
		slice.Transparency = 0.05
	end
	addEyes(model, body, 0.45, 0.5, -1.05, 0.95)
	addMouth(model, body, -0.15, -1.08, 0.6)
	addFeet(model, body, -1.5, 0.55, def.accentColor)
end

builders.tree = function(model, body, def)
	-- A walking tree: foliage ball, long nose, root feet, branch arms.
	local foliage = makePart(model, "Foliage", Vector3.new(3.0, 2.6, 3.0), def.accentColor, Enum.PartType.Ball)
	place(body, foliage, CFrame.new(0, 2.2, 0))
	local nose = makePart(model, "LongNose", Vector3.new(0.4, 0.4, 1.6), Color3.fromRGB(240, 205, 160))
	place(body, nose, CFrame.new(0, 0.6, -1.5))
	for _, side in ipairs({ -1, 1 }) do
		local branch = makePart(model, "BranchArm", Vector3.new(1.4, 0.3, 0.3), def.bodyColor)
		place(body, branch, CFrame.new(1.4 * side, 0.9, 0) * CFrame.Angles(0, 0, math.rad(20 * side)))
		local root = makePart(model, "RootFoot", Vector3.new(0.8, 0.35, 1.3), def.bodyColor)
		place(body, root, CFrame.new(0.6 * side, -1.6, -0.1))
	end
	addEyes(model, body, 1.1, 0.5, -0.85, 1)
end

builders.watermelon = function(model, body, def)
	-- A watermelon creature: stripes, a slice on top, little arms.
	for i = -1, 1 do
		local stripe = makePart(model, "Stripe", Vector3.new(0.35, 2.2, 2.9), Color3.fromRGB(40, 140, 60))
		place(body, stripe, CFrame.new(i * 0.9, 0, 0))
	end
	local slice = uprightCylinder(model, body, "MelonSlice", 1.6, 0.3, def.accentColor, CFrame.new(0, 1.55, 0))
	slice.Transparency = 0.05
	for _, side in ipairs({ -1, 1 }) do
		local arm = makePart(model, "Arm", Vector3.new(0.9, 0.35, 0.35), def.bodyColor)
		place(body, arm, CFrame.new(1.5 * side, -0.2, 0))
	end
	addEyes(model, body, 0.5, 0.55, -1.35, 1)
	addMouth(model, body, -0.3, -1.42, 0.8)
	addFeet(model, body, -1.55, 0.6, Color3.fromRGB(40, 140, 60))
end

builders.bomber = function(model, body, def)
	-- A crocodile bomber plane: snout, wings, tail fin, propeller.
	local snout = makePart(model, "Snout", Vector3.new(1.7, 0.9, 1.2), def.bodyColor)
	place(body, snout, CFrame.new(0, -0.1, -2.2))
	for i = -1, 1 do
		local tooth = makePart(model, "Tooth", Vector3.new(0.22, 0.35, 0.15), WHITE)
		place(body, tooth, CFrame.new(i * 0.5, -0.55, -2.75))
	end
	for _, side in ipairs({ -1, 1 }) do
		local wing = makePart(model, "Wing", Vector3.new(2.2, 0.18, 1.1), def.accentColor)
		place(body, wing, CFrame.new(2.0 * side, 0.5, 0.2))
	end
	local tail = makePart(model, "TailFin", Vector3.new(0.2, 1.2, 1.0), def.accentColor, Enum.PartType.Wedge)
	place(body, tail, CFrame.new(0, 0.9, 1.8))
	local propA = makePart(model, "Propeller", Vector3.new(0.18, 2.2, 0.1), Color3.fromRGB(90, 90, 100))
	place(body, propA, CFrame.new(0, -0.1, -2.95))
	local propB = makePart(model, "Propeller", Vector3.new(2.2, 0.18, 0.1), Color3.fromRGB(90, 90, 100))
	place(body, propB, CFrame.new(0, -0.1, -2.95))
	addEyes(model, body, 0.75, 0.55, -1.75, 1)
	addFeet(model, body, -1.15, 0.6, def.bodyColor)
end

builders.combo = function(model, body, def)
	-- The great combination: a mashup wearing everyone else's props.
	uprightCylinder(model, body, "GoldRing", 3.4, 0.3, def.accentColor, CFrame.new(0, -0.3, 0))
	local miniBat = makePart(model, "MiniBat", Vector3.new(0.3, 1.8, 0.3), Color3.fromRGB(200, 160, 100))
	place(body, miniBat, CFrame.new(1.6, 0.3, 0) * CFrame.Angles(0, 0, math.rad(-20)))
	local fin = makePart(model, "MiniFin", Vector3.new(0.2, 0.9, 1.0), Color3.fromRGB(70, 140, 220), Enum.PartType.Wedge)
	place(body, fin, CFrame.new(0, 1.9, 0.3))
	uprightCylinder(model, body, "MiniCup", 1.1, 0.9, WHITE, CFrame.new(-0.8, 1.8, -0.4))
	for _, side in ipairs({ -1, 1 }) do
		local shoe = makePart(model, "Sneaker", Vector3.new(0.8, 0.45, 1.3), Color3.fromRGB(255, 120, 180))
		place(body, shoe, CFrame.new(0.65 * side, -1.65, -0.2))
	end
	addEyes(model, body, 0.7, 0.55, -1.12, 1.05)
	addMouth(model, body, -0.05, -1.15, 0.8)
end

builders.saturncow = function(model, body, def)
	-- A cow wearing Saturn's ring.
	uprightCylinder(model, body, "SaturnRing", 4.6, 0.22, def.accentColor, CFrame.new(0, 0.1, 0) * CFrame.Angles(math.rad(12), 0, 0))
	local spotOffsets = { Vector3.new(1.15, 0.5, 0.4), Vector3.new(-1.15, -0.3, -0.3), Vector3.new(0.6, 0.9, -1.05), Vector3.new(-0.7, -0.7, 1.05) }
	for _, offset in ipairs(spotOffsets) do
		local spot = makePart(model, "Spot", Vector3.new(0.7, 0.7, 0.15), BLACK)
		place(body, spot, CFrame.new(offset))
	end
	for _, side in ipairs({ -1, 1 }) do
		local horn = makePart(model, "Horn", Vector3.new(0.3, 0.7, 0.3), Color3.fromRGB(230, 220, 190), Enum.PartType.Wedge)
		place(body, horn, CFrame.new(0.8 * side, 1.5, 0))
	end
	local snout = makePart(model, "Snout", Vector3.new(1.3, 0.7, 0.5), Color3.fromRGB(255, 180, 200))
	place(body, snout, CFrame.new(0, -0.2, -1.15))
	local udder = makePart(model, "Udder", Vector3.new(0.9, 0.5, 0.9), Color3.fromRGB(255, 180, 200))
	place(body, udder, CFrame.new(0, -1.35, 0.2))
	addEyes(model, body, 0.6, 0.55, -1.12, 1)
	addFeet(model, body, -1.45, 0.6, BLACK)
end

builders.fridge = function(model, body, def)
	-- A fridge with a camel head.
	local doorLine = makePart(model, "DoorLine", Vector3.new(2.24, 0.12, 0.1), Color3.fromRGB(150, 160, 170))
	place(body, doorLine, CFrame.new(0, 0.4, -0.92))
	local handle = makePart(model, "Handle", Vector3.new(0.18, 1.2, 0.18), Color3.fromRGB(150, 160, 170))
	place(body, handle, CFrame.new(0.85, 0.9, -1.0))
	local neck = makePart(model, "CamelNeck", Vector3.new(0.6, 1.4, 0.6), def.accentColor)
	place(body, neck, CFrame.new(0, 2.2, -0.3) * CFrame.Angles(math.rad(20), 0, 0))
	local head = makePart(model, "CamelHead", Vector3.new(0.8, 0.7, 1.1), def.accentColor)
	place(body, head, CFrame.new(0, 2.95, -0.75))
	for _, side in ipairs({ -1, 1 }) do
		local ear = makePart(model, "CamelEar", Vector3.new(0.3, 0.3, 0.2), def.accentColor)
		place(body, ear, CFrame.new(0.35 * side, 3.35, -0.6))
	end
	addEyes(model, body, 3.0, 0.3, -1.25, 0.8)
	addFeet(model, body, -1.85, 0.6, Color3.fromRGB(150, 160, 170))
end

builders.frogtire = function(model, body, def)
	-- A frog riding a tire.
	uprightCylinder(model, body, "Tire", 3.4, 0.8, def.accentColor, CFrame.new(0, -1.3, 0))
	uprightCylinder(model, body, "TireHub", 1.4, 0.85, Color3.fromRGB(180, 185, 195), CFrame.new(0, -1.3, 0))
	for _, side in ipairs({ -1, 1 }) do
		local stalk = makePart(model, "EyeStalk", Vector3.new(0.25, 0.7, 0.25), def.bodyColor)
		place(body, stalk, CFrame.new(0.55 * side, 1.5, -0.3))
		local leg = makePart(model, "FrogLeg", Vector3.new(0.45, 1.0, 0.45), def.bodyColor)
		place(body, leg, CFrame.new(1.25 * side, -0.5, 0.2) * CFrame.Angles(0, 0, math.rad(25 * side)))
	end
	addEyes(model, body, 1.95, 0.55, -0.45, 1.05)
	addMouth(model, body, 0.2, -1.05, 1.1)
end

builders.spaghetti = function(model, body, def)
	-- A plate of spaghetti with meatballs and a fork.
	uprightCylinder(model, body, "Plate", 4.0, 0.3, WHITE, CFrame.new(0, -1.35, 0))
	local mound = makePart(model, "NoodleMound", Vector3.new(2.6, 1.6, 2.6), def.bodyColor, Enum.PartType.Ball)
	place(body, mound, CFrame.new(0, -0.5, 0))
	for i = 1, 5 do
		local angle = math.rad(i * 72)
		local strand = makePart(model, "Strand", Vector3.new(0.18, 1.1, 0.18), def.bodyColor)
		place(body, strand, CFrame.new(math.sin(angle) * 1.2, -0.9, math.cos(angle) * 1.2) * CFrame.Angles(math.rad(20), angle, 0))
	end
	local meatballOffsets = { Vector3.new(0.7, 0.35, 0.4), Vector3.new(-0.6, 0.3, -0.5), Vector3.new(0.1, 0.55, -0.8) }
	for _, offset in ipairs(meatballOffsets) do
		local ball = makePart(model, "Meatball", Vector3.new(0.65, 0.65, 0.65), def.accentColor, Enum.PartType.Ball)
		place(body, ball, CFrame.new(offset))
	end
	local fork = makePart(model, "Fork", Vector3.new(0.15, 1.8, 0.3), Color3.fromRGB(200, 205, 215))
	place(body, fork, CFrame.new(0.9, 0.9, -0.6) * CFrame.Angles(math.rad(-25), 0, math.rad(15)))
	addEyes(model, body, 0.15, 0.5, -1.25, 0.95)
	addMouth(model, body, -0.45, -1.3, 0.7)
end

builders.giraffe = function(model, body, def)
	-- A celestial giraffe: long neck, ossicones, melon-red belly.
	local neck = makePart(model, "LongNeck", Vector3.new(0.7, 2.6, 0.7), def.bodyColor)
	place(body, neck, CFrame.new(0, 2.0, -0.5) * CFrame.Angles(math.rad(18), 0, 0))
	local head = makePart(model, "Head", Vector3.new(0.9, 0.8, 1.2), def.bodyColor)
	place(body, head, CFrame.new(0, 3.3, -1.0))
	for _, side in ipairs({ -1, 1 }) do
		local ossicone = makePart(model, "Ossicone", Vector3.new(0.22, 0.6, 0.22), def.accentColor)
		place(body, ossicone, CFrame.new(0.3 * side, 3.9, -0.85))
	end
	local belly = makePart(model, "MelonBelly", Vector3.new(1.8, 1.6, 0.3), Color3.fromRGB(255, 90, 110))
	place(body, belly, CFrame.new(0, -0.2, -1.05))
	local spotOffsets = { Vector3.new(1.12, 0.6, 0.2), Vector3.new(-1.12, -0.2, -0.4), Vector3.new(0.5, 1.05, 0.9) }
	for _, offset in ipairs(spotOffsets) do
		local spot = makePart(model, "Spot", Vector3.new(0.6, 0.6, 0.15), def.accentColor)
		place(body, spot, CFrame.new(offset))
	end
	addEyes(model, body, 3.35, 0.32, -1.55, 0.85)
	addFeet(model, body, -1.45, 0.6, def.accentColor)
end

builders.babysharks = function(model, body, def)
	-- Three baby sharks in pink sneakers, huddled as one catch.
	local babyOffsets = { Vector3.new(-0.95, -0.55, 0.35), Vector3.new(0.95, -0.55, 0.35), Vector3.new(0, 0.45, -0.3) }
	for _, offset in ipairs(babyOffsets) do
		local baby = makePart(model, "BabyShark", Vector3.new(1.15, 1.0, 1.4), def.bodyColor)
		place(body, baby, CFrame.new(offset))
		local fin = makePart(model, "BabyFin", Vector3.new(0.15, 0.55, 0.6), WHITE, Enum.PartType.Wedge)
		place(body, fin, CFrame.new(offset + Vector3.new(0, 0.75, 0.15)))
		for _, side in ipairs({ -1, 1 }) do
			local shoe = makePart(model, "BabySneaker", Vector3.new(0.45, 0.3, 0.7), def.accentColor)
			place(body, shoe, CFrame.new(offset + Vector3.new(0.32 * side, -0.65, -0.15)))
		end
	end
	addEyes(model, body, 0.55, 0.3, -1.05, 0.8)
end

-- Body shapes per propKind: {size, shape}. ------------------------------------

local bodyShapes: { [string]: any } = {
	bat = { Vector3.new(3.4, 2.0, 2.0), Enum.PartType.Cylinder },
	shark = { Vector3.new(2.4, 2.0, 2.6), nil },
	coffee = { Vector3.new(2.6, 2.2, 2.2), Enum.PartType.Cylinder },
	banana = { Vector3.new(1.9, 2.6, 1.7), nil },
	bearfish = { Vector3.new(2.2, 2.4, 2.0), nil },
	elephant = { Vector3.new(2.8, 2.4, 2.2), nil },
	ballerina = { Vector3.new(2.6, 2.1, 2.1), Enum.PartType.Cylinder },
	smoothie = { Vector3.new(2.6, 2.2, 2.2), Enum.PartType.Cylinder },
	tree = { Vector3.new(1.8, 2.8, 1.8), nil },
	watermelon = { Vector3.new(2.8, 2.6, 2.8), Enum.PartType.Ball },
	bomber = { Vector3.new(2.0, 1.8, 3.4), nil },
	combo = { Vector3.new(2.6, 3.0, 2.2), nil },
	saturncow = { Vector3.new(2.4, 2.4, 2.2), nil },
	fridge = { Vector3.new(2.2, 3.4, 1.8), nil },
	frogtire = { Vector3.new(2.2, 1.9, 2.0), Enum.PartType.Ball },
	spaghetti = { Vector3.new(2.2, 1.6, 2.2), nil },
	giraffe = { Vector3.new(2.2, 2.4, 2.0), nil },
	babysharks = { Vector3.new(1.6, 1.4, 1.6), nil },
}

local function applyTint(model: Model, tintMode: string)
	if tintMode == "normal" then
		return
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if tintMode == "gold" then
				part.Color = part.Color:Lerp(GOLD, 0.65)
			elseif tintMode == "cyan" then
				part.Color = part.Color:Lerp(CYAN, 0.65)
			elseif tintMode == "dim" then
				part.Color = part.Color:Lerp(DIM, 0.55)
			elseif tintMode == "silhouette" then
				part.Color = SILHOUETTE
			end
		end
	end
end

function BrainrotModelBuilder.build(charId: string, tintMode: string?): Model
	local def = BrainrotCatalog.get(charId)
	assert(def ~= nil, "BrainrotModelBuilder: unknown character id " .. tostring(charId))

	local model = Instance.new("Model")
	model.Name = def.id

	local shapeInfo = bodyShapes[def.propKind]
	assert(shapeInfo ~= nil, "BrainrotModelBuilder: no body shape for propKind " .. def.propKind)

	local body = makePart(model, "Body", shapeInfo[1], def.bodyColor, shapeInfo[2])
	if shapeInfo[2] == Enum.PartType.Cylinder then
		-- Cylinder parts run along X; stand the body upright.
		body.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
	end
	body.Anchored = true
	body.CanTouch = true
	model.PrimaryPart = body

	local builder = builders[def.propKind]
	assert(builder ~= nil, "BrainrotModelBuilder: no builder for propKind " .. def.propKind)
	builder(model, body, def)

	applyTint(model, tintMode or "normal")

	assert(model.PrimaryPart ~= nil, "BrainrotModelBuilder: built model has no PrimaryPart")
	return model
end

return BrainrotModelBuilder
