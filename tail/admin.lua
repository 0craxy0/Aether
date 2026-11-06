local A = ...

-- Owner panel ----------------------------------------------------------------
-- Local check on a local value. Nothing here identifies anyone: no hardware id
-- is read, stored or sent, no other client is contacted, and the page is only
-- ever built on this account. Everything it exposes is a control over this
-- instance of the script - re-check the CDN, restart into the latest build,
-- re-read the announcements file - which is the same set of actions a user
-- already has on the Settings page.
local ADMIN_ID = 1562524075
if not A.LP or A.LP.UserId ~= ADMIN_ID then return end

local T = A.T
local button, makePage = A.button, A.makePage

local pAdmin = makePage("Admin", 9)

local sMaint = pAdmin.section("Maintenance", 1)
button(sMaint, "Force update check", "CHECK", function()
	if A.updater then A.updater.checkNow() end
end)
button(sMaint, "Restart into latest", "RESTART", function()
	if not A.updater then return end
	local ok, saved, msg = pcall(A.flushConfig)
	if not (ok and saved == true) then
		A.notify("Restart", "config could not be saved: " .. tostring(msg or saved), "bad")
		return
	end
	A.updater.restart()
end)

local sAnn = pAdmin.section("Announcements", 2)
button(sAnn, "Force announcement check", "CHECK", function()
	if A.announce then A.announce.check(true) end
end)
button(sAnn, "Reset seen announcements", "RESET", function()
	if A.announce then A.announce.reset() end
	A.notify("Announcements", "seen list cleared", "good")
end)
button(sAnn, "Copy announcements template", "COPY", function()
	if A.announce then A.copy(A.announce.TEMPLATE) end
end)

local sInfo = pAdmin.section("Session", 3)
for _, row in ipairs({
	{ "UserId", tostring(A.LP.UserId) },
	{ "Executor", tostring(A.executorName) },
	{ "Build", tostring(A.build) },
	{ "Rev", tostring(A.rev) },
}) do
	A.label({
		Text = string.format('<font color="#79818C">%s</font>   %s', row[1], row[2]),
		TextSize = 11, Size = UDim2.new(1, 0, 0, 18), Parent = sInfo,
	})
end
A.label({
	Text = "Owner panel. It reads nothing about other clients and sends nothing about this one.",
	TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 28), Parent = sInfo,
})

A.stage("admin panel ready")
