local ADDON, ns = ...
local L = ns.L

-- The settings window: one dark panel with a gold accent, built from plain
-- colour textures so it needs no Blizzard templates. /fw, the addon
-- compartment and the game's Options all open it.

local WIDTH = 380
local PAD = 18
local INNER = WIDTH - PAD * 2

local C = {
	bg = { 0.071, 0.086, 0.133, 0.97 },
	panel = { 0.106, 0.125, 0.192, 1 },
	raised = { 0.145, 0.170, 0.255, 1 },
	hover = { 0.185, 0.215, 0.315, 1 },
	line = { 1, 1, 1, 0.07 },
	text = { 0.96, 0.97, 0.99, 1 },
	dim = { 0.71, 0.74, 0.82, 1 },
	muted = { 0.52, 0.56, 0.65, 1 },
	accent = { 0.92, 0.74, 0.38, 1 },
	onAccent = { 0.06, 0.07, 0.10, 1 },
	on = { 0.42, 0.85, 0.60, 1 },
	warn = { 0.98, 0.75, 0.30, 1 },
	off = { 0.55, 0.59, 0.68, 1 },
	danger = { 0.96, 0.45, 0.45, 1 },
}

local win
local widgets = {}

-- Helpers ----------------------------------------------------------------

local function Tex(parent, color, layer)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
	return t
end

local function Paint(t, color)
	t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

local function Border(frame, color)
	local edges = {}
	for i, spec in ipairs({
		{ "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
	}) do
		local t = Tex(frame, color, "BORDER")
		t:SetPoint(spec[1])
		t:SetPoint(spec[2])
		if spec[3] then t:SetHeight(1) else t:SetWidth(1) end
		edges[i] = t
	end
	return edges
end

local function Text(parent, template, color, width)
	local fs = parent:CreateFontString(nil, "OVERLAY", template)
	fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	fs:SetJustifyH("LEFT")
	-- Every label is one line in a fixed box: a long translation is cut with
	-- "..." instead of wrapping, so the window keeps its size in any language.
	if width then
		fs:SetWidth(width)
		fs:SetWordWrap(false)
		if fs.SetMaxLines then fs:SetMaxLines(1) end
	end
	return fs
end

local LINE = 16 -- height of one line of GameFontHighlight / GameFontNormal

local function SetTextColor(fs, color)
	fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

-- Switch -------------------------------------------------------------------

local function Switch(parent, onToggle)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(36, 18)
	b.track = Tex(b, C.raised, "ARTWORK")
	b.track:SetAllPoints()
	b.knob = Tex(b, C.text, "OVERLAY")
	b.knob:SetSize(14, 14)
	b.checked = false

	function b:SetChecked(on)
		self.checked = on and true or false
		self.knob:ClearAllPoints()
		if self.checked then
			self.knob:SetPoint("RIGHT", -2, 0)
			Paint(self.track, C.accent)
			Paint(self.knob, C.onAccent)
		else
			self.knob:SetPoint("LEFT", 2, 0)
			Paint(self.track, self:IsMouseOver() and C.hover or C.raised)
			Paint(self.knob, C.dim)
		end
	end

	b:SetScript("OnClick", function(self)
		if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
		onToggle(not self.checked)
	end)
	b:SetScript("OnEnter", function(self) if not self.checked then Paint(self.track, C.hover) end end)
	b:SetScript("OnLeave", function(self) if not self.checked then Paint(self.track, C.raised) end end)
	return b
end

-- Help lives in a tooltip on hover, so the window itself stays short.
-- body may be a function, for text that changes (the status line).
local function Tooltip(frame, title, body)
	frame:EnableMouse(true)
	frame:HookScript("OnEnter", function(self)
		local text = type(body) == "function" and body() or body
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(type(title) == "function" and title() or title, 1, 1, 1)
		if text and text ~= "" then GameTooltip:AddLine(text, nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A row: label on the left, switch on the right, help in the tooltip.
local function ToggleRow(parent, y, label, help, key)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", PAD, y)
	row:SetWidth(INNER)

	row.label = Text(row, "GameFontHighlight", C.text, INNER - 52)
	row.label:SetPoint("LEFT")
	row.label:SetText(label)

	row.switch = Switch(row, function(on) ns.Set(key, on) end)
	row.switch:SetPoint("RIGHT")

	row:SetHeight(20)
	Tooltip(row, label, help)
	Tooltip(row.switch, label, help)
	row.key = key

	function row:SetActive(active)
		self:SetAlpha(active and 1 or 0.4)
		self.switch:EnableMouse(active)
	end
	return row, row:GetHeight()
end

-- Segmented drag-mode picker -----------------------------------------------------

local MODES = { { "anywhere", "DRAG_ANYWHERE", "DRAG_HELP_ANYWHERE" }, { "shift", "DRAG_SHIFT", "DRAG_HELP_SHIFT" } }

local function ModePicker(parent, y)
	local box = CreateFrame("Frame", nil, parent)
	box:SetPoint("TOPLEFT", PAD, y)
	box:SetSize(INNER, 28)
	box.bg = Tex(box, C.panel)
	box.bg:SetAllPoints()
	Border(box, C.line)

	local w = (INNER - 4) / #MODES
	box.buttons = {}
	for i, m in ipairs(MODES) do
		local b = CreateFrame("Button", nil, box)
		b:SetSize(w, 24)
		b:SetPoint("LEFT", 2 + (i - 1) * w, 0)
		b.bg = Tex(b, C.panel, "ARTWORK")
		b.bg:SetAllPoints()
		b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		b.text:SetPoint("CENTER")
		b.text:SetText(L[m[2]])
		b.mode = m[1]
		b:SetScript("OnClick", function(self)
			if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
			ns.Set("mode", self.mode)
		end)
		b:SetScript("OnEnter", function(self) if not self.selected then Paint(self.bg, C.hover) end end)
		b:SetScript("OnLeave", function(self) if not self.selected then Paint(self.bg, C.panel) end end)
		Tooltip(b, L[m[2]], L[m[3]])
		box.buttons[i] = b
	end

	function box:SetMode(mode)
		for _, b in ipairs(self.buttons) do
			b.selected = b.mode == mode
			Paint(b.bg, b.selected and C.accent or C.panel)
			SetTextColor(b.text, b.selected and C.onAccent or C.dim)
		end
	end
	function box:SetActive(active)
		self:SetAlpha(active and 1 or 0.4)
		for _, b in ipairs(self.buttons) do b:EnableMouse(active) end
	end
	return box, 28
end

-- Window names for the list -----------------------------------------------------

local function DisplayName(name)
	local bag = name:match("^ContainerFrame(%d+)$")
	if bag then return L.W_ContainerFrame:format(tonumber(bag)) end
	return L["W_" .. name] or (name:gsub("Frame$", ""))
end

-- Text button ----------------------------------------------------------------

local function TextButton(parent, label, onClick)
	local b = CreateFrame("Button", nil, parent)
	b.bg = Tex(b, C.raised, "ARTWORK")
	b.bg:SetAllPoints()
	Border(b, C.line)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	SetTextColor(b.text, C.dim)
	b:SetSize(b.text:GetStringWidth() + 28, 24)
	b:SetScript("OnClick", function()
		if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
		onClick()
	end)
	b:SetScript("OnEnter", function(self) Paint(self.bg, C.hover); SetTextColor(self.text, C.text) end)
	b:SetScript("OnLeave", function(self) Paint(self.bg, C.raised); SetTextColor(self.text, C.dim) end)
	return b
end

-- Close button: an X drawn from two rotated bars.
local function CloseButton(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(22, 22)
	b.bars = {}
	for i, angle in ipairs({ math.rad(45), math.rad(-45) }) do
		local t = Tex(b, C.dim, "OVERLAY")
		t:SetSize(14, 2)
		t:SetPoint("CENTER")
		t:SetRotation(angle)
		b.bars[i] = t
	end
	local function Color(c) for _, t in ipairs(b.bars) do Paint(t, c) end end
	b:SetScript("OnEnter", function() Color(C.text) end)
	b:SetScript("OnLeave", function() Color(C.dim) end)
	b:SetScript("OnClick", function() parent:Hide() end)
	return b
end

-- Language menu --------------------------------------------------------------

local function LanguageMenu(parent)
	-- The language the window is in now; picking the game's own language
	-- stores nothing, so the addon keeps following the client.
	local current = ns.activeLocale
	local client = ns.ClientLocale()

	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(22)
	button.bg = Tex(button, C.panel, "ARTWORK")
	button.bg:SetAllPoints()
	Border(button, C.line)
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.text:SetPoint("LEFT", 10, 0)
	SetTextColor(button.text, C.dim)

	-- One width for every language, so the header doesn't shift on a switch.
	local label, widest = "English", 0
	for _, lang in ipairs(ns.LANGUAGES) do
		if ns.LanguageAvailable(lang) then
			button.text:SetText(lang.name)
			widest = math.max(widest, button.text:GetStringWidth())
		end
		if lang.code == current then label = lang.name end
	end
	button.text:SetText(label)
	button:SetWidth(math.ceil(widest) + 36)
	local chevron = {}
	for i, angle in ipairs({ math.rad(-45), math.rad(45) }) do -- a "v" pointing down
		local t = Tex(button, C.dim, "OVERLAY")
		t:SetSize(6, 1.5)
		t:SetRotation(angle)
		chevron[i] = t
	end
	chevron[1]:SetPoint("CENTER", button, "RIGHT", -15, 0)
	chevron[2]:SetPoint("CENTER", button, "RIGHT", -11, 0)

	-- The list, and a catcher behind it that closes it on any outside click.
	local catcher = CreateFrame("Button", nil, parent)
	catcher:SetAllPoints(parent)
	catcher:SetFrameLevel(parent:GetFrameLevel() + 40)
	catcher:Hide()

	local menu = CreateFrame("Frame", nil, parent)
	menu:SetFrameLevel(parent:GetFrameLevel() + 50)
	menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -4)
	menu.bg = Tex(menu, C.raised)
	menu.bg:SetAllPoints()
	Border(menu, C.line)
	menu:Hide()

	local entries = {}
	for _, lang in ipairs(ns.LANGUAGES) do
		if ns.LanguageAvailable(lang) then entries[#entries + 1] = lang end
	end

	local ITEM_H, width = 20, 120
	for i, entry in ipairs(entries) do
		local item = CreateFrame("Button", nil, menu)
		item:SetHeight(ITEM_H)
		item:SetPoint("TOPLEFT", 1, -4 - (i - 1) * ITEM_H)
		item:SetPoint("TOPRIGHT", -1, -4 - (i - 1) * ITEM_H)
		item.bg = Tex(item, C.raised, "ARTWORK")
		item.bg:SetAllPoints()
		item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		item.text:SetPoint("LEFT", 12, 0)
		item.text:SetText(entry.name)
		local selected = entry.code == current
		SetTextColor(item.text, selected and C.accent or C.text)
		width = math.max(width, item.text:GetStringWidth() + 32)
		item:SetScript("OnEnter", function(self) Paint(self.bg, C.hover) end)
		item:SetScript("OnLeave", function(self) Paint(self.bg, C.raised) end)
		item:SetScript("OnClick", function()
			menu:Hide()
			catcher:Hide()
			if not selected then ns.SetLanguage(entry.code ~= client and entry.code or nil) end
		end)
	end
	menu:SetSize(width, #entries * ITEM_H + 8)

	local function Close()
		menu:Hide()
		catcher:Hide()
	end
	catcher:SetScript("OnClick", Close)
	button:SetScript("OnClick", function()
		if menu:IsShown() then Close() else catcher:Show(); menu:Show() end
	end)
	button:SetScript("OnEnter", function(self) Paint(self.bg, C.hover); SetTextColor(self.text, C.text) end)
	button:SetScript("OnLeave", function(self) Paint(self.bg, C.panel); SetTextColor(self.text, C.dim) end)
	parent:HookScript("OnHide", Close)
	return button
end

-- Window -------------------------------------------------------------------

local ROW_H = 26

local function SavePosition()
	local point, _, relPoint, x, y = win:GetPoint(1)
	ns.DB().win = { point, relPoint, x, y }
end

-- The list of moved windows: one row per saved spot, sorted by name, and
-- the footer below it; the window grows and shrinks with the list.
local function LayoutList()
	local db = ns.DB()
	local list = {}
	for name in pairs(db.positions) do list[#list + 1] = name end
	table.sort(list, function(a, b) return DisplayName(a) < DisplayName(b) end)

	for _, row in ipairs(widgets.rows) do row:Hide() end
	local y = widgets.listTop
	for i, name in ipairs(list) do
		local row = widgets.rows[i]
		if not row then
			row = CreateFrame("Frame", nil, win)
			row:SetSize(INNER, ROW_H)
			row.bg = Tex(row, C.panel)
			row.bg:SetAllPoints()
			row.label = Text(row, "GameFontHighlight", C.text, INNER - 90)
			row.label:SetPoint("LEFT", 10, 0)
			row.reset = TextButton(row, L.RESET_ONE, function() ns.ResetOne(row.name) end)
			row.reset:SetHeight(20)
			row.reset:SetPoint("RIGHT", -3, 0)
			Tooltip(row.reset, L.RESET_ONE, L.RESET_ONE_HELP)
			widgets.rows[i] = row
		end
		row.name = name
		row.label:SetText(DisplayName(name))
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", PAD, y)
		row:Show()
		y = y - ROW_H - 4
	end

	widgets.empty:SetShown(#list == 0)
	if #list == 0 then y = y - LINE - 4 end
	y = y - 14

	widgets.footer:ClearAllPoints()
	widgets.footer:SetPoint("TOPLEFT", 0, y)
	widgets.footer:SetPoint("TOPRIGHT", 0, y)
	win:SetHeight(-y + widgets.footer:GetHeight())
end

local function Refresh()
	if not win or not win:IsShown() then return end
	local db = ns.DB()
	local enabled = db.enabled

	widgets.enabled:SetChecked(enabled)
	widgets.modeLabel:SetAlpha(enabled and 1 or 0.4)
	widgets.mode:SetMode(db.mode)
	widgets.mode:SetActive(enabled)
	widgets.lock.switch:SetChecked(db.locked)
	widgets.lock:SetActive(enabled)
	LayoutList()
end
ns.RefreshUI = Refresh

local function Build()
	win = CreateFrame("Frame", "ForeverWindowsWindow", UIParent)
	win:SetWidth(WIDTH)
	win:SetFrameStrata("DIALOG")
	win:SetToplevel(true)
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:Hide()
	if not tContains(UISpecialFrames, "ForeverWindowsWindow") then
		tinsert(UISpecialFrames, "ForeverWindowsWindow")
	end

	win.bg = Tex(win, C.bg)
	win.bg:SetAllPoints()
	Border(win, C.line)
	local top = Tex(win, C.accent, "ARTWORK")
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(2)

	-- Header (drag handle)
	local header = CreateFrame("Frame", nil, win)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(58)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() win:StartMoving() end)
	header:SetScript("OnDragStop", function()
		win:StopMovingOrSizing()
		SavePosition()
	end)

	local title = Text(header, "GameFontNormalLarge", C.text)
	title:SetPoint("TOPLEFT", PAD, -16)
	title:SetText(L.TITLE)
	local subtitle = Text(header, "GameFontHighlightSmall", C.muted, INNER)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
	local version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or ""
	subtitle:SetText("v" .. version)

	-- Above the header, which takes the mouse for dragging.
	local close = CloseButton(win)
	close:SetPoint("TOPRIGHT", -10, -12)
	close:SetFrameLevel(header:GetFrameLevel() + 10)

	local language = LanguageMenu(win)
	language:SetPoint("TOPRIGHT", -40, -12)
	language:SetFrameLevel(header:GetFrameLevel() + 10)

	-- The addon's own on/off switch sits in the header; off dims the rest.
	widgets.enabled = Switch(win, function(on) ns.SetEnabled(on) end)
	widgets.enabled:SetPoint("RIGHT", language, "LEFT", -10, 0)
	widgets.enabled:SetFrameLevel(header:GetFrameLevel() + 10)
	Tooltip(widgets.enabled, L.ENABLED, L.ENABLED_HELP)

	local y = -58
	local h

	widgets.modeLabel = Text(win, "GameFontNormal", C.accent)
	widgets.modeLabel:SetPoint("TOPLEFT", PAD, y)
	widgets.modeLabel:SetText(L.DRAG)
	y = y - LINE - 6
	widgets.mode, h = ModePicker(win, y)
	y = y - h - 16

	widgets.lock, h = ToggleRow(win, y, L.LOCK, L.LOCK_HELP, "locked")
	y = y - h - 18

	local savedLabel = Text(win, "GameFontNormal", C.accent)
	savedLabel:SetPoint("TOPLEFT", PAD, y)
	savedLabel:SetText(L.SAVED)
	y = y - LINE - 8

	widgets.listTop = y
	widgets.rows = {}
	widgets.empty = Text(win, "GameFontHighlightSmall", C.muted, INNER)
	widgets.empty:SetPoint("TOPLEFT", PAD, y)
	widgets.empty:SetText(L.SAVED_NONE)

	-- Footer, moved down by LayoutList as the list grows.
	local footer = CreateFrame("Frame", nil, win)
	footer:SetHeight(48)
	local footerLine = Tex(footer, C.line, "ARTWORK")
	footerLine:SetPoint("TOPLEFT")
	footerLine:SetPoint("TOPRIGHT")
	footerLine:SetHeight(1)
	local footerBg = Tex(footer, { 0, 0, 0, 0.18 }, "BORDER")
	footerBg:SetAllPoints()
	widgets.footer = footer

	local resetAll = TextButton(footer, L.RESET_ALL, function() ns.ResetAll() end)
	resetAll:SetPoint("TOPLEFT", PAD, -12)

	-- Which command opens this window, at the right of the footer.
	local command = Text(footer, "GameFontHighlightSmall", C.muted, INNER - resetAll:GetWidth() - 12)
	command:SetJustifyH("RIGHT")
	command:SetPoint("RIGHT", footer, "TOPRIGHT", -PAD, -24)
	command:SetText(L.CMD_HINT .. " |cffebbd61/fw|r")

	local pos = ns.DB().win
	if pos then
		win:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	else
		win:SetPoint("CENTER", 0, 60)
	end

	local fade = win:CreateAnimationGroup()
	local alpha = fade:CreateAnimation("Alpha")
	alpha:SetFromAlpha(0)
	alpha:SetToAlpha(1)
	alpha:SetDuration(0.15)
	win:SetScript("OnShow", function()
		fade:Play()
		Refresh()
	end)
end

function ns.ToggleWindow()
	if not win then Build() end
	if win:IsShown() then win:Hide() else win:Show() end
end

-- After a language change: drop the old window and build it again in the
-- new language, at the same place and with the same visibility.
function ns.RebuildWindow()
	if not win then return end
	local shown = win:IsShown()
	win:Hide()
	win = nil
	Build()
	if shown then win:Show() end
end

-- The game's Options: a page with one button that opens the window.
local options

local function RegisterOptions()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local panel = CreateFrame("Frame")
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(L.TITLE)
	local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	text:SetText(L.OPTIONS_TEXT)
	local button = TextButton(panel, L.OPTIONS_OPEN, function()
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		if not win or not win:IsShown() then ns.ToggleWindow() end
	end)
	button:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
	local category = Settings.RegisterCanvasLayoutCategory(panel, L.TITLE)
	Settings.RegisterAddOnCategory(category)
	options = { text = text, button = button }
end

-- After a language change the Options page follows too (its list entry is
-- the addon's name, the same in every language).
function ns.RefreshOptions()
	if not options then return end
	options.text:SetText(L.OPTIONS_TEXT)
	options.button.text:SetText(L.OPTIONS_OPEN)
	options.button:SetWidth(options.button.text:GetStringWidth() + 28)
end

function ns.InitUI()
	pcall(RegisterOptions)
	ns.OnChange(Refresh)
end
