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
-- Spots are kept in UIParent units, not in the window's own scale: the game
-- shrinks some windows on the fly (the bags while the bank is open, panels
-- that don't fit the screen), and a spot in the window's own units would
-- drift with every such change.
--
-- Windows that Edit Mode positions (the loot window and the like) are left
-- to Edit Mode. Nothing is ever written onto a Blizzard frame; all state lives
-- in the tables below, keyed by frame, so the game's own code is not tainted.

local EXTRA = { "ContainerFrameCombinedBags" }
for i = 1, 13 do EXTRA[#EXTRA + 1] = "ContainerFrame" .. i end

local frames = {}         -- [name] = frame
local names = {}          -- [frame] = name
local moving = {}         -- [frame] = true while it is being dragged
local original = {}       -- [frame] = the game's anchor before we first moved it
local pendingApply = {}   -- [frame] = true: protected, waits for combat to end
local pendingInstall = {} -- [name] = true: protected, waits for combat to end
local warned = {}         -- [frame] = true: the combat message was shown once
local pendingStop = {}    -- [frame] = "save" or "drop": a drag a fight cut into, ended after it
local applying = false

local function DB() return ns.DB() end

local function Blocked(frame)
	return InCombatLockdown() and frame:IsProtected()
end

-- A maximized window (the big world map) fills the screen on the game's terms.
local function Maximized(frame)
	local isMaximized = frame.IsMaximized
	return type(isMaximized) == "function" and isMaximized(frame) == true
end

-- window units per UIParent unit
local function Ratio(frame)
	return UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
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
	if type(pos) ~= "table" or type(pos[3]) ~= "number" or type(pos[4]) ~= "number" then return end
	if moving[frame] or Maximized(frame) then return end
	if Blocked(frame) then
		pendingApply[frame] = true
		return
	end
	Capture(frame)
	local ratio = Ratio(frame)
	applying = true
	frame:ClearAllPoints()
	frame:SetPoint(pos[1], UIParent, pos[2], pos[3] * ratio, pos[4] * ratio)
	applying = false
end

local function Save(frame)
	local left, top = frame:GetLeft(), frame:GetTop()
	if not (left and top) then return end
	-- GetLeft/GetTop are in the window's own scale; kept in UIParent units
	local ratio = Ratio(frame)
	DB().positions[names[frame]] = { "TOPLEFT", "BOTTOMLEFT", left / ratio, top / ratio }
end

local function OnDragStart(frame)
	local db = DB()
	if not db.enabled or db.locked then return end
	if db.mode == "shift" and not IsShiftKeyDown() then return end
	if Maximized(frame) then return end
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

local function EndDrag(frame, save)
	frame:StopMovingOrSizing()
	moving[frame] = nil
	-- the game would also keep its own copy of the spot; ours is enough
	pcall(frame.SetUserPlaced, frame, false)
	if save then Save(frame) end
	Apply(frame)
	ns.Notify()
end

-- A protected window can't be let go of in combat (a fight that started
-- mid-drag): it is let go of right after the fight.
local function OnDragStop(frame)
	if not moving[frame] then return end
	if Blocked(frame) then
		pendingStop[frame] = "save"
		return
	end
	EndDrag(frame, true)
end

-- Closed while being dragged (Esc, the loot ran out, the vendor walked off):
-- end the drag without saving, or the window would stay unmanaged.
local function OnHide(frame)
	if not moving[frame] then return end
	if Blocked(frame) then
		pendingStop[frame] = pendingStop[frame] or "drop"
		return
	end
	EndDrag(frame, false)
end

local function Install(name)
	local frame = _G[name]
	if type(frame) ~= "table" or not frame.GetObjectType or names[frame] then return end
	if frame.IsForbidden and frame:IsForbidden() then return end
	-- Edit Mode places this one (it carries an Edit Mode system)
	if frame.system ~= nil then return end
	if Blocked(frame) then
		pendingInstall[name] = true
		return
	end
	pendingInstall[name] = nil
	names[frame], frames[name] = name, frame

	frame:SetMovable(true)
	-- the game must not keep its own copy of the spot (layout-local.txt); ours is enough
	if frame.SetDontSavePosition then pcall(frame.SetDontSavePosition, frame, true) end
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:HookScript("OnDragStart", OnDragStart)
	frame:HookScript("OnDragStop", OnDragStop)
	frame:HookScript("OnShow", Apply)
	frame:HookScript("OnHide", OnHide)
	local function Again(self)
		if not applying then Apply(self) end
	end
	hooksecurefunc(frame, "SetPoint", Again)
	-- a new scale moves the window's spot on screen; put it back
	hooksecurefunc(frame, "SetScale", Again)

	if frame:IsShown() then Apply(frame) end
end

-- Every window the game manages as a panel, plus the bags. Called at login
-- and whenever a Blizzard part loads on demand.
function ns.Scan()
	if UIPanelWindows then
		for name, info in pairs(UIPanelWindows) do
			if type(info) ~= "table" or info.area ~= "full" then Install(name) end
		end
	end
	for _, name in ipairs(EXTRA) do Install(name) end
end

function ns.AfterCombat()
	for frame, what in pairs(pendingStop) do
		pendingStop[frame] = nil
		if moving[frame] then EndDrag(frame, what == "save") end
	end
	for name in pairs(pendingInstall) do Install(name) end
	for frame in pairs(pendingApply) do
		pendingApply[frame] = nil
		Apply(frame)
	end
end

-- The game's own anchor back. Done for closed windows too: some (the Esc
-- menu) are never placed again by the game.
local function Unplace(frame)
	local points = original[frame]
	if not points or #points == 0 or Blocked(frame) or moving[frame] then return end
	applying = true
	frame:ClearAllPoints()
	for _, p in ipairs(points) do frame:SetPoint(unpack(p)) end
	applying = false
end

-- Forget one window's spot; it goes back to where the game had it.
function ns.ResetOne(name, quiet)
	DB().positions[name] = nil
	local frame = frames[name]
	if frame then Unplace(frame) end
	if not quiet then ns.Notify() end
end

-- The addon switched off: every moved window goes back to the game's spot.
local function UnplaceAll()
	for frame in pairs(names) do Unplace(frame) end
end

-- After settings change: a window that is open now follows at once.
function ns.ApplyAll()
	for frame in pairs(names) do
		if frame:IsShown() then Apply(frame) end
	end
end
ns.OnChange(function()
	local db = DB()
	if db and not db.enabled then UnplaceAll() else ns.ApplyAll() end
end)
