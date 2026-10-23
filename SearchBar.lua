-- ATT-Search: SearchBar
-- The search bar on top of ATT's main list, and the search logic behind it: debounced
-- searching, keyboard selection, opening results and waypoints.
local _, ns = ...
local ATT, Util, Index, Filters, Navigator, ResultsList, Options, L =
	ns.ATT, ns.Util, ns.Index, ns.Filters, ns.Navigator, ns.ResultsList, ns.Options, ns.L

local SearchBar = {}
ns.SearchBar = SearchBar

local BAR_HEIGHT = 30
local DEBOUNCE_SECONDS = 0.15
local REFRESH_SECONDS = 0.5
local SCROLL_STEP = 3
local COG_SIZE = 16

local window, bar, box, list, cog
local debounceTimer, refreshTimer

-- What the results list shows. `wantOpen` is true only while the player wants the list open
-- (typing, focusing the box, arrow keys): background re-searches update the results but
-- never reopen a list the player closed.
local model = {
	query = nil,      -- text of the last search, or nil
	results = {},
	total = 0,        -- all matches (results holds the best of them)
	selected = 0,
	offset = 0,       -- first result shown (scroll position)
	footer = "",
	wantOpen = false,
}

local function FooterText()
	local parts = {}
	if Index:IsBuilding() then
		parts[#parts + 1] = L.INDEXING_PROGRESS:format(Index:GetCount())
	end
	if model.query then
		if #model.results == 0 then
			if not Index:IsBuilding() then parts[#parts + 1] = L.NO_MATCHES end
		elseif model.total > #model.results then
			parts[#parts + 1] = L.TOP_MATCHES:format(#model.results, model.total)
		else
			parts[#parts + 1] = (model.total == 1 and L.MATCH_ONE or L.MATCH_MANY):format(model.total)
		end
	end
	if Index:IsReady() then
		if Index:GetLoadingCount() > 0 then
			parts[#parts + 1] = L.LOADING_NAMES:format(Index:GetLoadingCount())
		elseif Index:GetPendingCount() > 0 then
			parts[#parts + 1] = L.NOT_LOADED:format(Index:GetPendingCount())
		end
	end
	return table.concat(parts, "  |  ")
end

local function Render()
	model.footer = FooterText()
	list:Render(model)
end

local function HideResults()
	model.wantOpen = false
	if refreshTimer then refreshTimer:Cancel() refreshTimer = nil end
	Index:CancelSearch()
	if list then list:Hide() end
end

local function ClearResults()
	model.query, model.results, model.total = nil, {}, 0
end

local function Select(index)
	local n = #model.results
	if n == 0 then model.selected = 0 return end
	model.wantOpen = true
	if index < 1 then index = n elseif index > n then index = 1 end
	model.selected = index
	if index <= model.offset then
		model.offset = index - 1
	elseif index > model.offset + ResultsList.MAX_ROWS then
		model.offset = index - ResultsList.MAX_ROWS
	end
	Render()
end

-- Searching ------------------------------------------------------------------

local function FindResult(results, group)
	for i = 1, #results do
		if results[i].group == group then return i end
	end
end

-- Puts the new results in the model. A new search starts at the top; a refresh (`keep`) stays
-- on the selected result, at the same row of the list, so the player's place isn't lost.
local function SetResults(results, total, keep)
	local previous = keep and model.results[model.selected]
	local previousRow = model.selected - model.offset
	model.results, model.total = results, total
	local n = #results
	if not previous or n == 0 then
		model.selected, model.offset = (n > 0) and 1 or 0, 0
		return
	end
	-- It may have dropped out of the best results; then keep the same position instead.
	local index = FindResult(results, previous.group) or math.min(model.selected, n)
	model.selected = index
	model.offset = math.min(math.max(0, n - ResultsList.MAX_ROWS), math.max(0, index - previousRow))
end

-- `refresh` is true for background re-searches of the same text (see Index:OnChanged below).
local function RunSearch(text, refresh)
	local root = ATT.GetRoot()
	if not root then
		ClearResults()
		if model.wantOpen then
			Render()
			list:SetFooter(L.ATT_LOADING_FOOTER)
		end
		return
	end
	Index:Ensure(root)
	model.query = text
	Index:Search(text, function(results, total)
		if text ~= model.query then return end
		SetResults(results, total, refresh)
		if model.wantOpen then Render() end
	end)
end

local function QueueSearch()
	if debounceTimer then debounceTimer:Cancel() debounceTimer = nil end
	local text = box:GetText() or ""
	if #text < Index.MIN_NAME_CHARS and not Index.IsIDQuery(text) then
		ClearResults()
		HideResults()
		return
	end
	model.wantOpen = true
	debounceTimer = C_Timer.NewTimer(DEBOUNCE_SECONDS, function()
		debounceTimer = nil
		RunSearch(text)
	end)
end

-- While the index grows (or late names load), refresh the open results now and then.
Index:OnChanged(function()
	if not (list and list:IsShown()) then return end
	list:SetFooter(FooterText())
	if model.query and not refreshTimer then
		refreshTimer = C_Timer.NewTimer(REFRESH_SECONDS, function()
			refreshTimer = nil
			if model.query and list:IsShown() then RunSearch(model.query, true) end
		end)
	end
end)

-- Opening results ------------------------------------------------------------

-- Click / Enter: show the result in the main list. The list closes; the text stays, so
-- focusing the box brings the results back.
local function Open(index)
	local result = model.results[index]
	if not result then return end
	HideResults()
	box:ClearFocus()
	local ok, reason = Navigator.Reveal(result.group)
	if ok then return end
	if reason == "filtered" then
		local why = result.hiddenReason or Filters.HiddenReason(result.group, Index:GetRoot()) or L.REASON_FILTERS
		Util.Print(L.HIDDEN_CHAT:format(ResultsList.DisplayName(result), why))
	elseif reason == "stale" then
		Util.Print(L.LIST_REBUILT)
		Index:Reset()
		if model.query then
			model.wantOpen = true
			RunSearch(model.query)
		end
	else
		Util.Print(L.ATT_STILL_LOADING)
	end
end

-- Shift+click / Shift+Enter: open an achievement in the game's Achievements window, and set a
-- waypoint to anything else (or to an achievement the window can't show).
local function ShiftOpen(index)
	local result = model.results[index]
	if not result then return end
	HideResults()
	box:ClearFocus()
	local achievementID = ATT.GetAchievementID(result.group)
	if achievementID and Util.OpenAchievement(achievementID) then return end
	if not ATT.AddWaypoint(result.group) then Util.Print(L.NO_WAYPOINTS) end
end

local function Activate(index, shift)
	if shift then ShiftOpen(index) else Open(index) end
end

-- Construction ---------------------------------------------------------------

local function CreateBox()
	-- SearchBoxTemplate gives the magnifier and clear button; fall back to a plain input box
	-- on any client that doesn't have it.
	-- (Named: InputBoxTemplate names its textures after the box.)
	local ok, searchBox = pcall(CreateFrame, "EditBox", "ATTSearchBox", bar, "SearchBoxTemplate")
	local plain = not (ok and searchBox)
	local editBox = plain and CreateFrame("EditBox", "ATTSearchBox", bar, "InputBoxTemplate") or searchBox
	if plain then
		editBox.Instructions = editBox:CreateFontString(nil, "ARTWORK", "GameFontDisable")
		editBox.Instructions:SetPoint("LEFT", editBox, "LEFT", 2, 0)
	end
	if editBox.Instructions then editBox.Instructions:SetText(L.SEARCH_PLACEHOLDER) end
	editBox:SetHeight(20)
	editBox:SetPoint("LEFT", bar, "LEFT", 12, 0)
	editBox:SetPoint("RIGHT", cog, "LEFT", -6, 0)
	editBox:SetAutoFocus(false)

	editBox:HookScript("OnTextChanged", function(self, userInput)
		local empty = (self:GetText() or "") == ""
		if plain then self.Instructions:SetShown(empty) end -- SearchBoxTemplate does its own
		if empty then
			ClearResults()
			HideResults()
		elseif userInput then
			QueueSearch()
		end
	end)
	editBox:HookScript("OnEditFocusGained", function()
		Index:Ensure(ATT.GetRoot())
		if model.query and #model.results > 0 then
			model.wantOpen = true
			Render()
		end
	end)
	editBox:HookScript("OnEditFocusLost", function()
		C_Timer.After(0.2, function()
			if not list:IsMouseOver() and not editBox:HasFocus() then HideResults() end
		end)
	end)
	editBox:SetScript("OnEnterPressed", function()
		if #model.results > 0 then Activate(math.max(model.selected, 1), IsShiftKeyDown()) end
	end)
	editBox:SetScript("OnEscapePressed", function(self)
		if list:IsShown() then HideResults() else self:ClearFocus() end
	end)
	editBox:SetScript("OnArrowPressed", function(_, key)
		if key == "UP" then Select(model.selected - 1) elseif key == "DOWN" then Select(model.selected + 1) end
	end)
	editBox:SetScript("OnTabPressed", function()
		Select(model.selected + (IsShiftKeyDown() and -1 or 1))
	end)
	return editBox
end

local function CreateBar()
	bar = CreateFrame("Frame", nil, window, BackdropTemplateMixin and "BackdropTemplate")
	bar:SetHeight(BAR_HEIGHT)
	bar:SetPoint("BOTTOMLEFT", window, "TOPLEFT", 0, -2)
	bar:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", 0, -2)
	bar:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	bar:SetBackdropColor(0, 0, 0, 0.9)
	bar:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	bar:EnableMouse(true)
	-- Keep the bar on screen when the window is dragged to the top edge.
	window:SetClampRectInsets(0, 0, BAR_HEIGHT, 0)

	-- Cog at the end of the bar: opens the options page.
	cog = CreateFrame("Button", nil, bar)
	cog:SetSize(COG_SIZE, COG_SIZE)
	cog:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
	cog:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
	cog:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton", "ADD")
	cog:SetScript("OnClick", function()
		HideResults()
		Options.Open()
	end)
	cog:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L.OPTIONS_BUTTON)
		GameTooltip:Show()
	end)
	cog:SetScript("OnLeave", GameTooltip_Hide)

	box = CreateBox()

	-- Dragging the bar (or the box) moves the ATT window. The bar sits above the window, so
	-- ATT always treats this as a move, never a resize.
	local function StartDrag() ATT.StartWindowDrag(window) end
	local function StopDrag() ATT.StopWindowDrag(window) end
	bar:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then StartDrag() end
	end)
	bar:SetScript("OnMouseUp", StopDrag)
	box:RegisterForDrag("LeftButton")
	box:SetScript("OnDragStart", StartDrag)
	box:SetScript("OnDragStop", StopDrag)

	list = ResultsList.Create(bar, {
		OnActivate = Activate,
		OnHover = function(index)
			model.selected = index
			list:ShowSelection(index)
		end,
		OnScroll = function(delta)
			local maxOffset = math.max(0, #model.results - ResultsList.MAX_ROWS)
			model.offset = math.min(maxOffset, math.max(0, model.offset - delta * SCROLL_STEP))
			Render()
		end,
	})

	window:HookScript("OnHide", HideResults)
end

-- Public API -----------------------------------------------------------------

-- Adds the search bar to ATT's main list window (once).
function SearchBar.Attach()
	if bar then return true end
	window = ATT.GetMainWindow()
	if not window then return false end
	CreateBar()
	return true
end

-- Opens the main list and focuses the search bar, optionally searching for `text`.
function SearchBar.Focus(text)
	if not SearchBar.Attach() then
		Util.Print(L.MAIN_LIST_NOT_READY)
		return
	end
	if not window:IsShown() then window:Show() end
	box:SetFocus()
	if text and text ~= "" then
		box:SetText(text)
		QueueSearch()
	end
end
