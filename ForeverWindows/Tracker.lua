local _, ns = ...

-- Hide the quest tracker: the list of quests and objectives at the right edge
-- of the screen (ObjectiveTrackerFrame) stays hidden while the option is on.
--
-- The tracker holds secure quest item buttons, so the game lets an addon hide
-- or show it only out of combat; a change asked for in a fight waits for its
-- end. Only a tracker this addon hid is shown again.

local hooked = false
local hiddenByUs = false
local pending = false

local function Wanted()
	local db = ns.DB()
	return db and db.enabled and db.hideTracker
end

local function Hook(tracker)
	if hooked then return end
	hooked = true
	-- the game shows the tracker again on its own (new quest, Edit Mode, zoning)
	tracker:HookScript("OnShow", function(self)
		if not Wanted() then return end
		if InCombatLockdown() then
			pending = true
		else
			hiddenByUs = true
			self:Hide()
		end
	end)
end

function ns.UpdateTracker()
	local tracker = ObjectiveTrackerFrame
	if not tracker or not ns.DB() then return end
	Hook(tracker)
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	if Wanted() then
		if tracker:IsShown() then
			hiddenByUs = true
			tracker:Hide()
		end
	elseif hiddenByUs then
		hiddenByUs = false
		tracker:Show()
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
