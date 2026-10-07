-- ATT-Search: ResultsList
-- The dropdown under the search bar: result rows, their tooltips and the footer line.
-- It only draws what it's given and reports clicks; SearchBar.lua decides what happens.
local _, ns = ...
local ATT, Util, Filters, L = ns.ATT, ns.Util, ns.Filters, ns.L

local ResultsList = {}
ns.ResultsList = ResultsList

local ROW_HEIGHT = 36
local MAX_ROWS = 10
local QUESTION_MARK_ICON = 134400
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:16:16|t"
local CROSS = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:16:16|t"
local HINT_R, HINT_G, HINT_B = 0.29, 0.65, 1

ResultsList.MAX_ROWS = MAX_ROWS

-- Collected / completed status, from the same fields ATT uses for its own rows: a
-- collectible's collected state, else a group's progress, else a quest's completed state.
-- Returns the text for the row (an icon or "5/12") and a tooltip line (nil for nothing).
local function Status(group)
	local collectible, collected = ATT.GetCollection(group)
	if collectible then
		if collected then return CHECK, L.COLLECTED end
		return CROSS, L.NOT_COLLECTED
	end
	local progress, total = ATT.GetProgress(group)
	if total > 0 then
		if progress >= total then return CHECK, L.ALL_COLLECTED end
		return ("|cffffd100%d/%d|r"):format(progress, total), L.PROGRESS:format(progress, total)
	end
	local trackable, saved = ATT.GetCompletion(group)
	if trackable then
		if saved then return CHECK, L.COMPLETED end
		return CROSS, L.NOT_COMPLETED
	end
	return "", nil
end

-- The group's own id (e.g. NPC ID), then Item ID and Spell ID when it has them too.
local function AddIDLines(tooltip, group)
	local shown = {}
	local function Line(field, id)
		if shown[field] or not id then return end
		shown[field] = true
		tooltip:AddDoubleLine(L.ID_LABELS[field] or field, tostring(id), 0.6, 0.6, 0.6, 1, 1, 1)
	end
	local key, id = ATT.GetKey(group)
	if key and key ~= "headerID" and type(id) == "number" and id ~= 0 then Line(key, id) end
	Line("itemID", ATT.GetID(group, "itemID"))
	Line("spellID", ATT.GetID(group, "spellID"))
end

local function ShowTooltip(row, result)
	local group = result.group
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Util.DisplayText(ATT.GetText(group)))
	if result.path ~= "" then GameTooltip:AddLine(result.path, 0.7, 0.7, 0.7, true) end
	local statusText, statusLine = Status(group)
	if statusLine then
		local icon = (statusText == CHECK or statusText == CROSS) and (statusText .. " ") or ""
		GameTooltip:AddLine(icon .. statusLine, 1, 1, 1)
	end
	if result.hiddenReason then
		GameTooltip:AddLine(L.HIDDEN_TOOLTIP:format(result.hiddenReason), 1, 0.5, 0.25, true)
	end
	AddIDLines(GameTooltip, group)
	GameTooltip:AddLine(L.CLICK_HINT, HINT_R, HINT_G, HINT_B)
	if ATT.HasCoords(group) then GameTooltip:AddLine(L.SHIFT_CLICK_HINT, HINT_R, HINT_G, HINT_B) end
	GameTooltip:Show()
end

-- Fills one row. Results that the main list hides are greyed out with the reason first.
local function FillRow(row, result)
	local group = result.group
	row.status:SetText((Status(group)))
	if not pcall(row.icon.SetTexture, row.icon, ATT.GetIcon(group) or QUESTION_MARK_ICON) then
		row.icon:SetTexture(QUESTION_MARK_ICON)
	end
	local hidden = result.hiddenReason ~= nil
	row.icon:SetDesaturated(hidden)
	row.icon:SetAlpha(hidden and 0.6 or 1)
	if hidden then
		row.name:SetText("|cff808080" .. (Util.CleanText(ATT.GetText(group)) or UNKNOWN) .. "|r")
		local reason = "|cffff8040" .. L.HIDDEN_ROW:format(result.hiddenReason) .. "|r"
		row.path:SetText(result.path ~= "" and (reason .. "  " .. result.path) or reason)
	else
		row.name:SetText(Util.DisplayText(ATT.GetText(group)))
		row.path:SetText(result.path ~= "" and result.path or " ")
	end
end

local function CreateRow(list, i)
	local panel = list.panel
	local row = CreateFrame("Button", nil, panel)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -5 - (i - 1) * ROW_HEIGHT)
	row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5 - (i - 1) * ROW_HEIGHT)
	row:RegisterForClicks("LeftButtonUp")

	row.selected = row:CreateTexture(nil, "BACKGROUND")
	row.selected:SetAllPoints()
	row.selected:SetColorTexture(HINT_R, HINT_G, HINT_B, 0.25)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(28, 28)
	row.icon:SetPoint("LEFT", 4, 0)

	-- Check / cross / progress on the right; name and path end where it starts.
	row.status = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.status:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	row.status:SetJustifyH("RIGHT")

	row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 1)
	row.name:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row.path = row:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	row.path:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, -1)
	row.path:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
	row.path:SetJustifyH("LEFT")
	row.path:SetWordWrap(false)

	row:SetScript("OnClick", function(self)
		list.handlers.OnActivate(self.index, IsShiftKeyDown())
	end)
	row:SetScript("OnEnter", function(self)
		list.handlers.OnHover(self.index)
		local result = list.model and list.model.results[self.index]
		if result then ShowTooltip(self, result) end
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	return row
end

-- Methods --------------------------------------------------------------------

local Methods = {}

-- Draws the model: { results, selected, offset, footer }. Each result gets its path and
-- hidden reason filled in here, only for the rows actually shown.
function Methods:Render(model)
	self.model = model
	local root = ns.Index:GetRoot()
	local visible = math.min(#model.results, MAX_ROWS)
	for i = 1, MAX_ROWS do
		local row = self.rows[i]
		local index = model.offset + i
		local result = model.results[index]
		if i <= visible and result then
			row.index = index
			result.path = result.path or ns.Navigator.GetPath(result.group, root)
			result.hiddenReason = Filters.HiddenReason(result.group, root)
			FillRow(row, result)
			row.selected:SetShown(index == model.selected)
			row:Show()
		else
			row.index = nil
			row:Hide()
		end
	end
	self.footer:SetText(model.footer or "")
	self.panel:SetHeight(10 + visible * ROW_HEIGHT + 24)
	self.panel:Show()
end

-- Moves the selection highlight without redrawing the rows.
function Methods:ShowSelection(selected)
	for i = 1, MAX_ROWS do
		local row = self.rows[i]
		row.selected:SetShown(row.index ~= nil and row.index == selected)
	end
end

function Methods:SetFooter(text) self.footer:SetText(text or "") end
function Methods:Hide() self.panel:Hide() GameTooltip_Hide() end
function Methods:IsShown() return self.panel:IsShown() end
function Methods:IsMouseOver() return self.panel:IsMouseOver() end

-- Creates the dropdown under `anchor`. handlers: OnActivate(index, shift), OnHover(index),
-- OnScroll(delta).
function ResultsList.Create(anchor, handlers)
	local list = setmetatable({ handlers = handlers, rows = {} }, { __index = Methods })

	local panel = CreateFrame("Frame", nil, anchor, BackdropTemplateMixin and "BackdropTemplate")
	panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 2)
	panel:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, 2)
	panel:SetFrameStrata("DIALOG")
	-- Solid background so ATT's rows don't show through the results.
	panel:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	panel:SetBackdropColor(0.06, 0.06, 0.08, 1)
	panel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	panel:EnableMouse(true)
	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(_, delta) handlers.OnScroll(delta) end)
	panel:Hide()
	list.panel = panel

	for i = 1, MAX_ROWS do list.rows[i] = CreateRow(list, i) end

	local footer = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 6)
	footer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 6)
	footer:SetJustifyH("LEFT")
	list.footer = footer

	return list
end
