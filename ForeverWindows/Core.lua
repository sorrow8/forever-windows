local ADDON, ns = ...
local L = ns.L

-- Forever Windows: drag a game window once, it opens at that spot from then on.
--
-- The moving itself lives in Mover.lua. This file keeps the settings, answers
-- the slash command and tells the mover and the window when something changes.

local DEFAULTS = {
	enabled = true,
	mode = "anywhere", -- anywhere | shift
	locked = false,
	hideTracker = false, -- the quest tracker at the right edge of the screen
	minimapShow = true,
	minimapAngle = 150,
}

local PREFIX = "|cffebbd61Forever Windows|r: "

local db
local listeners = {}

function ns.Print(msg)
	print(PREFIX .. msg)
end

function ns.OnChange(fn)
	listeners[#listeners + 1] = fn
end

local function Notify()
	for _, fn in ipairs(listeners) do fn() end
end
ns.Notify = Notify

function ns.DB() return db end
ns.DEFAULTS = DEFAULTS

function ns.SetEnabled(on)
	on = on and true or false
	if db.enabled == on then return end
	db.enabled = on
	ns.Print(on and L.MSG_ON or L.MSG_OFF)
	Notify()
end

function ns.Set(key, value)
	if db[key] == value then return end
	db[key] = value
	Notify()
end

function ns.SetLanguage(code)
	db.language = code
	ns.ApplyLocale(code)
	if ns.RebuildWindow then ns.RebuildWindow() end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- Settings back to defaults; the saved window spots stay.
function ns.Reset()
	for k, v in pairs(DEFAULTS) do db[k] = v end
	Notify()
end

-- Every saved window spot is forgotten.
function ns.ResetAll()
	for name in pairs(db.positions) do
		if ns.ResetOne then ns.ResetOne(name, true) end
	end
	wipe(db.positions)
	ns.Print(L.MSG_RESET)
	Notify()
end

-- Events ---------------------------------------------------------------------

local frame = CreateFrame("Frame")
local events = {}

function events.ADDON_LOADED(name)
	if name == ADDON then
		ForeverWindowsDB = ForeverWindowsDB or {}
		db = ForeverWindowsDB
		for k, v in pairs(DEFAULTS) do
			if db[k] == nil then db[k] = v end
		end
		-- damaged or foreign saved data must not break a window
		if type(db.positions) ~= "table" then db.positions = {} end
		for name, pos in pairs(db.positions) do
			if type(name) ~= "string" or type(pos) ~= "table" or type(pos[1]) ~= "string" or type(pos[2]) ~= "string"
				or type(pos[3]) ~= "number" or type(pos[4]) ~= "number" then
				db.positions[name] = nil
			end
		end
		local win = db.win
		if win ~= nil and not (type(win) == "table" and type(win[1]) == "string" and type(win[2]) == "string"
			and type(win[3]) == "number" and type(win[4]) == "number") then
			db.win = nil
		end
		if db.mode ~= "anywhere" and db.mode ~= "shift" then db.mode = DEFAULTS.mode end
		ns.ApplyLocale(db.language)
	end
	-- Blizzard loads many windows on demand; look for new ones each time.
	if db and ns.loggedIn then ns.Scan() end
end

function events.PLAYER_LOGIN()
	ns.loggedIn = true
	ns.Scan()
	if ns.InitUI then ns.InitUI() end
	-- the first login explains what changed, every later one says how to open the settings
	if not db.welcomed then
		db.welcomed = true
		ns.Print(L.MSG_WELCOME)
	else
		ns.Print(L.MSG_LOADED)
	end
end

function events.PLAYER_REGEN_ENABLED()
	ns.AfterCombat()
end

frame:SetScript("OnEvent", function(_, event, ...)
	local fn = events[event]
	if fn then fn(...) end
end)
for event in pairs(events) do
	frame:RegisterEvent(event)
end

-- Slash command, addon compartment -----------------------------------------

local function Command(msg)
	local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")
	if cmd == "" then
		if ns.ToggleWindow then ns.ToggleWindow() end
	elseif cmd == "on" then
		ns.SetEnabled(true)
	elseif cmd == "off" then
		ns.SetEnabled(false)
	elseif cmd == "lock" then
		ns.Set("locked", true)
		ns.Print(L.MSG_LOCKED)
	elseif cmd == "unlock" then
		ns.Set("locked", false)
		ns.Print(L.MSG_UNLOCKED)
	elseif cmd == "tracker" then
		ns.Set("hideTracker", not ns.DB().hideTracker)
		if not ns.DB().enabled then
			ns.Print(L.MSG_TRACKER_ADDON_OFF)
		else
			ns.Print(ns.DB().hideTracker and L.MSG_TRACKER_OFF or L.MSG_TRACKER_ON)
		end
	elseif cmd == "lang" and (arg == "auto" or ns.LanguageCode(arg)) then
		ns.SetLanguage(arg ~= "auto" and ns.LanguageCode(arg) or nil)
	elseif cmd == "reset" then
		ns.ResetAll()
	else
		ns.Print(L.MSG_HELP)
	end
end

SLASH_FOREVERWINDOWS1 = "/fw"
SLASH_FOREVERWINDOWS2 = "/foreverwindows"
SlashCmdList.FOREVERWINDOWS = Command

function ForeverWindows_OnCompartmentClick()
	if ns.ToggleWindow then ns.ToggleWindow() end
end
