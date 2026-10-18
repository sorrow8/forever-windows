local ADDON, ns = ...
local L = ns.L

-- The mover: makes game windows draggable and keeps them where they were put.
--
-- A saved spot is put back at the moment the game places the window: right
-- after any SetPoint the game makes (UpdateUIPanelPositions, the bag
-- anchoring, a gossip window handing over to a quest) and when it is shown.
-- Both happen before the frame is drawn, so the window never shows up at
-- the game's spot first.
--
-- Some windows are protected and cannot be moved by an addon in combat.
-- Those are left to the game during a fight and put in place right after.
--
-- Nothing is ever written onto a Blizzard frame; all state lives in the
-- tables below, keyed by frame, so the game's own code is not tainted.

local EXTRA = { "ContainerFrameCombinedBags", "LootFrame" }
for i = 1, 13 do EXTRA[#EXTRA + 1] = "ContainerFrame" .. i end

local frames = {}         -- [name] = frame
local names = {}          -- [frame] = name
local moving = {}         -- [frame] = true while it is being dragged
local original = {}       -- [frame] = the game's anchor before we first moved it
local pendingApply = {}   -- [frame] = true: protected, waits for combat to end
local pendingInstall = {} -- [name] = true: protected, waits for combat to end
local warned = {}         -- [frame] = true: the combat message was shown once
local applying = false

local function DB() return ns.DB() end

local function Blocked(frame)
	return InCombatLockdown() and frame:IsProtected()
end

-- The anchor the game gave the window, kept so a reset can put it back.
local function Capture(frame)
	if original[frame] then return end
	local points = {}
	for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
	original[frame] = points
end

local function Apply(frame)
	local db = DB()
	local pos = db and db.enabled and db.positions[names[frame]]
	if not pos or moving[frame] then return end
	if Blocked(frame) then
		pendingApply[frame] = true
		return
	end
	Capture(frame)
	applying = true
	frame:ClearAllPoints()
	frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	applying = false
end

local function Save(frame)
	local left, top = frame:GetLeft(), frame:GetTop()
	if not (left and top) then return end
	-- GetLeft/GetTop and SetPoint offsets are both in the frame's own scale.
	DB().positions[names[frame]] = { "TOPLEFT", "BOTTOMLEFT", left, top }
end

local function OnDragStart(frame)
	local db = DB()
	if not db.enabled or db.locked then return end
	if db.mode == "shift" and not IsShiftKeyDown() then return end
	if Blocked(frame) then
		if not warned[frame] then
			warned[frame] = true
			ns.Print(L.MSG_COMBAT)
		end
		return
	end
	Capture(frame)
	moving[frame] = true
	frame:StartMoving()
end

local function OnDragStop(frame)
	if not moving[frame] then return end
	frame:StopMovingOrSizing()
	moving[frame] = nil
	-- the game would also keep its own copy of the spot; ours is enough
	pcall(frame.SetUserPlaced, frame, false)
	Save(frame)
	Apply(frame)
	ns.Notify()
end

local function Install(name)
	local frame = _G[name]
	if type(frame) ~= "table" or not frame.GetObjectType or names[frame] then return end
	if frame.IsForbidden and frame:IsForbidden() then return end
	if Blocked(frame) then
		pendingInstall[name] = true
		return
	end
	pendingInstall[name] = nil
	names[frame], frames[name] = name, frame

	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:HookScript("OnDragStart", OnDragStart)
	frame:HookScript("OnDragStop", OnDragStop)
	frame:HookScript("OnShow", Apply)
	hooksecurefunc(frame, "SetPoint", function(self)
		if not applying then Apply(self) end
	end)

	if frame:IsShown() then Apply(frame) end
end

-- Every window the game manages as a panel, plus the bags and the loot
-- window. Called at login and whenever a Blizzard part loads on demand.
function ns.Scan()
	if UIPanelWindows then
		for name, info in pairs(UIPanelWindows) do
			if type(info) ~= "table" or info.area ~= "full" then Install(name) end
		end
	end
	for _, name in ipairs(EXTRA) do Install(name) end
end

function ns.AfterCombat()
	for name in pairs(pendingInstall) do Install(name) end
	for frame in pairs(pendingApply) do
		pendingApply[frame] = nil
		Apply(frame)
	end
end

-- Forget one window's spot. If it is open, it goes back to where the game
-- had it; otherwise the game places it on the next open anyway.
function ns.ResetOne(name, quiet)
	DB().positions[name] = nil
	local frame = frames[name]
	local points = frame and original[frame]
	if points and frame:IsShown() and not Blocked(frame) and #points > 0 then
		applying = true
		frame:ClearAllPoints()
		for _, p in ipairs(points) do frame:SetPoint(unpack(p)) end
		applying = false
	end
	if not quiet then ns.Notify() end
end

-- After settings change: a window that is open now follows at once.
function ns.ApplyAll()
	for frame in pairs(names) do
		if frame:IsShown() then Apply(frame) end
	end
end
ns.OnChange(function() ns.ApplyAll() end)
