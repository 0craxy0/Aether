local A = ...

for _, name in ipairs({
	"Players", "RunService", "UserInputService", "TweenService", "Lighting",
	"TeleportService", "HttpService", "VirtualUser", "StarterGui",
}) do
	A[name] = game:GetService(name)
end

A.LP = A.Players.LocalPlayer

function A.stage(n) print("[Aether] stage " .. n) end
A.stage("0 start")
if _G.AetherUnload then pcall(_G.AetherUnload) end -- never stack two instances

A.has = {
	drawing = type(Drawing) == "table",
	writefile = type(writefile) == "function",
	readfile = type(readfile) == "function",
	isfile = type(isfile) == "function",
	makefolder = type(makefolder) == "function",
	gethui = type(gethui) == "function",
}

A.executorName = "unknown"
pcall(function() A.executorName = identifyexecutor() end)

A.cleanup = {}
function A.onCleanup(fn) A.cleanup[#A.cleanup + 1] = fn end

