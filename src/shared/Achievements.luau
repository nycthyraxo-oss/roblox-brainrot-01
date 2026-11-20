-- Brainrot Stealer: the ten achievements. Definitions only; the server-side
-- ProgressService decides when each one is earned and pays the reward once.
-- Rewards are cash grants that never count toward lifetime earnings.

export type AchievementDef = {
	id: string,
	name: string,
	description: string,
	reward: number,
}

local Achievements = {}

local defs: { AchievementDef } = {
	{
		id = "first_purchase",
		name = "First Catch",
		description = "Buy your first brainrot",
		reward = 50,
	},
	{
		id = "collector_5",
		name = "Collector I",
		description = "Own 5 different brainrots",
		reward = 250,
	},
	{
		id = "collector_10",
		name = "Collector II",
		description = "Own 10 different brainrots",
		reward = 1500,
	},
	{
		id = "earn_10k",
		name = "Earner",
		description = "Earn $10,000 in total",
		reward = 500,
	},
	{
		id = "earn_100k",
		name = "Tycoon",
		description = "Earn $100,000 in total",
		reward = 5000,
	},
	{
		id = "legendary_owner",
		name = "Legendary Catch",
		description = "Own a Legendary brainrot",
		reward = 2000,
	},
	{
		id = "secret_owner",
		name = "Top Secret",
		description = "Own a Secret brainrot",
		reward = 10000,
	},
	{
		id = "first_rebirth",
		name = "Born Again",
		description = "Rebirth for the first time",
		reward = 2500,
	},
	{
		id = "storm_survivor",
		name = "Storm Survivor",
		description = "Still be carrying when a Gull Storm ends",
		reward = 500,
	},
	{
		id = "buyer_10",
		name = "Regular Customer",
		description = "Buy 10 brainrots",
		reward = 750,
	},
}

Achievements.Defs = defs

local byId: { [string]: AchievementDef } = {}
for _, def in ipairs(defs) do
	assert(byId[def.id] == nil, "Achievements: duplicate id " .. def.id)
	byId[def.id] = def
end

function Achievements.get(id: string): AchievementDef?
	return byId[id]
end

assert(#defs == 10, "Achievements: exactly ten achievements are defined")

return Achievements
