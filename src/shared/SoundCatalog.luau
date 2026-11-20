-- Brainrot Stealer: pickup sounds. Ten characters have a verified public
-- Roblox audio track (played as a short clip to the carrier only). The rest
-- use a built-in client ping at a distinct pitch per character, so every
-- pickup still sounds different.

local SoundCatalog = {}

-- Verified public audio asset ids (Audio type).
SoundCatalog.TrackIds = {
	tungtung = 128096405862126,
	tralalero = 101843316787835,
	chimpanzini = 123254496530998,
	lirili = 101207716587722,
	ballerina = 99253687868892,
	patapim = 126271266950979,
	bombardiro = 107128147864287,
	lavaca = 77931469173217,
	boneca = 96830927974148,
	trippitroppi = 101241740024903,
}

-- Fallback ping pitches (PlaybackSpeed) for characters without a track.
SoundCatalog.PingPitches = {
	cappuccino = 0.9,
	frulli = 1.1,
	glorbo = 0.8,
	grande = 1.0,
	frigo = 0.7,
	giraffa = 1.3,
	tralaleritos = 1.5,
	spaghetti = 1.2,
}

SoundCatalog.PingSoundId = "rbxasset://sounds/electronicpingshort.wav"

-- The background music track and its playback level.
SoundCatalog.MusicTrackId = 101843316787835
SoundCatalog.MusicVolume = 0.25

function SoundCatalog.trackIdFor(charId: string): number?
	return SoundCatalog.TrackIds[charId]
end

function SoundCatalog.pitchFor(charId: string): number
	return SoundCatalog.PingPitches[charId] or 1
end

return SoundCatalog
