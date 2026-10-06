-- ATT-Search: Filters
-- Works out whether, and exactly why, ATT's main list hides a result.
--
-- ATT hides a row when the row, or any parent above it, is not visible. A group ends up
-- not visible for one of two reasons (see ATT's DataHandling UpdateGroup):
-- 1. A settings filter excludes it: account filters first, then character filters, which
--    unbound (BoE) items skip.
-- 2. It passes the filters but is done, and the matching "show completed" option is off.
local _, ns = ...
local ATT, Util, L = ns.ATT, ns.Util, ns.L

local Filters = {}
ns.Filters = Filters

-- ATT's filter names, in the order ATT applies them, with the reason to show.
local ACCOUNT_FILTERS = {
	{ "Unobtainable", L.REASON_UNOBTAINABLE },
	{ "Event", L.REASON_EVENT },
	{ "ExpansionContent", L.REASON_EXPANSION },
	{ "PvP", L.REASON_PVP },
	{ "ChallengeMaster", L.REASON_CHALLENGE_MODE },
	{ "PetBattles", L.REASON_PET_BATTLES },
	{ "Skyriding", L.REASON_SKYRIDING },
	{ "UnavailablePersonalLoot", L.REASON_PERSONAL_LOOT },
}
local CHARACTER_FILTERS = {
	{ "Class", L.REASON_CLASS },
	{ "Level", L.REASON_LEVEL },
	{ "RequireSkill", L.REASON_PROFESSION },
	{ "MinReputation", L.REASON_REPUTATION },
	{ "FilterID", L.REASON_ITEM_TYPE },
	{ "Bound", L.REASON_BOUND },
	{ "CustomCollect", L.REASON_CUSTOM_COLLECT },
}

local function FirstFailing(filters, group)
	for i = 1, #filters do
		local name, reason = filters[i][1], filters[i][2]
		if ATT.IsFilterActive(name) and not ATT.PassesFilter(name, group) then return reason end
	end
end

-- ATT's race filter has no readable on/off state, so it's judged from the group itself.
local function RaceReason(group)
	if not ATT.IsNotForMyRace(group) then return nil end
	local mine = UnitFactionGroup("player")
	local otherName = (mine == "Alliance" and FACTION_HORDE) or (mine == "Horde" and FACTION_ALLIANCE)
	if otherName then
		local r, races = ATT.GetFactionRestriction(group)
		local myFactionID = ATT.GetMyFactionID()
		if (r and myFactionID and r ~= myFactionID)
			or (races and not ATT.PassesFilter("Race_" .. mine, group)) then
			return L.REASON_FACTION_ONLY:format(otherName)
		end
	end
	return L.REASON_RACE
end

-- Which settings filter excludes this one group, or nil if none can be named.
local function SettingsFilterReason(group)
	local reason = FirstFailing(ACCOUNT_FILTERS, group)
	if reason then return reason end
	-- Unbound (BoE) items skip the character filters when that option is on.
	if ATT.IsFilterActive("ItemUnbound") and ATT.PassesFilter("ItemUnbound", group)
		and ATT.GetID(group, "itemID") then
		return nil
	end
	-- Race last: it can't be checked for being on, so only blame it when nothing else applies.
	return FirstFailing(CHARACTER_FILTERS, group) or RaceReason(group)
end

-- Why a group that passes the filters still isn't shown (it's done and hidden as such).
local function CompletionReason(group)
	local collectible, collected = ATT.GetCollection(group)
	if collectible then
		if collected and not ATT.ShowsCollected(group) then return L.REASON_SHOW_COLLECTED_OFF end
		return nil
	end
	local progress, total = ATT.GetProgress(group)
	if total > 0 then
		if progress >= total and not ATT.ShowsCompletedGroups(group) then return L.REASON_SHOW_COMPLETED_OFF end
		return nil
	end
	local trackable, saved = ATT.GetCompletion(group)
	if trackable and saved then return L.REASON_COMPLETED end
	return L.REASON_NOTHING_TO_COLLECT
end

-- Whether a group is shown in the main list: it and every parent up to `root` are visible.
function Filters.IsShownInList(group, root)
	local g = group
	while g and g ~= root do
		if not ATT.IsVisible(g) then return false end
		g = ATT.GetParent(g)
	end
	return true
end

-- Why the main list hides a group, or nil when it's shown. When the cause is a parent,
-- the reason names it: "Expansion filter, on Northrend".
function Filters.HiddenReason(group, root)
	if Filters.IsShownInList(group, root) then return nil end

	-- A parent can be hidden just because everything inside it is, so look for the cause
	-- from the group outward: first a settings filter, then a "show completed" option.
	local reason, cause
	if ATT.HasFilterDetails() then
		local g = group
		while g and g ~= root do
			if not ATT.PassesSettingsFilters(g) then
				reason, cause = SettingsFilterReason(g) or L.REASON_FILTERS, g
				break
			end
			g = ATT.GetParent(g)
		end
	end
	if not reason then
		local fallback
		local g = group
		while g and g ~= root do
			if not ATT.IsVisible(g) then
				local why = CompletionReason(g)
				if why ~= L.REASON_NOTHING_TO_COLLECT then
					if why then reason, cause = why, g break end
				else
					fallback = fallback or why
				end
			end
			g = ATT.GetParent(g)
		end
		if not reason then reason, cause = fallback or L.REASON_FILTERS, group end
	end
	if cause ~= group then
		reason = L.REASON_ON_PARENT:format(reason, Util.CleanText(ATT.GetText(cause)) or UNKNOWN)
	end
	return reason
end
