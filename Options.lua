-- ATT-Search: Options
-- Saved settings (ATTSearchSettings) and the options page under the game's AddOns settings.
local addonName, ns = ...
local L, Util = ns.L, ns.Util

local Options = {}
ns.Options = Options

local DEFAULTS = {
	lookups = true,       -- ask the server for names the game hasn't loaded (NPCs, objects...)
	loadItems = true,     -- also load the names of items the game hasn't cached
	searchQuests = false, -- also load quest names from the server (strictly limited)
}

-- Settings ---------------------------------------------------------------------

local function DB()
	if type(ATTSearchSettings) ~= "table" then
		ATTSearchSettings = {}
		-- 1.1.7 and 1.1.8 kept "/atts lookups off" next to the saved names.
		if type(ATTSearchDB) == "table" and ATTSearchDB.lookupsOff then
			ATTSearchSettings.lookups = false
			ATTSearchDB.lookupsOff = nil
		end
	end
	return ATTSearchSettings
end

function Options.Get(key)
	local value = DB()[key]
	if value == nil then return DEFAULTS[key] end
	return value
end

local listeners = {}

-- Registers fn(key, value) to be called when a setting changes.
function Options.OnChanged(fn)
	listeners[#listeners + 1] = fn
end

local panel -- defined below

function Options.Set(key, value)
	if Options.Get(key) == value then return end
	DB()[key] = value
	for i = 1, #listeners do Util.SafeCall(listeners[i], key, value) end
	if panel and panel:IsShown() then panel:Refresh() end
end

-- Options page -----------------------------------------------------------------

local WIDTH = 560

local function CreateCheckbox(parent, label, description, key)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check.label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	check.label:SetPoint("LEFT", check, "RIGHT", 4, 1)
	check.label:SetText(label)
	check.description = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	check.description:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 30, -2)
	check.description:SetWidth(WIDTH - 40)
	check.description:SetJustifyH("LEFT")
	check.description:SetText(description)
	check:SetScript("OnClick", function(self)
		Options.Set(key, self:GetChecked() and true or false)
	end)
	check.key = key
	return check
end

panel = CreateFrame("Frame")
panel.name = addonName
panel:Hide()

-- Everything sits on `content`, inside a scroll frame, so a small settings window (or a big
-- status) scrolls instead of running off the bottom. The bar hides when everything fits.
-- It's the thin bar the game's own settings use, or the old panel bar on a client without it.
local function HasTemplate(name)
	return C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(name) ~= nil
end

local scroll
if ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar and HasTemplate("MinimalScrollBar") then
	scroll = CreateFrame("ScrollFrame", nil, panel)
	scroll:SetPoint("TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", -22, 4)
	local bar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)
	bar:SetHideIfUnscrollable(true)
	scroll:EnableMouseWheel(true)
else
	scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", -30, 4) -- this bar sits outside the frame, on its right
	scroll.scrollBarHideable = true
end
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(WIDTH + 32, 1)
scroll:SetScrollChild(content)
scroll:SetScript("OnSizeChanged", function(_, width)
	content:SetWidth(math.max(width, 1))
end)

local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(addonName)

local lookupsCheck = CreateCheckbox(content, L.OPT_LOOKUPS,
	Util.HasPartySync() and L.OPT_LOOKUPS_DESC or L.OPT_LOOKUPS_DESC_NO_SYNC, "lookups")
lookupsCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -16)

local itemsCheck = CreateCheckbox(content, L.OPT_ITEMS, L.OPT_ITEMS_DESC, "loadItems")
itemsCheck:SetPoint("TOPLEFT", lookupsCheck.description, "BOTTOMLEFT", -30, -12)

local questsCheck = CreateCheckbox(content, L.OPT_QUESTS, L.OPT_QUESTS_DESC, "searchQuests")
questsCheck:SetPoint("TOPLEFT", itemsCheck.description, "BOTTOMLEFT", -30, -12)

local warning = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
warning:SetPoint("TOPLEFT", questsCheck.description, "BOTTOMLEFT", 0, -6)
warning:SetWidth(WIDTH - 40)
warning:SetJustifyH("LEFT")
warning:SetTextColor(1, 0.5, 0.25)
warning:SetText(L.OPT_QUESTS_WARNING)

-- Actions: the other /atts commands. ns.Commands, ns.Index... load after this file, so they're
-- looked up when a button is used.

local function RunCommand(name)
	if ns.Commands then ns.Commands.Run(name) end
end

local function CloseSettings()
	if SettingsPanel and SettingsPanel:IsShown() then
		HideUIPanel(SettingsPanel)
	elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
		HideUIPanel(InterfaceOptionsFrame)
	end
end

StaticPopupDialogs.ATTSEARCH_CLEAR_CACHE = {
	text = L.OPT_CLEAR_CONFIRM,
	button1 = YES,
	button2 = NO,
	OnAccept = function() RunCommand("clearcache") end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local actionsHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
actionsHeader:SetPoint("TOPLEFT", warning, "BOTTOMLEFT", -30, -16)
actionsHeader:SetText(L.OPT_ACTIONS)

-- A button with its description on the right. Returns the row, as tall as the taller of the
-- two, so a description that wraps onto several lines pushes the next row down.
local function CreateAction(anchor, label, description, onClick)
	local row = CreateFrame("Frame", nil, content)
	row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
	row:SetWidth(WIDTH)
	local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	button:SetSize(170, 22)
	button:SetPoint("TOPLEFT")
	button:SetText(label)
	button:SetScript("OnClick", onClick)
	local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", button, "TOPRIGHT", 10, -4)
	text:SetWidth(WIDTH - 190)
	text:SetJustifyH("LEFT")
	text:SetText(description)
	row:SetHeight(math.max(button:GetHeight(), text:GetStringHeight() + 4))
	return row
end

local openAction = CreateAction(actionsHeader, L.OPT_OPEN, L.OPT_OPEN_DESC, function()
	CloseSettings()
	RunCommand("open")
end)
local clearAction = CreateAction(openAction, L.OPT_CLEAR, L.OPT_CLEAR_DESC, function()
	StaticPopup_Show("ATTSEARCH_CLEAR_CACHE")
end)

-- Status: the same lines as /atts status, kept up to date while the page is open.
local statusHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
statusHeader:SetPoint("TOPLEFT", clearAction, "BOTTOMLEFT", 0, -16)
statusHeader:SetText(L.OPT_STATUS)

-- One row per status line: a gold label, and the value next to it.
local STATUS_LABEL_WIDTH = 150
local statusRows = {}

local footer = content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
footer:SetWidth(WIDTH)
footer:SetJustifyH("LEFT")
footer:SetText(L.OPT_FOOTER)

local function StatusRow(i)
	local row = statusRows[i]
	if row then return row end
	row = CreateFrame("Frame", nil, content)
	row:SetSize(WIDTH, 1)
	if i == 1 then
		row:SetPoint("TOPLEFT", statusHeader, "BOTTOMLEFT", 0, -8)
	else
		row:SetPoint("TOPLEFT", statusRows[i - 1], "BOTTOMLEFT", 0, -5)
	end
	row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	row.label:SetPoint("TOPLEFT")
	row.label:SetWidth(STATUS_LABEL_WIDTH)
	row.label:SetJustifyH("LEFT")
	row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.value:SetPoint("TOPLEFT", row.label, "TOPRIGHT", 10, 0)
	row.value:SetWidth(WIDTH - STATUS_LABEL_WIDTH - 10)
	row.value:SetJustifyH("LEFT")
	row.value:SetSpacing(2)
	statusRows[i] = row
	footer:ClearAllPoints()
	footer:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -16)
	return row
end

local function RefreshStatus()
	if not ns.Commands then return end
	local rows = ns.Commands.StatusRows()
	for i = 1, #rows do
		local row = StatusRow(i)
		row.label:SetText(rows[i][1])
		row.value:SetText(rows[i][2])
		row:SetHeight(math.max(row.label:GetStringHeight(), row.value:GetStringHeight()))
	end
	-- Scroll range: from the top of the page to below the footer.
	local top, bottom = content:GetTop(), footer:GetBottom()
	if top and bottom then content:SetHeight(math.max(top - bottom + 16, 1)) end
end

function panel:Refresh()
	local lookups = Options.Get("lookups")
	lookupsCheck:SetChecked(lookups)
	-- Item and quest lookups are server lookups too, so they need the first option.
	for _, check in ipairs({ itemsCheck, questsCheck }) do
		check:SetChecked(Options.Get(check.key))
		check:SetEnabled(lookups)
		check.label:SetFontObject(lookups and "GameFontHighlight" or "GameFontDisable")
	end
	RefreshStatus()
end
panel:SetScript("OnShow", panel.Refresh)

local STATUS_REFRESH_SECONDS = 1
local sinceRefresh = 0
panel:SetScript("OnUpdate", function(_, elapsed)
	sinceRefresh = sinceRefresh + elapsed
	if sinceRefresh < STATUS_REFRESH_SECONDS then return end
	sinceRefresh = 0
	RefreshStatus()
end)

local category
if Settings and Settings.RegisterCanvasLayoutCategory then
	category = Settings.RegisterCanvasLayoutCategory(panel, addonName)
	Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
	InterfaceOptions_AddCategory(panel)
end

-- Opens this page in the game's settings.
function Options.Open()
	if category and Settings.OpenToCategory then
		Settings.OpenToCategory(category:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel) -- the first call can land on the wrong page
	end
end
