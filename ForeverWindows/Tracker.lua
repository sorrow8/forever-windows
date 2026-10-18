local _, ns = ...

-- Hide the quest tracker: the list of quests and objectives at the right edge
-- of the screen (ObjectiveTrackerFrame) stays hidden while the option is on.
--
-- Hiding the tracker makes the game lay out the right side of the screen
-- again (the boss frames live there too), which an addon must not start in
-- combat. So in a fight the tracker only turns invisible, and it is really
-- hidden once the fight ends. Only a tracker this addon hid is shown again.

local hooked = false
local hiddenByUs = false -- hidden by this addon, not by the game
local dimmed = false     -- made invisible in combat
local ourHide = false    -- a Hide this addon is doing right now
local pending = false

local function Wanted()
	local db = ns.DB()
	return db and db.enabled and db.hideTracker
end

local function HideTracker(tracker)
	hiddenByUs = true
	ourHide = true
	tracker:Hide()
	ourHide = false
end

local function Dim(tracker)
	dimmed = true
	tracker:SetAlpha(0)
	pending = true
end

local function Undim(tracker)
	if dimmed then
		dimmed = false
		tracker:SetAlpha(1)
	end
end

local function Hook(tracker)
	if hooked then return end
	hooked = true
	-- the game shows the tracker again on its own (quest progress, Edit Mode, zoning)
	tracker:HookScript("OnShow", function(self)
		if not Wanted() then return end
		if InCombatLockdown() then
			Dim(self)
		else
			HideTracker(self)
		end
	end)
	-- the game fades the right side of the screen back in (after Alt+Z): stay invisible
	local fixing = false
	hooksecurefunc(tracker, "SetAlpha", function(self, alpha)
		if dimmed and not fixing and alpha ~= 0 then
			fixing = true
			self:SetAlpha(0)
			fixing = false
		end
	end)
	-- the game hid it itself (nothing tracked): not ours to show again later.
	-- The method, not OnHide: the game also hides a tracker that is already hidden.
	hooksecurefunc(tracker, "Hide", function()
		if not ourHide then hiddenByUs = false end
	end)
end

function ns.UpdateTracker()
	local tracker = ObjectiveTrackerFrame
	if not tracker or not ns.DB() then return end
	Hook(tracker)
	if InCombatLockdown() then
		if Wanted() then
			if tracker:IsShown() then Dim(tracker) end
		else
			Undim(tracker)
			if hiddenByUs then pending = true end
		end
		return
	end
	pending = false
	if Wanted() then
		if tracker:IsShown() then HideTracker(tracker) end
		Undim(tracker) -- hidden by now, so this shows nothing
	else
		Undim(tracker)
		if hiddenByUs then
			hiddenByUs = false
			tracker:Show()
		end
	end
end

ns.OnChange(ns.UpdateTracker)

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, name)
	if event == "PLAYER_REGEN_ENABLED" then
		if pending then ns.UpdateTracker() end
	elseif event == "PLAYER_LOGIN" or name == "Blizzard_ObjectiveTracker" then
		-- the tracker may come with the game or in its own Blizzard addon
		ns.UpdateTracker()
	end
end)
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
