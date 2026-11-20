-- Brainrot Stealer: cash, lifetime earnings and rebirth math.
-- Session-only: everything lives in this table, nothing is saved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local EconomyService = {}

local states: { [Player]: any } = {}

function EconomyService.Init(_ctx: any)
	-- No remotes of its own; MainServer drives the income tick and syncs.
end

function EconomyService.getState(player: Player): any
	local state = states[player]
	if not state then
		state = {
			cash = Config.StartCash,
			lifetimeTotal = 0,
			lifetimeRun = 0,
			rebirths = 0,
			multiplier = 1,
			purchases = 0,
		}
		states[player] = state
	end
	return state
end

function EconomyService.clearPlayer(player: Player)
	states[player] = nil
end

function EconomyService.addCash(player: Player, amount: number, countsToLifetime: boolean)
	local state = EconomyService.getState(player)
	state.cash += amount
	if countsToLifetime then
		state.lifetimeTotal += amount
		state.lifetimeRun += amount
	end
end

function EconomyService.spendCash(player: Player, amount: number): boolean
	local state = EconomyService.getState(player)
	if state.cash < amount then
		return false
	end
	state.cash -= amount
	return true
end

function EconomyService.recordPurchase(player: Player)
	EconomyService.getState(player).purchases += 1
end

function EconomyService.rebirthRequirement(player: Player): number
	local state = EconomyService.getState(player)
	return Config.RebirthBaseRequirement * (Config.RebirthRequirementGrowth ^ state.rebirths)
end

function EconomyService.canRebirth(player: Player): boolean
	local state = EconomyService.getState(player)
	return state.lifetimeRun >= EconomyService.rebirthRequirement(player)
end

-- Applies the rebirth: cash and run earnings reset, multiplier grows.
-- Clearing the physical base is BaseService's job (MainServer calls both).
function EconomyService.applyRebirth(player: Player)
	local state = EconomyService.getState(player)
	state.rebirths += 1
	state.multiplier = 1 + Config.RebirthBonusPerRebirth * state.rebirths
	state.cash = Config.StartCash
	state.lifetimeRun = 0
end

function EconomyService.formatCash(amount: number): string
	local whole = math.floor(amount)
	local text = tostring(whole)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end

return EconomyService
