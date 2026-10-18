local _, ns = ...

-- English is the base; a locale file (Locales/*.lua) only overrides what it
-- translates. The game's language is used unless one is picked in the
-- window's language menu or with /fw lang.
local L = {
	TITLE = "Forever Windows",

	ENABLED = "Addon enabled",
	ENABLED_HELP = "Off: every window opens at the game's own spot again. Your saved spots are kept.",

	DRAG = "Move windows",
	DRAG_ANYWHERE = "Just drag",
	DRAG_SHIFT = "Shift + drag",
	DRAG_HELP_ANYWHERE = "Drag a window by any empty part of it.",
	DRAG_HELP_SHIFT = "Hold Shift and drag, so a window never moves by accident.",

	LOCK = "Lock positions",
	LOCK_HELP = "Windows keep their spots and can't be dragged until you unlock them.",

	TRACKER = "Hide the quest tracker",
	TRACKER_HELP = "The list of quests and objectives at the right edge of the screen stays hidden. Quest progress is still in the quest log. In a fight the change waits for its end.",

	SAVED = "Moved windows",
	SAVED_NONE = "None yet. Open any window and drag it.",
	RESET_ONE = "Reset",
	RESET_ONE_HELP = "This window opens at the game's own spot again.",
	RESET_ALL = "Reset all",
	CMD_HINT = "Open this window:",

	MSG_WELCOME = "installed. Drag any window to move it, it will open there from now on. Settings: type |cffebbd61/fw|r",
	MSG_LOADED = "loaded. Settings: |cffebbd61/fw|r",
	MSG_ON = "on.",
	MSG_OFF = "off, windows open at the game's own spots.",
	MSG_RESET = "all window positions reset.",
	MSG_LOCKED = "positions locked.",
	MSG_UNLOCKED = "positions unlocked.",
	MSG_COMBAT = "this window is protected in combat, it moves into place after the fight.",
	MSG_TRACKER_OFF = "quest tracker hidden.",
	MSG_TRACKER_ON = "quest tracker shown.",
	MSG_HELP = "/fw: window, /fw on, /fw off, /fw lock, /fw unlock, /fw tracker, /fw reset, /fw lang auto/en/ru",

	OPTIONS_OPEN = "Open the settings window",
	OPTIONS_TEXT = "Every setting lives in the addon's own window.",

	-- window names for the list
	W_CharacterFrame = "Character",
	W_ContainerFrameCombinedBags = "Bags",
	W_ContainerFrame = "Bag %d",
	W_MerchantFrame = "Merchant",
	W_QuestFrame = "Quest dialogue",
	W_GossipFrame = "NPC dialogue",
	W_ClassTrainerFrame = "Trainer",
	W_WorldMapFrame = "Map and quest log",
	W_QuestLogFrame = "Quest log",
	W_MailFrame = "Mail",
	W_BankFrame = "Bank",
	W_GuildBankFrame = "Guild bank",
	W_ProfessionsFrame = "Professions",
	W_TradeSkillFrame = "Professions",
	W_AuctionHouseFrame = "Auction house",
	W_AuctionFrame = "Auction house",
	W_PlayerSpellsFrame = "Spellbook and talents",
	W_SpellBookFrame = "Spellbook",
	W_TalentFrame = "Talents",
	W_PlayerTalentFrame = "Talents",
	W_FriendsFrame = "Social",
	W_SocialUIFrame = "Social",
	W_CommunitiesFrame = "Guild and communities",
	W_CollectionsJournal = "Collections",
	W_PVEFrame = "Group finder",
	W_LFGParentFrame = "Group finder",
	W_InspectFrame = "Inspect",
	W_CalendarFrame = "Calendar",
	W_AchievementFrame = "Achievements",
	W_DressUpFrame = "Dressing room",
	W_TaxiFrame = "Flight master",
	W_EncounterJournal = "Adventure guide",
	W_MacroFrame = "Macros",
	W_KeyBindingFrame = "Key bindings",
	W_TradeFrame = "Trade",
	W_ItemTextFrame = "Book and letter",
	W_TabardFrame = "Tabard",
	W_PetStableFrame = "Stable",
}

ns.LOCALES = {}

-- The language menu.
ns.LANGUAGES = {
	{ code = "enUS", short = "en", name = "English" },
	{ code = "ruRU", short = "ru", name = "Русский" },
}

function ns.LanguageAvailable(lang)
	return not lang.cjk or GetLocale() == lang.code
end

-- "ruRU" or "ru" -> "ruRU"; nil, "auto" or anything unknown -> nil.
function ns.LanguageCode(choice)
	if type(choice) ~= "string" then return nil end
	choice = choice:lower()
	for _, lang in ipairs(ns.LANGUAGES) do
		if choice == lang.short or choice == lang.code:lower() then return lang.code end
	end
end

local EN = {}
for k, v in pairs(L) do EN[k] = v end

-- The game's language as one of ns.LANGUAGES' codes.
function ns.ClientLocale()
	local code = GetLocale()
	if code == "enGB" then return "enUS" end
	return code
end

-- The table stays the same object, so every file holding ns.L sees the change.
function ns.ApplyLocale(choice)
	local code = ns.LanguageCode(choice) or ns.ClientLocale()
	for k, v in pairs(EN) do L[k] = v end
	local over = ns.LOCALES[code]
	if over then
		for k, v in pairs(over) do L[k] = v end
	end
	ns.activeLocale = over and code or "enUS"
end

ns.L = L
