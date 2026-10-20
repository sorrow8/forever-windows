local _, ns = ...

-- Hide the quest tracker: the list of quests and objectives at the right edge
-- of the screen (ObjectiveTrackerFrame) stays out of sight while the option
-- is on.
--
-- The tracker is never hidden with Hide: that makes the game lay out the
-- right side of the screen again from this addon's code, and the boss frames
-- live there too, so a fight later could end with "action blocked". It turns
-- invisible instead and its lines stop taking the mouse, which changes no
-- layout. In Edit Mode it shows, so it can still be moved.

local hooked = false
local dimmed = false      -- made invisible by this addon
local fixing = false      -- an alpha change this addon is doing right now
local unclickable = {}    -- [frame] = true, mouse turned off by this addon

local function Wanted()
	local db = ns.DB()
	if not (db and db.enabled and db.hideTracker) then return false end
	return not (EditModeManagerFrame and EditModeManagerFrame:IsShown())
end

-- Every line, header and item button under the tracker; a protected one only
-- out of combat.
local function Mouse(frame, on)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.EnableMouse and not (child.IsForbidden and child:IsForbidden())
			and not (InCombatLockdown() and child:IsProtected()) then
			if on then
				if unclickable[child] then
					unclickable[child] = nil
					child:EnableMouse(true)
				end
			elseif child:IsMouseEnabled() then
				unclickable[child] = true
				child:EnableMouse(false)
			end
		end
		Mouse(child, on)
	end
end

local function Dim(tracker)
	dimmed = true
	fixing = true
	tracker:SetAlpha(0)
	fixing = false
	Mouse(tracker, false)
end

local function Undim(tracker)
	if not dimmed then return end
	dimmed = false
	fixing = true
	tracker:SetAlpha(1)
	fixing = false
	Mouse(tracker, true)
end

local function Hook(tracker)
	if hooked then return end
	hooked = true
	-- the game fades the right side of the screen back in (after Alt+Z): stay invisible
	hooksecurefunc(tracker, "SetAlpha", function(self, alpha)
		if dimmed and not fixing and alpha ~= 0 then
			fixing = true
			self:SetAlpha(0)
			fixing = false
		end
	end)
	-- new quest lines and item buttons come with the tracker's updates
	if tracker.Update then
		hooksecurefunc(tracker, "Update", function(self)
			if dimmed then Mouse(self, false) end
		end)
	end
	-- Edit Mode shows the tracker so it can be moved
	if EditModeManagerFrame then
		EditModeManagerFrame:HookScript("OnShow", function() ns.UpdateTracker() end)
		EditModeManagerFrame:HookScript("OnHide", function() ns.UpdateTracker() end)
	end
end

function ns.UpdateTracker()
	local tracker = ObjectiveTrackerFrame
	if not tracker or not ns.DB() then return end
	Hook(tracker)
	if Wanted() then Dim(tracker) else Undim(tracker) end
end

ns.OnChange(ns.UpdateTracker)

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, name)
	if event == "PLAYER_REGEN_ENABLED" then
		-- item buttons are protected: their mouse is turned off once the fight ends
		if dimmed then Mouse(ObjectiveTrackerFrame, false) end
	elseif event == "PLAYER_LOGIN" or name == "Blizzard_ObjectiveTracker" then
		-- the tracker may come with the game or in its own Blizzard addon
		ns.UpdateTracker()
	end
end)
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
