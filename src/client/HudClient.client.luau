-- Brainrot Stealer: all HUD. Cash top-right, NEXT bar top-center, MY BASE
-- panel (collapsible), LOCK BASE / CODEX / REBIRTH buttons, storm banner,
-- toasts, and the 720x512 codex with ViewportFrame photos of all 18.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local BrainrotModelBuilder = require(Shared:WaitForChild("BrainrotModelBuilder"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local stateSync = remotes:WaitForChild("StateSync")
local toastEvent = remotes:WaitForChild("ToastEvent")
local stormEvent = remotes:WaitForChild("StormEvent")
local codexSync = remotes:WaitForChild("CodexSync")
local nextBrainrot = remotes:WaitForChild("NextBrainrot")
local lockRequest = remotes:WaitForChild("LockBaseRequest")
local rebirthRequest = remotes:WaitForChild("RebirthRequest")

local GREEN = Color3.fromRGB(60, 200, 90)
local DARK = Color3.fromRGB(20, 22, 32)
local WHITE = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 220, 90)

local function formatCash(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end

local gui = Instance.new("ScreenGui")
gui.Name = "HudGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function makeLabel(parent: Instance, name: string, size: UDim2, position: UDim2, text: string, color: Color3, bold: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, name: string, size: UDim2, position: UDim2, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = GREEN
	button.TextColor3 = WHITE
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Text = text
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

local function addPanelStroke(frame: Frame, color: Color3)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
end

-- Cash (top-right, clear of the Roblox menu in the top-left).
local cashFrame = Instance.new("Frame")
cashFrame.Name = "CashFrame"
cashFrame.Size = UDim2.new(0, 220, 0, 66)
cashFrame.AnchorPoint = Vector2.new(1, 0)
cashFrame.Position = UDim2.new(1, -12, 0, 12)
cashFrame.BackgroundColor3 = DARK
cashFrame.BackgroundTransparency = 0.2
cashFrame.Parent = gui
addPanelStroke(cashFrame, GOLD)
local cashLabel = makeLabel(cashFrame, "CashLabel", UDim2.new(1, 0, 0, 38), UDim2.new(0, 0, 0, 2), "$100", GOLD, true)
local incomeLabel = makeLabel(cashFrame, "IncomeLabel", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 40), "+$0/s", Color3.fromRGB(140, 255, 160), false)

-- NEXT bar (top-center).
local nextFrame = Instance.new("Frame")
nextFrame.Name = "NextFrame"
nextFrame.Size = UDim2.new(0, 360, 0, 52)
nextFrame.AnchorPoint = Vector2.new(0.5, 0)
nextFrame.Position = UDim2.new(0.5, 0, 0, 12)
nextFrame.BackgroundColor3 = DARK
nextFrame.BackgroundTransparency = 0.2
nextFrame.Parent = gui
addPanelStroke(nextFrame, WHITE)
local nextLabel = makeLabel(nextFrame, "NextLabel", UDim2.new(1, -8, 1, 0), UDim2.new(0, 4, 0, 0), "NEXT: ...", WHITE, true)
local nextStroke = nextFrame:FindFirstChildOfClass("UIStroke")

-- Storm banner (under the NEXT bar).
local stormFrame = Instance.new("Frame")
stormFrame.Name = "StormFrame"
stormFrame.Size = UDim2.new(0, 440, 0, 48)
stormFrame.AnchorPoint = Vector2.new(0.5, 0)
stormFrame.Position = UDim2.new(0.5, 0, 0, 72)
stormFrame.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
stormFrame.BackgroundTransparency = 0.1
stormFrame.Visible = false
stormFrame.Parent = gui
addPanelStroke(stormFrame, WHITE)
local stormLabel = makeLabel(stormFrame, "StormLabel", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "GULL STORM!", WHITE, true)

-- MY BASE panel (left side, collapsible).
local baseFrame = Instance.new("Frame")
baseFrame.Name = "MyBaseFrame"
baseFrame.Size = UDim2.new(0, 250, 0, 210)
baseFrame.Position = UDim2.new(0, 12, 0, 120)
baseFrame.BackgroundColor3 = DARK
baseFrame.BackgroundTransparency = 0.2
baseFrame.Parent = gui
addPanelStroke(baseFrame, WHITE)
local baseHeader = makeButton(baseFrame, "BaseHeader", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 0), "MY BASE v")
local baseRows = Instance.new("Frame")
baseRows.Name = "BaseRows"
baseRows.Size = UDim2.new(1, -12, 0, 160)
baseRows.Position = UDim2.new(0, 6, 0, 48)
baseRows.BackgroundTransparency = 1
baseRows.Parent = baseFrame
local rowBase = makeLabel(baseRows, "RowBase", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 0), "Base: -", WHITE, false)
rowBase.TextXAlignment = Enum.TextXAlignment.Left
local rowPlaced = makeLabel(baseRows, "RowPlaced", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 28), "Placed: 0/8", WHITE, false)
rowPlaced.TextXAlignment = Enum.TextXAlignment.Left
local rowIncome = makeLabel(baseRows, "RowIncome", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 56), "Income: $0/s", WHITE, false)
rowIncome.TextXAlignment = Enum.TextXAlignment.Left
local rowSteals = makeLabel(baseRows, "RowSteals", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 84), "Stolen: 0", WHITE, false)
rowSteals.TextXAlignment = Enum.TextXAlignment.Left
local rowCollected = makeLabel(baseRows, "RowCollected", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 112), "Collected: 0/18", WHITE, false)
rowCollected.TextXAlignment = Enum.TextXAlignment.Left
local rowCarrying = makeLabel(baseRows, "RowCarrying", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 140), "Carrying: -", WHITE, false)
rowCarrying.TextXAlignment = Enum.TextXAlignment.Left

local baseCollapsed = false
baseHeader.Activated:Connect(function()
	baseCollapsed = not baseCollapsed
	baseRows.Visible = not baseCollapsed
	baseFrame.Size = UDim2.new(0, 250, 0, if baseCollapsed then 44 else 210)
	baseHeader.Text = if baseCollapsed then "MY BASE >" else "MY BASE v"
end)

-- Rebirth progress + action buttons (bottom-center).
local rebirthFrame = Instance.new("Frame")
rebirthFrame.Name = "RebirthFrame"
rebirthFrame.Size = UDim2.new(0, 320, 0, 40)
rebirthFrame.AnchorPoint = Vector2.new(0.5, 1)
rebirthFrame.Position = UDim2.new(0.5, 0, 1, -66)
rebirthFrame.BackgroundColor3 = DARK
rebirthFrame.BackgroundTransparency = 0.2
rebirthFrame.Parent = gui
addPanelStroke(rebirthFrame, Color3.fromRGB(170, 70, 255))
local rebirthBar = Instance.new("Frame")
rebirthBar.Name = "RebirthBar"
rebirthBar.Size = UDim2.new(0, 0, 1, 0)
rebirthBar.BackgroundColor3 = Color3.fromRGB(170, 70, 255)
rebirthBar.BorderSizePixel = 0
rebirthBar.Parent = rebirthFrame
local rebirthLabel = makeLabel(rebirthFrame, "RebirthLabel", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "Rebirth: $0 / $10,000", WHITE, true)

local buttonRow = Instance.new("Frame")
buttonRow.Name = "ButtonRow"
buttonRow.Size = UDim2.new(0, 480, 0, 46)
buttonRow.AnchorPoint = Vector2.new(0.5, 1)
buttonRow.Position = UDim2.new(0.5, 0, 1, -12)
buttonRow.BackgroundTransparency = 1
buttonRow.Parent = gui
local lockButton = makeButton(buttonRow, "LockButton", UDim2.new(0, 150, 0, 46), UDim2.new(0, 0, 0, 0), "LOCK BASE [L]")
local codexButton = makeButton(buttonRow, "CodexButton", UDim2.new(0, 150, 0, 46), UDim2.new(0, 165, 0, 0), "CODEX [C]")
local rebirthButton = makeButton(buttonRow, "RebirthButton", UDim2.new(0, 150, 0, 46), UDim2.new(0, 330, 0, 0), "REBIRTH [R]")
rebirthButton.BackgroundColor3 = Color3.fromRGB(120, 120, 130)

-- Toasts (stack upward above the rebirth bar).
local toastFrame = Instance.new("Frame")
toastFrame.Name = "ToastFrame"
toastFrame.Size = UDim2.new(0, 520, 0, 200)
toastFrame.AnchorPoint = Vector2.new(0.5, 1)
toastFrame.Position = UDim2.new(0.5, 0, 1, -116)
toastFrame.BackgroundTransparency = 1
toastFrame.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 6)
toastLayout.Parent = toastFrame

-- Toast spam guard: server touch events can fire the same message
-- many times a second (e.g. "Your hands are full!" while carrying).
-- Identical text within 2.5s is dropped; at most 4 toasts visible.
local lastToastAt: { [string]: number } = {}
local activeToasts: { TextLabel } = {}

local function showToast(text: string)
	local now = os.clock()
	local last = lastToastAt[text]
	if last and now - last < 2.5 then
		return
	end
	lastToastAt[text] = now
	while #activeToasts >= 4 do
		local oldest = table.remove(activeToasts, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.Size = UDim2.new(0, 520, 0, 34)
	toast.BackgroundColor3 = DARK
	toast.BackgroundTransparency = 0.15
	toast.Text = text
	toast.TextColor3 = WHITE
	toast.TextScaled = true
	toast.Font = Enum.Font.GothamBold
	toast.Parent = toastFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toast
	table.insert(activeToasts, toast)
	task.delay(3.5, function()
		local index = table.find(activeToasts, toast)
		if index then
			table.remove(activeToasts, index)
		end
		toast:Destroy()
	end)
end

-- Codex (720x512, toggled with C or the CODEX button).
local codexFrame = Instance.new("Frame")
codexFrame.Name = "CodexFrame"
codexFrame.Size = UDim2.new(0, 720, 0, 512)
codexFrame.AnchorPoint = Vector2.new(0.5, 0.5)
codexFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
codexFrame.BackgroundColor3 = DARK
codexFrame.BackgroundTransparency = 0.05
codexFrame.Visible = false
codexFrame.Parent = gui
addPanelStroke(codexFrame, GOLD)
local codexTitle = makeLabel(codexFrame, "CodexTitle", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 4), "BRAINROT CODEX - Collected 0/18", GOLD, true)
local codexScroll = Instance.new("ScrollingFrame")
codexScroll.Name = "CodexScroll"
codexScroll.Size = UDim2.new(1, -16, 1, -100)
codexScroll.Position = UDim2.new(0, 8, 0, 52)
codexScroll.BackgroundTransparency = 1
codexScroll.BorderSizePixel = 0
codexScroll.ScrollBarThickness = 8
codexScroll.Parent = codexFrame
local codexGrid = Instance.new("UIGridLayout")
codexGrid.CellSize = UDim2.new(0, 166, 0, 170)
codexGrid.CellPadding = UDim2.new(0, 8, 0, 8)
codexGrid.Parent = codexScroll
local codexFooter = makeLabel(codexFrame, "CodexFooter", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 1, -44), "Achievements: 0/10", WHITE, false)

local codexData = { seen = {}, owned = {}, achievements = {} }

local function rebuildCodex()
	for _, child in ipairs(codexScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local collected = 0
	for _ in pairs(codexData.owned) do
		collected += 1
	end
	codexTitle.Text = "BRAINROT CODEX - Collected " .. collected .. "/" .. BrainrotCatalog.count()
	local earned = 0
	for _ in pairs(codexData.achievements) do
		earned += 1
	end
	codexFooter.Text = "Achievements: " .. earned .. "/10"

	for _, def in ipairs(BrainrotCatalog.Defs) do
		local isOwned = codexData.owned[def.id] == true
		local isSeen = codexData.seen[def.id] == true
		local cell = Instance.new("Frame")
		cell.Name = "Cell_" .. def.id
		cell.BackgroundColor3 = Color3.fromRGB(32, 36, 50)
		cell.Parent = codexScroll
		local stroke = Instance.new("UIStroke")
		stroke.Color = BrainrotCatalog.RarityColors[def.rarity]
		stroke.Thickness = 2
		stroke.Parent = cell
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = cell

		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "Photo"
		viewport.Size = UDim2.new(1, -8, 0, 92)
		viewport.Position = UDim2.new(0, 4, 0, 4)
		viewport.BackgroundColor3 = Color3.fromRGB(50, 55, 75)
		-- ViewportFrames light their contents independently of the
		-- game Lighting; set explicit bright lighting so the models
		-- are never rendered black.
		viewport.Ambient = Color3.fromRGB(200, 200, 210)
		viewport.LightColor = Color3.fromRGB(255, 250, 240)
		viewport.LightDirection = Vector3.new(-0.5, -1, -0.5)
		viewport.Parent = cell
		-- Photo setup is pcall-wrapped: one bad model must not kill
		-- the whole codex rebuild.
		pcall(function()
			local world = Instance.new("WorldModel")
			world.Parent = viewport
			local tint = if isOwned then "normal" elseif isSeen then "dim" else "silhouette"
			local model = BrainrotModelBuilder.build(def.id, tint)
			model.Parent = world
			-- GetBoundingBox returns (CFrame, Vector3): take the
			-- Vector3 center from the CFrame's Position.
			local bboxCF, size = model:GetBoundingBox()
			local center = bboxCF.Position
			-- Frame the bounding sphere so every catalog model fits:
			-- distance from the sphere radius at FOV 45, plus margin.
			local radius = size.Magnitude * 0.5
			local distance = radius * 2.6 + 0.5
			-- Models face -Z (eyes/mouth at negative Z), so the
			-- camera sits on the -Z side, raised for a 3/4 view.
			local viewDir = Vector3.new(0.55, 0.4, -1).Unit
			local camera = Instance.new("Camera")
			camera.FieldOfView = 45
			camera.CFrame = CFrame.lookAt(center + viewDir * distance, center)
			camera.Parent = viewport
			viewport.CurrentCamera = camera
		end)

		local displayName = if isSeen or isOwned then def.name else "???"
		makeLabel(cell, "Name", UDim2.new(1, -6, 0, 24), UDim2.new(0, 3, 0, 98), displayName, WHITE, true)
		local rarityText = if isSeen or isOwned then (def.rarity .. " - " .. formatCash(def.price)) else "Unknown"
		local rarityLabel = makeLabel(cell, "Rarity", UDim2.new(1, -6, 0, 20), UDim2.new(0, 3, 0, 122), rarityText, BrainrotCatalog.RarityColors[def.rarity], false)
		rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
		local incomeText = if isSeen or isOwned then ("$" .. def.income .. "/s") else "?"
		makeLabel(cell, "Income", UDim2.new(1, -6, 0, 20), UDim2.new(0, 3, 0, 142), incomeText, Color3.fromRGB(140, 255, 160), false)
		local status = if isOwned then "OWNED" elseif isSeen then "SEEN" else "???"
		local statusLabel = makeLabel(cell, "Status", UDim2.new(0, 60, 0, 18), UDim2.new(1, -64, 0, 4), status, GOLD, true)
		statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	end
	codexScroll.CanvasSize = UDim2.new(0, 0, 0, math.ceil(#BrainrotCatalog.Defs / 4) * 178)
end

local function toggleCodex()
	codexFrame.Visible = not codexFrame.Visible
	if codexFrame.Visible then
		rebuildCodex()
	end
end

codexButton.Activated:Connect(toggleCodex)
lockButton.Activated:Connect(function()
	lockRequest:FireServer()
end)
rebirthButton.Activated:Connect(function()
	rebirthRequest:FireServer()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.KeyCode == Enum.KeyCode.C then
		toggleCodex()
	elseif input.KeyCode == Enum.KeyCode.L then
		lockRequest:FireServer()
	elseif input.KeyCode == Enum.KeyCode.R then
		rebirthRequest:FireServer()
	end
end)

-- Remote handlers -----------------------------------------------------------------

stateSync.OnClientEvent:Connect(function(state: any)
	cashLabel.Text = formatCash(state.cash)
	incomeLabel.Text = "+" .. formatCash(state.incomePerSecond) .. "/s"
	rowBase.Text = "Base: " .. (if state.baseIndex then ("#" .. state.baseIndex) else "-")
	rowPlaced.Text = "Placed: " .. state.placedCount .. "/8"
	rowIncome.Text = "Income: " .. formatCash(state.incomePerSecond) .. "/s"
	rowSteals.Text = "Stolen: " .. state.steals
	rowCollected.Text = "Collected: " .. state.collected .. "/" .. BrainrotCatalog.count()
	if state.carrying then
		local def = BrainrotCatalog.get(state.carrying)
		rowCarrying.Text = "Carrying: " .. (if def then def.name else state.carrying)
	else
		rowCarrying.Text = "Carrying: -"
	end
	local progress = math.clamp(state.lifetimeRun / state.rebirthRequirement, 0, 1)
	rebirthBar.Size = UDim2.new(progress, 0, 1, 0)
	rebirthLabel.Text = "Rebirth x" .. tostring(state.multiplier) .. ": " .. formatCash(state.lifetimeRun) .. " / " .. formatCash(state.rebirthRequirement)
	rebirthButton.BackgroundColor3 = if progress >= 1 then GREEN else Color3.fromRGB(120, 120, 130)
	if state.lockRemaining > 0 then
		lockButton.Text = "LOCKED (" .. math.ceil(state.lockRemaining) .. "s)"
		lockButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	elseif state.lockRechargeRemaining > 0 then
		lockButton.Text = "LOCK (" .. math.ceil(state.lockRechargeRemaining) .. "s)"
		lockButton.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
	else
		lockButton.Text = "LOCK BASE [L]"
		lockButton.BackgroundColor3 = GREEN
	end
end)

nextBrainrot.OnClientEvent:Connect(function(spec: any)
	local title = spec.name
	if spec.mutation then
		title = spec.mutation .. " " .. spec.name
	end
	nextLabel.Text = "NEXT: " .. title .. " - " .. formatCash(spec.price) .. " - $" .. spec.income .. "/s"
	if nextStroke then
		nextStroke.Color = BrainrotCatalog.RarityColors[spec.rarity]
	end
end)

toastEvent.OnClientEvent:Connect(function(text: string)
	showToast(text)
end)

codexSync.OnClientEvent:Connect(function(data: any)
	codexData = data
	if codexFrame.Visible then
		rebuildCodex()
	end
end)

local stormGeneration = 0
stormEvent.OnClientEvent:Connect(function(kind: string, seconds: number)
	stormGeneration += 1
	local generation = stormGeneration
	if kind == "warn" then
		stormFrame.Visible = true
		task.spawn(function()
			local remaining = seconds
			while remaining > 0 and generation == stormGeneration do
				stormLabel.Text = "GULL STORM IN " .. remaining .. "s! Get to your base!"
				task.wait(1)
				remaining -= 1
			end
		end)
	elseif kind == "start" then
		stormFrame.Visible = true
		stormLabel.Text = "GULL STORM! Hold onto your brainrots!"
	elseif kind == "end" then
		stormFrame.Visible = false
	end
end)

rebuildCodex()
