-- Brainrot Stealer: the cast. Eighteen absurd characters on a six-rung rarity
-- ladder. Prices and income are server-owned numbers; the model builder reads
-- bodyColor/accentColor/propKind to dress each one.

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type BrainrotDef = {
	id: string,
	name: string,
	rarity: Rarity,
	price: number,
	income: number,
	bodyColor: Color3,
	accentColor: Color3,
	propKind: string,
}

local BrainrotCatalog = {}

BrainrotCatalog.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

BrainrotCatalog.RarityColors = {
	Common = Color3.fromRGB(180, 190, 200),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(190, 100, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 80, 120),
	Secret = Color3.fromRGB(60, 255, 220),
}

local defs: { BrainrotDef } = {
	-- Common ------------------------------------------------------------------
	{
		id = "tungtung",
		name = "Tung Tung Sahur",
		rarity = "Common",
		price = 25,
		income = 3,
		bodyColor = Color3.fromRGB(150, 100, 60),
		accentColor = Color3.fromRGB(90, 60, 35),
		propKind = "bat",
	},
	{
		id = "tralalero",
		name = "Tralalero Tralala",
		rarity = "Common",
		price = 60,
		income = 6,
		bodyColor = Color3.fromRGB(70, 140, 220),
		accentColor = Color3.fromRGB(240, 245, 250),
		propKind = "shark",
	},
	-- Rare --------------------------------------------------------------------
	{
		id = "cappuccino",
		name = "Cappuccino Assassino",
		rarity = "Rare",
		price = 110,
		income = 11,
		bodyColor = Color3.fromRGB(245, 240, 230),
		accentColor = Color3.fromRGB(120, 75, 45),
		propKind = "coffee",
	},
	{
		id = "chimpanzini",
		name = "Chimpanzini Bananini",
		rarity = "Rare",
		price = 180,
		income = 14,
		bodyColor = Color3.fromRGB(250, 215, 60),
		accentColor = Color3.fromRGB(120, 80, 40),
		propKind = "banana",
	},
	{
		id = "trippitroppi",
		name = "Trippi Troppi",
		rarity = "Rare",
		price = 240,
		income = 18,
		bodyColor = Color3.fromRGB(160, 110, 70),
		accentColor = Color3.fromRGB(90, 180, 220),
		propKind = "bearfish",
	},
	{
		id = "lirili",
		name = "Lirili Larila",
		rarity = "Rare",
		price = 300,
		income = 22,
		bodyColor = Color3.fromRGB(165, 170, 180),
		accentColor = Color3.fromRGB(80, 180, 90),
		propKind = "elephant",
	},
	-- Epic --------------------------------------------------------------------
	{
		id = "ballerina",
		name = "Ballerina Cappuccina",
		rarity = "Epic",
		price = 700,
		income = 45,
		bodyColor = Color3.fromRGB(250, 200, 220),
		accentColor = Color3.fromRGB(255, 120, 180),
		propKind = "ballerina",
	},
	{
		id = "frulli",
		name = "Frulli Frulla",
		rarity = "Epic",
		price = 900,
		income = 58,
		bodyColor = Color3.fromRGB(255, 160, 90),
		accentColor = Color3.fromRGB(255, 90, 90),
		propKind = "smoothie",
	},
	{
		id = "patapim",
		name = "Brr Brr Patapim",
		rarity = "Epic",
		price = 1100,
		income = 70,
		bodyColor = Color3.fromRGB(120, 85, 55),
		accentColor = Color3.fromRGB(70, 190, 90),
		propKind = "tree",
	},
	-- Legendary ---------------------------------------------------------------
	{
		id = "glorbo",
		name = "Glorbo Fruttodrillo",
		rarity = "Legendary",
		price = 1500,
		income = 135,
		bodyColor = Color3.fromRGB(70, 200, 90),
		accentColor = Color3.fromRGB(255, 90, 110),
		propKind = "watermelon",
	},
	{
		id = "bombardiro",
		name = "Bombardiro Crocodilo",
		rarity = "Legendary",
		price = 2200,
		income = 140,
		bodyColor = Color3.fromRGB(90, 180, 90),
		accentColor = Color3.fromRGB(240, 240, 240),
		propKind = "bomber",
	},
	{
		id = "grande",
		name = "La Grande Combinazione",
		rarity = "Legendary",
		price = 2800,
		income = 175,
		bodyColor = Color3.fromRGB(200, 160, 255),
		accentColor = Color3.fromRGB(255, 200, 60),
		propKind = "combo",
	},
	{
		id = "lavaca",
		name = "La Vaca Saturno Saturnita",
		rarity = "Legendary",
		price = 3400,
		income = 210,
		bodyColor = Color3.fromRGB(245, 245, 245),
		accentColor = Color3.fromRGB(255, 200, 60),
		propKind = "saturncow",
	},
	-- Mythic ------------------------------------------------------------------
	{
		id = "frigo",
		name = "Frigo Camelo",
		rarity = "Mythic",
		price = 6500,
		income = 420,
		bodyColor = Color3.fromRGB(235, 240, 245),
		accentColor = Color3.fromRGB(200, 160, 110),
		propKind = "fridge",
	},
	{
		id = "boneca",
		name = "Boneca Ambalabu",
		rarity = "Mythic",
		price = 10000,
		income = 650,
		bodyColor = Color3.fromRGB(110, 220, 110),
		accentColor = Color3.fromRGB(40, 40, 45),
		propKind = "frogtire",
	},
	-- Secret ------------------------------------------------------------------
	{
		id = "spaghetti",
		name = "Spaghetti Tualetti",
		rarity = "Secret",
		price = 15000,
		income = 1350,
		bodyColor = Color3.fromRGB(250, 220, 120),
		accentColor = Color3.fromRGB(150, 70, 40),
		propKind = "spaghetti",
	},
	{
		id = "giraffa",
		name = "Giraffa Celeste",
		rarity = "Secret",
		price = 22000,
		income = 1500,
		bodyColor = Color3.fromRGB(120, 220, 130),
		accentColor = Color3.fromRGB(255, 170, 60),
		propKind = "giraffe",
	},
	{
		id = "tralaleritos",
		name = "Los Tralaleritos",
		rarity = "Secret",
		price = 45000,
		income = 3000,
		bodyColor = Color3.fromRGB(110, 180, 240),
		accentColor = Color3.fromRGB(255, 150, 200),
		propKind = "babysharks",
	},
}

BrainrotCatalog.Defs = defs

local byId: { [string]: BrainrotDef } = {}
local byRarity: { [string]: { BrainrotDef } } = {}
for _, def in ipairs(defs) do
	assert(byId[def.id] == nil, "BrainrotCatalog: duplicate id " .. def.id)
	byId[def.id] = def
	byRarity[def.rarity] = byRarity[def.rarity] or {}
	table.insert(byRarity[def.rarity], def)
end

function BrainrotCatalog.get(id: string): BrainrotDef?
	return byId[id]
end

function BrainrotCatalog.ofRarity(rarity: string): { BrainrotDef }
	return byRarity[rarity] or {}
end

function BrainrotCatalog.count(): number
	return #defs
end

assert(#defs == 18, "BrainrotCatalog: the cast must hold exactly 18 characters")

return BrainrotCatalog
