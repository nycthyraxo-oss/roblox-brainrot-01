-- Brainrot Stealer: bases, carrying, placing, stealing and locks.
--
-- One state table per player: which base they own, what they carry overhead,
-- what sits on each of the eight pedestals, lock timers and steal count.
-- Models are built by BrainrotFactory; this service moves them around.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local Config = require(Shared:WaitForChild("Config"))

local BaseService = {}

local ctx: any = nil
local states: { [Player]: any } = {}
local baseOwners: { [number]: Player? } = { nil, nil, nil, nil }
local pedestalDebounce: { [number]: number } = {}

local function now(): number
	return os.clock()
end

function BaseService.Init(context: any)
	ctx = context
	for index, base in ipairs(ctx.world.Bases) do
		base.PlaceZone.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				BaseService._tryPlace(player, index)
			end
		end)
		for slot, pedestal in ipairs(base.Pedestals) do
			pedestal.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					BaseService._trySteal(player, index, slot)
				end
			end)
		end
	end
end

function BaseService.getState(player: Player): any
	local state = states[player]
	if not state then
		state = {
			baseIndex = nil,
			carrying = nil,
			placed = {},
			lockUntil = 0,
			nextLockAt = 0,
			lastStealAt = -math.huge,
			steals = 0,
		}
		states[player] = state
	end
	return state
end

function BaseService.assignBase(player: Player): number?
	local state = BaseService.getState(player)
	if state.baseIndex then
		return state.baseIndex
	end
	for index = 1, 4 do
		if baseOwners[index] == nil then
			baseOwners[index] = player
			state.baseIndex = index
			BaseService._updateSign(index)
			return index
		end
	end
	return nil
end

function BaseService.freeBase(player: Player)
	local state = states[player]
	if not state then
		return
	end
	BaseService.clearBaseContents(player)
	if state.baseIndex then
		baseOwners[state.baseIndex] = nil
		BaseService._updateSign(state.baseIndex)
	end
	states[player] = nil
	BaseService.refreshLeaderboard()
end

function BaseService._updateSign(baseIndex: number)
	local base = ctx.world.Bases[baseIndex]
	local owner = baseOwners[baseIndex]
	if owner then
		base.SignLabel.Text = owner.DisplayName .. "'s Base"
	else
		base.SignLabel.Text = "EMPTY BASE"
	end
end

-- Carrying ----------------------------------------------------------------------

function BaseService.isCarrying(player: Player): boolean
	return BaseService.getState(player).carrying ~= nil
end

function BaseService.startCarrying(player: Player, model: Model, charId: string, mutation: string?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		model:Destroy()
		return
	end
	local body = model.PrimaryPart
	assert(body ~= nil, "BaseService: carried model has no PrimaryPart")
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.Massless = true
		end
	end
	model:PivotTo(root.CFrame * CFrame.new(0, 4.5, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = body
	model.Parent = character
	BaseService.getState(player).carrying = { model = model, charId = charId, mutation = mutation }
	ctx.progress.markOwned(player, charId)
end

-- Drops whatever the player carries (death, storm). Returns the dropped info.
function BaseService.dropCarrying(player: Player): any?
	local state = BaseService.getState(player)
	local carried = state.carrying
	if not carried then
		return nil
	end
	state.carrying = nil
	carried.model:Destroy()
	return carried
end

-- Placing ------------------------------------------------------------------------

function BaseService._tryPlace(player: Player, baseIndex: number)
	local state = BaseService.getState(player)
	if state.baseIndex ~= baseIndex or state.carrying == nil then
		return
	end
	local freeSlot: number? = nil
	for slot = 1, 8 do
		if state.placed[slot] == nil then
			freeSlot = slot
			break
		end
	end
	if freeSlot == nil then
		ctx.toast(player, "Your base is full! Sell the dream: steal a better spot... or rebirth.")
		return
	end
	local carried = state.carrying
	state.carrying = nil
	local base = ctx.world.Bases[baseIndex]
	local pedestal = base.Pedestals[freeSlot]
	local model = carried.model
	local body = model.PrimaryPart
	assert(body ~= nil, "BaseService: placed model has no PrimaryPart")
	-- Detach the carry weld, move the whole model onto the pedestal, then anchor.
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("WeldConstraint") and descendant.Part0 ~= body then
			descendant:Destroy()
		end
	end
	local pedestalTop = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
	local bodyPos = pedestalTop + Vector3.new(0, body.Size.Y / 2 + 0.15, 0)
	model:PivotTo(CFrame.lookAt(bodyPos, Vector3.new(0, bodyPos.Y, 0)))
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Massless = false
		end
	end
	model.Parent = pedestal.Parent
	local def = BrainrotCatalog.get(carried.charId)
	base.Rims[freeSlot].Color = BrainrotCatalog.RarityColors[def.rarity]
	state.placed[freeSlot] = { model = model, charId = carried.charId, mutation = carried.mutation }
	ctx.toast(player, def.name .. " placed! +" .. tostring(ctx.factory.incomeOf(def, carried.mutation)) .. "/s")
	ctx.syncPlayer(player)
end

-- Stealing ------------------------------------------------------------------------

function BaseService.isLocked(player: Player): boolean
	return now() < BaseService.getState(player).lockUntil
end

function BaseService.requestLock(player: Player)
	local state = BaseService.getState(player)
	if state.baseIndex == nil then
		return
	end
	if now() < state.nextLockAt then
		local wait = math.ceil(state.nextLockAt - now())
		ctx.toast(player, "Lock recharging... " .. wait .. "s")
		return
	end
	state.lockUntil = now() + Config.LockDurationSeconds
	state.nextLockAt = now() + Config.LockRechargeSeconds
	local base = ctx.world.Bases[state.baseIndex]
	base.GatewayBeam.Color = Color3.fromRGB(255, 50, 50)
	task.delay(Config.LockDurationSeconds, function()
		if base.GatewayBeam and base.GatewayBeam.Parent then
			base.GatewayBeam.Color = base.Color
		end
	end)
	ctx.toast(player, "Base locked for " .. Config.LockDurationSeconds .. "s!")
	ctx.syncPlayer(player)
end

function BaseService._trySteal(thief: Player, baseIndex: number, slot: number)
	local debounceKey = baseIndex * 100 + slot
	if pedestalDebounce[debounceKey] and now() - pedestalDebounce[debounceKey] < 0.5 then
		return
	end
	pedestalDebounce[debounceKey] = now()

	local victim = baseOwners[baseIndex]
	if victim == nil or victim == thief then
		return
	end
	local victimState = BaseService.getState(victim)
	local target = victimState.placed[slot]
	if target == nil then
		return
	end
	local thiefState = BaseService.getState(thief)
	if thiefState.carrying ~= nil then
		ctx.toast(thief, "Your hands are full!")
		return
	end
	if now() - thiefState.lastStealAt < Config.StealCooldownSeconds then
		local wait = math.ceil(Config.StealCooldownSeconds - (now() - thiefState.lastStealAt))
		ctx.toast(thief, "Steal cooldown: " .. wait .. "s")
		return
	end
	if BaseService.isLocked(victim) then
		ctx.toast(thief, "That base is locked!")
		return
	end

	victimState.placed[slot] = nil
	ctx.world.Bases[baseIndex].Rims[slot].Color = Color3.fromRGB(140, 145, 155)
	thiefState.lastStealAt = now()
	thiefState.steals += 1

	-- Hand the stolen brainrot to the thief as a fresh carried model.
	target.model:Destroy()
	local carriedModel = ctx.factory.build(target.charId, target.mutation, false)
	BaseService.startCarrying(thief, carriedModel, target.charId, target.mutation)

	local def = BrainrotCatalog.get(target.charId)
	ctx.toast(thief, "You stole " .. def.name .. "!")
	ctx.toast(victim, thief.DisplayName .. " stole your " .. def.name .. "!")
	ctx.progress.checkAchievements(thief)
	BaseService.refreshLeaderboard()
	ctx.syncPlayer(thief)
	ctx.syncPlayer(victim)
end

-- Income, queries, cleanup ----------------------------------------------------------

function BaseService.incomePerSecond(player: Player): number
	local state = BaseService.getState(player)
	local total = 0
	for _, entry in pairs(state.placed) do
		local def = BrainrotCatalog.get(entry.charId)
		total += ctx.factory.incomeOf(def, entry.mutation)
	end
	return total * ctx.economy.getState(player).multiplier
end

function BaseService.placedCount(player: Player): number
	local count = 0
	for _ in pairs(BaseService.getState(player).placed) do
		count += 1
	end
	return count
end

function BaseService.stealsOf(player: Player): number
	return BaseService.getState(player).steals
end

function BaseService.isInsideOwnBase(player: Player): boolean
	local state = BaseService.getState(player)
	if state.baseIndex == nil then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local center = ctx.world.Bases[state.baseIndex].Center
	local pos = root.Position
	return math.abs(pos.X - center.X) <= 16 and math.abs(pos.Z - center.Z) <= 13
end

function BaseService.carriers(): { Player }
	local result = {}
	for player, state in pairs(states) do
		if state.carrying ~= nil then
			table.insert(result, player)
		end
	end
	return result
end

function BaseService.clearBaseContents(player: Player)
	local state = BaseService.getState(player)
	if state.carrying then
		state.carrying.model:Destroy()
		state.carrying = nil
	end
	for slot, entry in pairs(state.placed) do
		entry.model:Destroy()
		if state.baseIndex then
			ctx.world.Bases[state.baseIndex].Rims[slot].Color = Color3.fromRGB(140, 145, 155)
		end
	end
	state.placed = {}
end

function BaseService.refreshLeaderboard()
	local rows = {}
	for player, state in pairs(states) do
		table.insert(rows, { name = player.DisplayName, steals = state.steals })
	end
	table.sort(rows, function(a, b)
		return a.steals > b.steals
	end)
	for row = 1, 4 do
		local entry = rows[row]
		local label = ctx.world.LeaderboardRows[row]
		if entry and entry.steals > 0 then
			label.Text = row .. ". " .. entry.name .. " - " .. entry.steals
		else
			label.Text = row .. ". ---"
		end
	end
end

return BaseService
