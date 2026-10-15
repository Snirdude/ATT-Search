-- ATT-Search: Commands
-- Slash commands (also run by the options page), the key binding, and startup.
local _, ns = ...
local ATT, Util, Index, SearchBar, Options, L = ns.ATT, ns.Util, ns.Index, ns.SearchBar, ns.Options, ns.L

local Commands = {}
ns.Commands = Commands

local INDEX_DELAY_SECONDS = 5

-- Key binding (Bindings.xml). These names are globals because WoW requires it.
BINDING_HEADER_ATTSEARCH = L.BINDING_HEADER
BINDING_NAME_ATTSEARCH_FOCUS = L.BINDING_FOCUS
function ATTSearch_Focus()
	SearchBar.Focus()
end

-- Slash commands -------------------------------------------------------------

local function RebuildIndex()
	Index:Reset()
	Index:Ensure(ATT.GetRoot())
end

-- What the background name loading is doing, as { label, value } rows (/atts status and the
-- options page show them). A value may have a second line.
function Commands.StatusRows()
	local s, N = Index:GetStatus(), Util.FormatNumber
	local paused
	if s.pausedBy == "off" then
		paused = L.STATUS_LOOKUPS_OFF
	elseif s.pausedBy == "backoff" and not s.partySyncAPI then
		paused = L.STATUS_PAUSED_BACKOFF_NO_SYNC:format(s.backoffSeconds)
	elseif s.pausedBy then
		paused = L["STATUS_PAUSED_" .. s.pausedBy:upper()]:format(s.backoffSeconds)
	end
	local index = L.STATUS_INDEX_IDLE
	if s.state == "ready" then
		index = L.STATUS_INDEX_READY:format(N(s.count))
	elseif s.state == "building" then
		index = L.STATUS_INDEX_BUILDING:format(N(s.count))
	end
	local quests
	if s.questWait == nil then
		quests = L.STATUS_QUESTS_RUNNING
	elseif s.questWait == "off" then
		quests = L.STATUS_QUESTS_OFF
	elseif s.questWait == "yield" then
		quests = L.STATUS_QUESTS_YIELD:format(s.questBackoffSeconds)
	elseif s.questWait == "backoff" then
		quests = L.STATUS_QUESTS_BACKOFF:format(s.questBackoffSeconds)
	else -- "paused": for the same reason as all lookups
		quests = paused or L.STATUS_LOOKUPS_OFF
	end
	local rows = {
		{ L.STATUS_INDEX, index },
		{ L.STATUS_LOOKUPS, paused or L.STATUS_LOOKUPS_RUNNING:format(s.rate) },
		{ L.STATUS_QUESTS, quests .. "\n" .. L.STATUS_QUESTS_COUNTS:format(N(s.questsWaiting), N(s.questsSent), N(s.questsNoData)) },
		{ L.STATUS_OTHER, L.STATUS_OTHER_COUNTS:format(N(s.queued), N(s.waiting), N(s.pending), N(s.itemsNoData)) },
	}
	if s.partySyncAPI then -- Retail only
		rows[#rows + 1] = { L.STATUS_PARTY_SYNC, s.partySync and L.STATUS_PARTY_SYNC_ON or L.STATUS_PARTY_SYNC_OFF }
	end
	rows[#rows + 1] = { L.STATUS_SERVER, L.STATUS_SERVER_COUNTS:format(N(s.sent), N(s.refused), N(s.refusedOurs)) }
	rows[#rows + 1] = { L.STATUS_REPLIES:format(s.statsWindow), L.STATUS_REPLIES_COUNT:format(N(s.recentReplies)) }
	return rows
end

local commands = {
	help = function()
		Util.Print(L.HELP_OPEN)
		Util.Print(L.HELP_SEARCH)
		Util.Print(L.HELP_ITEMS)
		Util.Print(L.HELP_CLEARCACHE)
		Util.Print(L.HELP_QUESTS)
		Util.Print(L.HELP_LOOKUPS)
		Util.Print(L.HELP_STATUS)
		Util.Print(L.HELP_OPTIONS)
	end,
	options = function()
		Options.Open()
	end,
	["quests on"] = function()
		Options.Set("searchQuests", true)
		Util.Print(L.QUESTS_ON)
		Util.Print("|cffff8040" .. L.OPT_QUESTS_WARNING .. "|r")
		if not Options.Get("lookups") then Util.Print(L.NEEDS_LOOKUPS) end
	end,
	["quests off"] = function()
		Options.Set("searchQuests", false)
		Util.Print(L.QUESTS_OFF)
	end,
	["lookups on"] = function()
		Options.Set("lookups", true)
		Util.Print(L.LOOKUPS_ON)
	end,
	["lookups off"] = function()
		Options.Set("lookups", false)
		Util.Print(L.LOOKUPS_OFF)
	end,
	status = function()
		local rows = Commands.StatusRows()
		for i = 1, #rows do
			Util.Print("|cffffd100" .. rows[i][1] .. ":|r " .. (rows[i][2]:gsub("\n", ". ")))
		end
	end,
	clearcache = function()
		Index:ClearCache()
		RebuildIndex()
		Util.Print(L.CACHE_CLEARED)
	end,
	["items on"] = function()
		Options.Set("loadItems", true)
		Util.Print(L.ITEMS_ON)
		if not Options.Get("lookups") then Util.Print(L.NEEDS_LOOKUPS) end
	end,
	["items off"] = function()
		Options.Set("loadItems", false)
		Util.Print(L.ITEMS_OFF)
	end,
}
commands.warmup = commands["items on"] -- the name before "Load all item names" became an option

-- Runs a command by name, the same as typing it after /atts ("open" is plain /atts).
function Commands.Run(name)
	if name == "open" then
		SearchBar.Focus()
	elseif commands[name] then
		commands[name]()
	end
end

SLASH_ATTSEARCH1 = "/atts"
SLASH_ATTSEARCH2 = "/attsearch"
SlashCmdList.ATTSEARCH = function(message)
	message = Util.Trim(message or "")
	local command = commands[message:lower()]
	if command then
		command()
	else
		SearchBar.Focus(message) -- anything else is a search
	end
end

-- Startup --------------------------------------------------------------------
-- Once ATT's data is in: add the search bar, and build the index in the background (out of
-- combat) so it's usually ready before the first search.

local function StartIndexing()
	C_Timer.After(INDEX_DELAY_SECONDS, function()
		Index:Ensure(ATT.GetRoot())
	end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		ATT.OnDataReady(function()
			SearchBar.Attach()
			if InCombatLockdown() then
				self:RegisterEvent("PLAYER_REGEN_ENABLED")
			else
				StartIndexing()
			end
		end)
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		StartIndexing()
	end
end)
events:RegisterEvent("PLAYER_LOGIN")
