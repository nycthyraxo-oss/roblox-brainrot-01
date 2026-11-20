-- Brainrot Stealer: background music loop with an [M] toggle.
-- The button and the key both flip the same switch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundCatalog = require(Shared:WaitForChild("SoundCatalog"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local music = Instance.new("Sound")
music.Name = "BackgroundMusic"
music.SoundId = "rbxassetid://" .. tostring(SoundCatalog.MusicTrackId)
music.Volume = SoundCatalog.MusicVolume
music.Looped = true
music.Parent = SoundService
music:Play()

local gui = Instance.new("ScreenGui")
gui.Name = "MusicGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "MusicToggle"
button.Size = UDim2.new(0, 150, 0, 40)
button.Position = UDim2.new(0, 12, 1, -52)
button.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Font = Enum.Font.GothamBold
button.TextScaled = true
button.Text = "MUSIC ON [M]"
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

local function toggle()
	if music.Playing then
		music:Pause()
		button.Text = "MUSIC OFF [M]"
	else
		music:Resume()
		button.Text = "MUSIC ON [M]"
	end
end

button.Activated:Connect(toggle)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		toggle()
	end
end)
