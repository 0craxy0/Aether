local A = ...

for _, name in ipairs({
	"Players", "RunService", "UserInputService", "TweenService", "Lighting",
	"TeleportService", "HttpService", "VirtualUser", "StarterGui",
}) do
	A[name] = game:GetService(name)
end

A.LP = A.Players.LocalPlayer

-- Coordinate spaces, once. GetMouseLocation is measured from the top of the
-- window; GuiObject.AbsolutePosition is reported from the topbar origin even
-- when the ScreenGui ignores the inset. Anything that compares a pointer with an
-- AbsolutePosition has to subtract this, or it is wrong by a whole topbar.
A.guiInset = 0
pcall(function() A.guiInset = game:GetService("GuiService"):GetGuiInset().Y end)

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

-- registered before the first file runs: a failure half way through the loader can
-- still tear down everything that was built instead of leaking a second ScreenGui
function A.unload()
	for i = #A.cleanup, 1, -1 do pcall(A.cleanup[i]) end
	A.cleanup = {}
	if A.screen then
		pcall(function() A.screen:Destroy() end)
		A.screen = nil
	end
	if _G.AetherUnload == A.unload then _G.AetherUnload = nil end
end
_G.AetherUnload = A.unload

