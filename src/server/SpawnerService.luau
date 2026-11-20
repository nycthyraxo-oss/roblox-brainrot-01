-- Brainrot Stealer: spawns brainrots at the portal and walks them around
-- the loop. The PrimaryPart Body is tweened, never the Model itself.
-- Touching a walking brainrot buys it (if you can afford it and your
-- hands are empty).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local Config = require(Shared:WaitForChild("Config"))

local SpawnerService = {}

local ctx: any = nil
local rng = Random.new()
local onPath: { [Model]: any } = {}
local pathFolder: Folder? = nil
local nextSpec: any = nil

local function pickSpec(): any
	local totalWeight = 0
	for _, rarity in ipairs(BrainrotCatalog.RarityOrder) do
		totalWeight += Config.RarityWeights[rarity]
	end
	local roll = rng:NextNumber(0, totalWeight)
	local chosenRarity = BrainrotCatalog.RarityOrder[#BrainrotCatalog.RarityOrder]
	for _, rarity in ipairs(BrainrotCatalog.RarityOrder) do
		roll -= Config.RarityWeights[rarity]
		if roll <= 0 then
			chosenRarity = rarity
			break
		end
	end
	local pool = BrainrotCatalog.ofRarity(chosenRarity)
	local def = pool[rng:NextInteger(1, #pool)]
	return { charId = def.id, mutation = ctx.factory.rollMutation(rng) }
end

local function broadcastNext()
	if nextSpec then
		local def = BrainrotCatalog.get(nextSpec.charId)
		ctx.remotes.NextBrainrot:FireAllClients({
			charId = def.id,
			name = def.name,
			rarity = def.rarity,
			price = def.price,
			income = ctx.factory.incomeOf(def, nextSpec.mutation),
			mutation = nextSpec.mutation,
		})
	end
end

local function removeFromPath(model: Model)
	local entry = onPath[model]
	if entry then
		if entry.tween then
			entry.tween:Cancel()
		end
		onPath[model] = nil
	end
	model:Destroy()
end

local function walkLeg(model: Model, entry: any, legIndex: number)
	if onPath[model] == nil then
		return
	end
	local waypoints = ctx.world.PathWaypoints
	if legIndex > #waypoints - 1 then
		removeFromPath(model)
		return
	end
	local body = model.PrimaryPart
	if body == nil then
		removeFromPath(model)
		return
	end
	local from = waypoints[legIndex]
	local to = waypoints[legIndex + 1]
	local lift = body.Size.Y / 2 + 0.4
	local targetPos = to + Vector3.new(0, lift, 0)
	local distance = (to - from).Magnitude
	local duration = distance / Config.WalkSpeedStudsPerSecond
	local targetCFrame = CFrame.lookAt(targetPos, targetPos + (to - from))
	local tween = TweenService:Create(body, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = targetCFrame })
	entry.tween = tween
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			walkLeg(model, entry, legIndex + 1)
		end
	end)
	tween:Play()
end

local function onBrainrotTouched(model: Model, hit: BasePart)
	local entry = onPath[model]
	if entry == nil then
		return
	end
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if player == nil then
		return
	end
	if ctx.base.isCarrying(player) then
		ctx.toast(player, "Your hands are full!")
		return
	end
	local def = BrainrotCatalog.get(entry.charId)
	if not ctx.economy.spendCash(player, def.price) then
		ctx.toast(player, "Need " .. ctx.economy.formatCash(def.price) .. " for " .. def.name .. "!")
		return
	end
	ctx.economy.recordPurchase(player)
	removeFromPath(model)
	local carriedModel = ctx.factory.build(entry.charId, entry.mutation, false)
	ctx.base.startCarrying(player, carriedModel, entry.charId, entry.mutation)
	ctx.sound(player, entry.charId)
	ctx.toast(player, "Bought " .. def.name .. "! Carry it to your base.")
	ctx.progress.checkAchievements(player)
	ctx.syncPlayer(player)
end

local function spawnOne(spec: any)
	local model = ctx.factory.build(spec.charId, spec.mutation, true)
	local body = model.PrimaryPart
	assert(body ~= nil, "SpawnerService: path model has no PrimaryPart")
	body.CanTouch = true
	local start = ctx.world.PathWaypoints[1]
	local lift = body.Size.Y / 2 + 0.4
	local startPos = start + Vector3.new(0, lift, 0)
	local second = ctx.world.PathWaypoints[2]
	model:PivotTo(CFrame.lookAt(startPos, startPos + (second - start)))
	model.Parent = pathFolder
	local entry = { charId = spec.charId, mutation = spec.mutation, tween = nil }
	onPath[model] = entry
	body.Touched:Connect(function(hit)
		onBrainrotTouched(model, hit)
	end)
	ctx.progress.markSeenAll(spec.charId)
	walkLeg(model, entry, 1)
end

function SpawnerService.Init(context: any)
	ctx = context
	pathFolder = Instance.new("Folder")
	pathFolder.Name = "PathBrainrots"
	pathFolder.Parent = Workspace
	nextSpec = pickSpec()
	broadcastNext()
	task.spawn(function()
		while true do
			task.wait(Config.SpawnIntervalSeconds)
			if SpawnerService.pathCount() < Config.MaxOnPath then
				local spec = nextSpec
				nextSpec = pickSpec()
				spawnOne(spec)
				broadcastNext()
			end
		end
	end)
end

function SpawnerService.pathCount(): number
	local count = 0
	for _ in pairs(onPath) do
		count += 1
	end
	return count
end

-- The Gull Storm clears the path.
function SpawnerService.clearPath()
	local models = {}
	for model in pairs(onPath) do
		table.insert(models, model)
	end
	for _, model in ipairs(models) do
		removeFromPath(model)
	end
end

return SpawnerService
