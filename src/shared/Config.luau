-- Brainrot Stealer: every economy and pacing number lives in this one table.
-- Server and client both read it; the server owns every amount that moves.

local Config = {}

-- Money -----------------------------------------------------------------------
Config.StartCash = 100

-- Spawning and the path -------------------------------------------------------
Config.SpawnIntervalSeconds = 6
Config.WalkSpeedStudsPerSecond = 4
Config.MaxOnPath = 12

-- Rarity roll weights (relative; they do not need to sum to 100).
Config.RarityWeights = {
	Common = 40,
	Rare = 30,
	Epic = 15,
	Legendary = 9,
	Mythic = 4,
	Secret = 2,
}

-- Mutations -------------------------------------------------------------------
Config.GoldenChance = 0.10
Config.GoldenMultiplier = 2
Config.DiamondChance = 0.03
Config.DiamondMultiplier = 3

-- Bases, locking and stealing -------------------------------------------------
Config.BaseCount = 4
Config.SlotsPerBase = 8
Config.LockDurationSeconds = 30
Config.LockRechargeSeconds = 60
Config.StealCooldownSeconds = 15

-- Gull Storm ------------------------------------------------------------------
Config.StormFirstAtSeconds = 30
Config.StormIntervalSeconds = 100
Config.StormWarnSeconds = 10
Config.StormDurationSeconds = 12
Config.GullsPerStorm = 8

-- Rebirth ---------------------------------------------------------------------
Config.RebirthBaseRequirement = 10000
Config.RebirthRequirementGrowth = 2
Config.RebirthBonusPerRebirth = 0.5

-- Sound pacing ----------------------------------------------------------------
Config.MoneyTickMinIntervalSeconds = 5
Config.CharacterClipSeconds = 4

-- Carrying --------------------------------------------------------------------
Config.CarryHeightAboveHead = 4.5

local weightTotal = 0
for _, weight in pairs(Config.RarityWeights) do
	weightTotal += weight
end
assert(weightTotal > 0, "Config: rarity weights must sum to more than zero")

return Config
