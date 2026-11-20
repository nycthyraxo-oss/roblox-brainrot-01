-- Brainrot Stealer: codex (seen/owned) and achievements, server-authoritative.
-- Achievement rewards are cash that does NOT count toward lifetime earnings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Achievements = require(Shared:WaitForChild("Achievements"))
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))

local ProgressService = {}

local ctx: any = nil
local states: { [Player]: any } = {}

function ProgressService.Init(context: any)
	ctx = context
end

function ProgressService.getState(player: Player): any
	local state = states[player]
	if not state then
		state = { seen = {}, owned = {}, achievements = {} }
		states[player] = state
	end
	return state
end

function ProgressService.clearPlayer(player: Player)
	states[player] = nil
end

function ProgressService.syncCodex(player: Player)
	local state = ProgressService.getState(player)
	ctx.remotes.CodexSync:FireClient(player, {
		seen = state.seen,
		owned = state.owned,
		achievements = state.achievements,
	})
end

function ProgressService.markSeen(player: Player, charId: string)
	local state = ProgressService.getState(player)
	if not state.seen[charId] then
		state.seen[charId] = true
		ProgressService.syncCodex(player)
	end
end

function ProgressService.markSeenAll(charId: string)
	for _, player in ipairs(Players:GetPlayers()) do
		ProgressService.markSeen(player, charId)
	end
end

function ProgressService.markOwned(player: Player, charId: string)
	local state = ProgressService.getState(player)
	state.seen[charId] = true
	if not state.owned[charId] then
		state.owned[charId] = true
		ProgressService.syncCodex(player)
		ProgressService.checkAchievements(player)
	end
end

function ProgressService.ownedCount(player: Player): number
	local count = 0
	for _ in pairs(ProgressService.getState(player).owned) do
		count += 1
	end
	return count
end

function ProgressService.grantAchievement(player: Player, achievementId: string)
	local state = ProgressService.getState(player)
	if state.achievements[achievementId] then
		return
	end
	local def = Achievements.get(achievementId)
	if def == nil then
		return
	end
	state.achievements[achievementId] = true
	ctx.economy.addCash(player, def.reward, false)
	ctx.toast(player, "Achievement: " .. def.name .. "! +" .. ctx.economy.formatCash(def.reward))
	ProgressService.syncCodex(player)
	ctx.syncPlayer(player)
end

local function ownsRarity(player: Player, rarity: string): boolean
	local state = ProgressService.getState(player)
	for charId in pairs(state.owned) do
		local def = BrainrotCatalog.get(charId)
		if def and def.rarity == rarity then
			return true
		end
	end
	return false
end

function ProgressService.checkAchievements(player: Player)
	local economy = ctx.economy.getState(player)
	local owned = ProgressService.ownedCount(player)
	if economy.purchases >= 1 then
		ProgressService.grantAchievement(player, "first_purchase")
	end
	if economy.purchases >= 10 then
		ProgressService.grantAchievement(player, "buyer_10")
	end
	if owned >= 5 then
		ProgressService.grantAchievement(player, "collector_5")
	end
	if owned >= 10 then
		ProgressService.grantAchievement(player, "collector_10")
	end
	if economy.lifetimeTotal >= 10000 then
		ProgressService.grantAchievement(player, "earn_10k")
	end
	if economy.lifetimeTotal >= 100000 then
		ProgressService.grantAchievement(player, "earn_100k")
	end
	if ownsRarity(player, "Legendary") then
		ProgressService.grantAchievement(player, "legendary_owner")
	end
	if ownsRarity(player, "Secret") then
		ProgressService.grantAchievement(player, "secret_owner")
	end
	if economy.rebirths >= 1 then
		ProgressService.grantAchievement(player, "first_rebirth")
	end
end

return ProgressService
