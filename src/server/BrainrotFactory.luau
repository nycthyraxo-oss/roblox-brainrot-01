-- Brainrot Stealer: server-side wrapper over the shared model builder.
-- Adds the floating name/price/income label the path and pedestals need, and
-- knows how mutations change income and tint.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local BrainrotModelBuilder = require(Shared:WaitForChild("BrainrotModelBuilder"))
local Config = require(Shared:WaitForChild("Config"))

local BrainrotFactory = {}

function BrainrotFactory.tintFor(mutation: string?): string
	if mutation == "Golden" then
		return "gold"
	elseif mutation == "Diamond" then
		return "cyan"
	end
	return "normal"
end

function BrainrotFactory.incomeOf(def: any, mutation: string?): number
	local multiplier = 1
	if mutation == "Golden" then
		multiplier = Config.GoldenMultiplier
	elseif mutation == "Diamond" then
		multiplier = Config.DiamondMultiplier
	end
	return def.income * multiplier
end

function BrainrotFactory.rollMutation(rng: Random): string?
	local roll = rng:NextNumber()
	if roll < Config.DiamondChance then
		return "Diamond"
	elseif roll < Config.DiamondChance + Config.GoldenChance then
		return "Golden"
	end
	return nil
end

local function makeLabel(parent: Instance, text: string, yOffset: number, color: Color3, bold: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Line"
	label.Size = UDim2.new(1, 0, 0, 22)
	label.Position = UDim2.new(0, 0, 0, yOffset)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	label.Parent = parent
	return label
end

function BrainrotFactory.addLabel(model: Model, def: any, mutation: string?)
	local body = model.PrimaryPart
	assert(body ~= nil, "BrainrotFactory: model has no PrimaryPart to label")

	local gui = Instance.new("BillboardGui")
	gui.Name = "BrainrotLabel"
	gui.Size = UDim2.new(0, 170, 0, 76)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140

	local frame = Instance.new("Frame")
	frame.Name = "Card"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = BrainrotCatalog.RarityColors[def.rarity]
	stroke.Thickness = 2
	stroke.Parent = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local title = def.name
	if mutation then
		title = mutation .. " " .. def.name
	end
	makeLabel(frame, title, 2, Color3.fromRGB(255, 255, 255), true)
	makeLabel(frame, "$" .. tostring(def.price), 26, Color3.fromRGB(255, 220, 90), false)
	makeLabel(frame, "$" .. tostring(BrainrotFactory.incomeOf(def, mutation)) .. "/s", 48, Color3.fromRGB(140, 255, 160), false)

	gui.Parent = body
end

function BrainrotFactory.build(charId: string, mutation: string?, withLabel: boolean): Model
	local def = BrainrotCatalog.get(charId)
	assert(def ~= nil, "BrainrotFactory: unknown character id " .. tostring(charId))
	local model = BrainrotModelBuilder.build(charId, BrainrotFactory.tintFor(mutation))
	model:SetAttribute("CharId", charId)
	if mutation then
		model:SetAttribute("Mutation", mutation)
	end
	if withLabel then
		BrainrotFactory.addLabel(model, def, mutation)
	end
	return model
end

return BrainrotFactory
