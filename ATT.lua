-- ATT-Search: ATT adapter
-- Every use of All The Things' internals goes through this file. None of it is an official
-- ATT API, so when an ATT update renames something, this is the only file to fix.
--
-- ATT's list is a tree of "groups" (zones, NPCs, items...). Fields read from groups here:
-- text, icon, g (children), parent, expanded, key (+ the id field it names), itemID,
-- coords, collectible, collected, collectedwarband, progress, total, trackable, saved,
-- nmr / r / races (race and faction), nmc (class), isHQT, u / rwp, and for criteria achievementID /
-- uid / id. Also ATT's own name tables: L.QUEST_NAMES, ObjectNames, NPCNameFromID.
--
-- Careful: reading `text` (or `name`, `link`) runs ATT code, and for quests, NPCs, items and
-- some criteria and objects that code asks the server when the name isn't loaded yet. The
-- index only reads it once the checks below say it's free.
local _, ns = ...
local Get, IsSecret = ns.Util.Get, ns.Util.IsSecret

local ATT = {}
ns.ATT = ATT

local type, rawget, pcall = type, rawget, pcall

local function App()
	return _G.AllTheThings
end

-- Calls an ATT filter function on a group. Treats a missing filter, or one that errors, as
-- passing, so a change in ATT never makes results look hidden by mistake.
local function Passes(filter, group)
	if type(filter) ~= "function" then return true end
	local ok, result = pcall(filter, group)
	return not ok or result
end

-- Main list ------------------------------------------------------------------

function ATT.GetMainWindow()
	local app = App()
	return (app and app.Windows and app.Windows.Prime) or _G.ATTWindowPrime
end

-- The root group of the main list, or nil while ATT is still loading.
function ATT.GetRoot()
	local window = ATT.GetMainWindow()
	return window and window.data
end

-- Calls fn once, as soon as the main list has its data. Listens for ATT's own
-- "OnDataCached" event, with a slow poll as a fallback in case that event has already
-- fired or gets renamed.
function ATT.OnDataReady(fn)
	local done = false
	local function Try()
		if done or not ATT.GetRoot() then return end
		done = true
		fn()
	end
	Try()
	if done then return end
	local app = App()
	if app and type(app.AddEventHandler) == "function" then
		-- ATT's main list stores its data in this same event, so check one frame later.
		pcall(app.AddEventHandler, "OnDataCached", function() C_Timer.After(0, Try) end)
	end
	local ticker
	ticker = C_Timer.NewTicker(2, function()
		Try()
		if done then ticker:Cancel() end
	end, 300)
end

-- Expands a group so its children show in the list.
function ATT.SetExpanded(group)
	group.expanded = true
end

-- Rows the main list currently shows (after its filters), or nil.
function ATT.GetShownRows(window)
	return window.rowData
end

-- Asks the window to scroll to, and highlight, the row whose `field` equals `value`
-- (ATT compares row[field] == value), then refreshes it.
function ATT.ScrollToAndRefresh(window, field, value)
	window:ScrollTo(field, value)
	window:Update()
end

-- Moving the window through ATT's own mouse handlers respects its lock setting and saves
-- the new position.
function ATT.StartWindowDrag(window)
	local onDown = window:GetScript("OnMouseDown")
	if onDown then onDown(window, "LeftButton") end
end

function ATT.StopWindowDrag(window)
	local onUp = window:GetScript("OnMouseUp")
	if onUp then onUp(window, "LeftButton") end
end

-- ATT's own waypoint function (its Alt+right-click): TomTom when installed, otherwise the
-- map pin on the nearest known spot. Returns false when this ATT version doesn't have it.
function ATT.AddWaypoint(group)
	local app = App()
	if not (app and type(app.AddTomTomWaypoint) == "function") then return false end
	ns.Util.SafeCall(app.AddTomTomWaypoint, group)
	return true
end

-- Group fields ---------------------------------------------------------------

function ATT.GetText(group) return Get(group, "text") end
function ATT.GetIcon(group) return Get(group, "icon") end
function ATT.GetChildren(group) return group.g end   -- plain data, safe to read directly
function ATT.GetParent(group) return group.parent end -- plain data, safe to read directly
function ATT.HasCoords(group) return Get(group, "coords") ~= nil end

-- The group's own kind and id, e.g. "npcID", 1234.
function ATT.GetKey(group)
	local key = Get(group, "key")
	if type(key) ~= "string" then return nil end
	return key, Get(group, key)
end

-- A numeric id field (itemID, spellID...), or nil.
function ATT.GetID(group, field)
	local id = Get(group, field)
	if type(id) == "number" and id ~= 0 then return id end
end

-- collectible, collected (on this character or anywhere in the warband)
function ATT.GetCollection(group)
	if not Get(group, "collectible") then return false, false end
	return true, (Get(group, "collected") or Get(group, "collectedwarband")) and true or false
end

-- progress, total for groups that contain collectible things (total is 0 otherwise)
function ATT.GetProgress(group)
	local total = Get(group, "total")
	if type(total) ~= "number" then return 0, 0 end
	local progress = Get(group, "progress")
	return type(progress) == "number" and progress or 0, total
end

-- trackable (can be completed, like a quest), saved (completed)
function ATT.GetCompletion(group)
	return Get(group, "trackable") and true or false, Get(group, "saved") and true or false
end

-- Race and class restrictions for the current character.
function ATT.IsNotForMyRace(group) return Get(group, "nmr") and true or false end
function ATT.IsNotForMyClass(group) return Get(group, "nmc") and true or false end
function ATT.GetFactionRestriction(group) return Get(group, "r"), Get(group, "races") end
function ATT.GetMyFactionID()
	local app = App()
	return app and app.FactionID
end

-- Names ----------------------------------------------------------------------

-- Whether text is a "still loading" placeholder rather than a real name.
function ATT.IsRetrieving(text)
	local app = App()
	local mod = app and app.Modules and app.Modules.RetrievingData
	if mod and type(mod.IsRetrieving) == "function" then return mod.IsRetrieving(text) end
	return text == nil or IsSecret(text) or text == ""
		or string.find(text, RETRIEVING_DATA or "Retrieving", 1, true) ~= nil
end

-- Whether ATT already knows this NPC's name (reading it then costs nothing).
function ATT.IsNPCNameCached(npcID)
	local app = App()
	local cache = app and app.NPCNameFromID
	return type(cache) == "table" and rawget(cache, npcID) ~= nil
end

-- An NPC's readable name from ATT's name table, or nil. The name on the group itself can be
-- stuck hidden: one read while the game restricts addons (12.0.5+) stays hidden there until a
-- reload, while the table keeps only readable names. With `lookUp`, asks for a name that isn't
-- known yet (that may query the server); otherwise only reads what's known.
function ATT.GetNPCName(npcID, lookUp)
	local app = App()
	local cache = app and app.NPCNameFromID
	if type(cache) ~= "table" then return nil end
	local name
	if lookUp then name = Get(cache, npcID) else name = rawget(cache, npcID) end
	if type(name) == "string" and not IsSecret(name) then return name end
end

-- Whether ATT ships this quest's name in its own data (reading it then costs nothing).
-- Every other quest name comes from the server.
function ATT.HasShippedQuestName(questID)
	local app = App()
	local names = app and app.L and app.L.QUEST_NAMES
	return type(names) == "table" and rawget(names, questID) ~= nil
end

-- Whether ATT marks this group, or a parent of it, unobtainable (u) or removed in a patch
-- (rwp). The server has no data for many such quests.
function ATT.IsUnobtainable(group)
	local g = group
	while g do
		if Get(g, "u") or Get(g, "rwp") then return true end
		g = ATT.GetParent(g)
	end
	return false
end

-- Hidden quest triggers: quests that only flag progress and have no data on the server.
function ATT.IsHiddenQuest(group)
	return Get(group, "isHQT") and true or false
end

-- Whether ATT ships this object's name (otherwise ATT names it after an item or NPC, which
-- may ask the server).
function ATT.HasShippedObjectName(objectID)
	local app = App()
	local names = app and app.ObjectNames
	return type(names) == "table" and rawget(names, objectID) ~= nil
end

-- A criteria's own text from the game's achievement data, which never asks the server, or nil
-- when the game has none. (ATT then names the criteria after a quest, NPC or item, and
-- reading those can ask the server.) Mirrors ATT's own lookup in Achievement.lua.
local GetCriteriaByID = _G.GetAchievementCriteriaInfoByID
local GetCriteriaByIndex = _G.GetAchievementCriteriaInfo
local GetNumCriteria = _G.GetAchievementNumCriteria
local function UsableName(ok, name)
	return ok and type(name) == "string" and not IsSecret(name) and not ATT.IsRetrieving(name)
end
function ATT.GetLocalCriteriaName(group)
	local achievementID = Get(group, "achievementID")
	local uid = Get(group, "uid") or Get(group, "criteriaID")
	if type(achievementID) ~= "number" or type(uid) ~= "number" then return nil end
	if GetCriteriaByID then
		local ok, name = pcall(GetCriteriaByID, achievementID, uid, true)
		if UsableName(ok, name) then return name end
	end
	local index = Get(group, "id") or uid
	if GetCriteriaByIndex and GetNumCriteria and type(index) == "number" then
		local ok, count = pcall(GetNumCriteria, achievementID)
		if ok and type(count) == "number" and index <= count then
			local okName, name = pcall(GetCriteriaByIndex, achievementID, index, true)
			if UsableName(okName, name) then return name end
		end
	end
end

-- Filters --------------------------------------------------------------------
-- How ATT decides what the main list shows (see ATT's Modules/Filter.lua and DataHandling).

-- Shown in the list by itself (not counting its parents).
function ATT.IsVisible(group)
	local app = App()
	return Passes(app and app.VisibilityFilter, group)
end

-- Passes all of the player's active settings filters.
function ATT.PassesSettingsFilters(group)
	local app = App()
	return Passes(app and app.GroupFilter, group)
end

-- Collected things are shown ("Show Collected Things").
function ATT.ShowsCollected(group)
	local app = App()
	return Passes(app and app.CollectedItemVisibilityFilter, group)
end

-- Completed groups are shown ("Show Completed Groups").
function ATT.ShowsCompletedGroups(group)
	local app = App()
	return Passes(app and app.GroupVisibilityFilter, group)
end

local function FilterModule()
	local app = App()
	local module = app and app.Modules and app.Modules.Filter
	if module and type(module.Filters) == "table" and type(module.Get) == "table" then
		return module
	end
end

-- Whether ATT can tell us about its individual filters at all.
function ATT.HasFilterDetails()
	return FilterModule() ~= nil
end

-- Whether the named filter (e.g. "Level") is turned on.
function ATT.IsFilterActive(name)
	local module = FilterModule()
	if not module then return false end
	local ok, active = pcall(module.Get[name])
	return ok and active and true or false
end

-- Whether a group passes the named filter.
function ATT.PassesFilter(name, group)
	local module = FilterModule()
	return Passes(module and module.Filters[name], group)
end
