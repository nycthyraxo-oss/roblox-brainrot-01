-- Brainrot Stealer: server entry point. Creates the remotes, builds the
-- park, starts every service and owns the income tick. Session-only game:
-- no DataStore, everything resets when the server empties.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent
local MapBuilder = require(Server:WaitForChild("MapBuilder"))
local BrainrotFactory = require(Server:WaitForChild("BrainrotFactory"))
local EconomyService = require(Server:WaitForChild("EconomyService"))
local BaseService = require(Server:WaitForChild("BaseService"))
local SpawnerService = require(Server:WaitForChild("SpawnerService"))
local ThreatService = require(Server:WaitForChild("ThreatService"))
local ProgressService = require(Server:WaitForChild("ProgressService"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

-- Bright, saturated carnival light.
Lighting.Brightness = 2.3
Lighting.ClockTime = 14
local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
if correction == nil then
	correction = Instance.new("ColorCorrectionEffect")
	correction.Parent = Lighting
end
correction.Saturation = 0.22
correction.Contrast = 0.08

-- Remotes (all client-visible events live here).
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "BrainrotRemotes"
remotesFolder.Parent = ReplicatedStorage

local function makeRemote(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local remotes = {
	StateSync = makeRemote("StateSync"),
	SoundEvent = makeRemote("SoundEvent"),
	ToastEvent = makeRemote("ToastEvent"),
	StormEvent = makeRemote("StormEvent"),
	CodexSync = makeRemote("CodexSync"),
	NextBrainrot = makeRemote("NextBrainrot"),
	LockBaseRequest = makeRemote("LockBaseRequest"),
	RebirthRequest = makeRemote("RebirthRequest"),
}

local ctx: any = {
	factory = BrainrotFactory,
	economy = EconomyService,
	base = BaseService,
	spawner = SpawnerService,
	threat = ThreatService,
	progress = ProgressService,
	remotes = remotes,
}

function ctx.toast(player: Player, text: string)
	remotes.ToastEvent:FireClient(player, text)
end

function ctx.sound(player: Player, charId: string)
	remotes.SoundEvent:FireClient(player, charId)
end

function ctx.syncPlayer(player: Player)
	local economy = EconomyService.getState(player)
	local baseState = BaseService.getState(player)
	local carryingId: string? = nil
	if baseState.carrying then
		carryingId = baseState.carrying.charId
	end
	remotes.StateSync:FireClient(player, {
		cash = economy.cash,
		lifetimeRun = economy.lifetimeRun,
		rebirthRequirement = EconomyService.rebirthRequirement(player),
		rebirths = economy.rebirths,
		multiplier = economy.multiplier,
		incomePerSecond = BaseService.incomePerSecond(player),
		baseIndex = baseState.baseIndex,
		placedCount = BaseService.placedCount(player),
		steals = baseState.steals,
		collected = ProgressService.ownedCount(player),
		carrying = carryingId,
		lockRemaining = math.max(0, baseState.lockUntil - os.clock()),
		lockRechargeRemaining = math.max(0, baseState.nextLockAt - os.clock()),
	})
end

-- Build the park, then start services with the shared context.
ctx.world = MapBuilder.Init()
EconomyService.Init(ctx)
ProgressService.Init(ctx)
BaseService.Init(ctx)
SpawnerService.Init(ctx)
ThreatService.Init(ctx)

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		if BaseService.dropCarrying(player) then
			ctx.toast(player, "You dropped your brainrot!")
			ctx.syncPlayer(player)
		end
	end)
end

local function onPlayerAdded(player: Player)
	local baseIndex = BaseService.assignBase(player)
	if baseIndex == nil then
		ctx.toast(player, "All four bases are taken - spectate and steal the show later!")
	else
		ctx.toast(player, "Welcome! Buy a brainrot on the path, carry it to Base " .. baseIndex .. ".")
	end
	ProgressService.syncCodex(player)
	ctx.syncPlayer(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	BaseService.refreshLeaderboard()
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	BaseService.freeBase(player)
	EconomyService.clearPlayer(player)
	ProgressService.clearPlayer(player)
end)

remotes.LockBaseRequest.OnServerEvent:Connect(function(player)
	BaseService.requestLock(player)
end)

remotes.RebirthRequest.OnServerEvent:Connect(function(player)
	if not EconomyService.canRebirth(player) then
		ctx.toast(player, "Rebirth needs " .. EconomyService.formatCash(EconomyService.rebirthRequirement(player)) .. " earned this run.")
		return
	end
	EconomyService.applyRebirth(player)
	BaseService.clearBaseContents(player)
	ProgressService.checkAchievements(player)
	local state = EconomyService.getState(player)
	ctx.toast(player, "Reborn! Income x" .. tostring(state.multiplier) .. " forever.")
	ctx.syncPlayer(player)
end)

-- Income tick: pay every MoneyTickMinIntervalSeconds, sync every second so
-- HUD timers (lock countdowns) stay smooth.
task.spawn(function()
	local sincePay = 0
	while true do
		task.wait(1)
		sincePay += 1
		local paying = sincePay >= Config.MoneyTickMinIntervalSeconds
		if paying then
			sincePay = 0
		end
		for _, player in ipairs(Players:GetPlayers()) do
			if paying then
				local perSecond = BaseService.incomePerSecond(player)
				if perSecond > 0 then
					EconomyService.addCash(player, perSecond * Config.MoneyTickMinIntervalSeconds, true)
					ProgressService.checkAchievements(player)
				end
			end
			ctx.syncPlayer(player)
		end
	end
end)
