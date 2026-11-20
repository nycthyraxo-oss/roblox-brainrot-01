-- Brainrot Stealer: plays the character clip when the server says you
-- picked one up. Characters without a verified track get a pitched ping.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SoundCatalog = require(Shared:WaitForChild("SoundCatalog"))

local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local soundEvent = remotes:WaitForChild("SoundEvent")

soundEvent.OnClientEvent:Connect(function(charId: string)
	local sound = Instance.new("Sound")
	sound.Name = "BrainrotClip"
	local trackId = SoundCatalog.trackIdFor(charId)
	if trackId then
		sound.SoundId = "rbxassetid://" .. tostring(trackId)
		sound.PlaybackSpeed = 1
	else
		sound.SoundId = SoundCatalog.PingSoundId
		sound.PlaybackSpeed = SoundCatalog.pitchFor(charId)
	end
	sound.Volume = 0.8
	sound.Parent = SoundService
	sound:Play()
	task.delay(Config.CharacterClipSeconds, function()
		sound:Stop()
		sound:Destroy()
	end)
end)
