-- Brainrot Stealer: the Gull Storm. Every so often the gulls come:
-- carriers caught outside their own base drop their brainrot, the path
-- clears, and anyone still carrying when it ends earns Storm Survivor.
-- Gull bodies are tweened, never whole models.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local ThreatService = {}

local ctx: any = nil
local stormActive = false
local gullFolder: Folder? = nil

local function buildGull(): Model
	local model = Instance.new("Model")
	model.Name = "Gull"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(1.6, 1.2, 2.4)
	body.Color = Color3.fromRGB(245, 245, 245)
	body.Material = Enum.Material.SmoothPlastic
	body.Shape = Enum.PartType.Ball
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.Parent = model
	model.PrimaryPart = body
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(0.8, 0.8, 0.8)
	head.Color = Color3.fromRGB(245, 245, 245)
	head.Shape = Enum.PartType.Ball
	head.Anchored = true
	head.CanCollide = false
	head.CanTouch = false
	head.CanQuery = false
	head.CFrame = body.CFrame * CFrame.new(0, 0.4, -1.3)
	head.Parent = model
	local beak = Instance.new("Part")
	beak.Name = "Beak"
	beak.Size = Vector3.new(0.3, 0.25, 0.7)
	beak.Color = Color3.fromRGB(255, 170, 40)
	beak.Shape = Enum.PartType.Wedge
	beak.Anchored = true
	beak.CanCollide = false
	beak.CanTouch = false
	beak.CanQuery = false
	beak.CFrame = body.CFrame * CFrame.new(0, 0.35, -1.9)
	beak.Parent = model
	for _, side in ipairs({ -1, 1 }) do
		local wing = Instance.new("Part")
		wing.Name = "Wing"
		wing.Size = Vector3.new(2.6, 0.15, 1.1)
		wing.Color = Color3.fromRGB(220, 225, 235)
		wing.Anchored = true
		wing.CanCollide = false
		wing.CanTouch = false
		wing.CanQuery = false
		wing.CFrame = body.CFrame * CFrame.new(side * 1.8, 0.5, 0) * CFrame.Angles(0, 0, side * math.rad(18))
		wing.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = wing
		weld.Parent = wing
	end
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = body
	headWeld.Part1 = head
	headWeld.Parent = head
	local beakWeld = Instance.new("WeldConstraint")
	beakWeld.Part0 = body
	beakWeld.Part1 = beak
	beakWeld.Parent = beak
	return model
end

local function flyGulls(duration: number)
	local rng = Random.new()
	for _ = 1, Config.GullsPerStorm do
		local gull = buildGull()
		local body = gull.PrimaryPart
		assert(body ~= nil, "ThreatService: gull has no PrimaryPart")
		local startX = rng:NextNumber(-220, 220)
		local startZ = rng:NextNumber(-220, 220)
		local height = rng:NextNumber(18, 32)
		local start = Vector3.new(startX, -5 + height, startZ)
		local finish = Vector3.new(-startX, -5 + height + rng:NextNumber(-4, 4), -startZ)
		gull:PivotTo(CFrame.lookAt(start, finish))
		gull.Parent = gullFolder
		local tween = TweenService:Create(body, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(finish, finish + (finish - start)) })
		tween.Completed:Connect(function()
			gull:Destroy()
		end)
		tween:Play()
	end
end

local function runStorm()
	if stormActive then
		return
	end
	stormActive = true
	ctx.remotes.StormEvent:FireAllClients("start", Config.StormDurationSeconds)

	-- Carriers outside their own base drop what they carry.
	local sheltered: { [Player]: boolean } = {}
	for _, player in ipairs(ctx.base.carriers()) do
		if ctx.base.isInsideOwnBase(player) then
			sheltered[player] = true
		else
			ctx.base.dropCarrying(player)
			ctx.toast(player, "The gulls snatched your brainrot!")
			ctx.syncPlayer(player)
		end
	end
	ctx.spawner.clearPath()
	flyGulls(Config.StormDurationSeconds)

	task.wait(Config.StormDurationSeconds)

	-- Anyone sheltered and still carrying survived the storm.
	for player in pairs(sheltered) do
		if player.Parent and ctx.base.isCarrying(player) then
			ctx.progress.grantAchievement(player, "storm_survivor")
		end
	end
	ctx.remotes.StormEvent:FireAllClients("end", 0)
	stormActive = false
end

local function runWarnedStorm()
	if stormActive then
		return
	end
	ctx.remotes.StormEvent:FireAllClients("warn", Config.StormWarnSeconds)
	task.wait(Config.StormWarnSeconds)
	runStorm()
end

-- TOUR hook: start a storm right away (no warning delay).
function ThreatService.forceStorm(_arg: any)
	task.spawn(runStorm)
end

function ThreatService.isStorming(): boolean
	return stormActive
end

function ThreatService.Init(context: any)
	ctx = context
	gullFolder = Instance.new("Folder")
	gullFolder.Name = "Gulls"
	gullFolder.Parent = Workspace
	task.spawn(function()
		task.wait(Config.StormFirstAtSeconds)
		while true do
			runWarnedStorm()
			task.wait(Config.StormIntervalSeconds)
		end
	end)
end

return ThreatService
