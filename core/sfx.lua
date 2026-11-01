local A = ...
local new, onCleanup = A.new, A.onCleanup

-- One voice for the whole interface: a single short blip, pitched per intent.
-- Sound is the cheapest way to make a UI feel like it heard you, so it is on by
-- default and deliberately quiet. If the executor cannot play it, nothing breaks.
local SoundService = game:GetService("SoundService")
local VOICE = "rbxasset://sounds/electronicpingshort.wav"
local PITCH = {
	hover = 1.34, tap = 1.52, on = 1.08, off = 0.76,
	page = 1.74, open = 0.96, close = 0.66, deny = 0.56,
}

local S = { enabled = true, volume = 0.12, cursor = 1, voices = {}, hoverAt = 0, mute = 0 }
local play

local function voice(i)
	local v = S.voices[i]
	if v then return v end
	local ok, inst = pcall(function()
		return new("Sound", {
			Name = "AetherVoice", SoundId = VOICE, Volume = S.volume,
			PlaybackSpeed = 1, Parent = SoundService,
		})
	end)
	if not ok or not inst then return nil end
	S.voices[i] = inst
	return inst
end

play = function(kind, gain)
	if not S.enabled or S.mute > 0 then return end
	if kind == "hover" then
		local now = os.clock()
		if now - S.hoverAt < 0.045 then return end -- a run down a list must not machine-gun
		S.hoverAt = now
	end
	local v = voice(S.cursor)
	if not v then return end
	S.cursor = S.cursor % 4 + 1
	v.PlaybackSpeed = PITCH[kind] or 1.2
	v.Volume = S.volume * (gain or 1)
	pcall(function()
		v.TimePosition = 0
		v:Play()
	end)
end

-- callable table: A.sfx("hover") plays a sound, A.sfx.enabled is its toggle
A.sfx = setmetatable(S, { __call = function(_, kind, gain) return play(kind, gain) end })

onCleanup(function()
	for _, v in pairs(S.voices) do pcall(function() v:Destroy() end) end
	S.voices = {}
end)
