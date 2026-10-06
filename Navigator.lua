-- ATT-Search: Navigator
-- Shows a result in ATT's main list: expands its parents, then lets ATT scroll to and
-- highlight it.
local _, ns = ...
local ATT, Util = ns.ATT, ns.Util

local Navigator = {}
ns.Navigator = Navigator

local MARK = "__attSearchMark"
local token, lastMarked = 0, nil

-- "Northrend > Borean Tundra > Quests" for a group (the root itself is left out).
function Navigator.GetPath(group, root)
	local parts = {}
	local p = ATT.GetParent(group)
	while p and p ~= root do
		local name = Util.CleanText(ATT.GetText(p))
		if name then table.insert(parts, 1, name) end
		p = ATT.GetParent(p)
	end
	return table.concat(parts, " > ")
end

-- Returns true when the group is now shown, or false plus a reason:
-- "loading" (ATT has no data yet), "stale" (ATT rebuilt its list since the search) or
-- "filtered" (the main list's filters hide it; its parents were still expanded).
function Navigator.Reveal(group)
	local window = ATT.GetMainWindow()
	local root = window and ATT.GetRoot()
	if not root then return false, "loading" end

	-- Make sure the group still belongs to the current tree, then expand its parents.
	local chain, p = {}, ATT.GetParent(group)
	while p and p ~= root do
		chain[#chain + 1] = p
		p = ATT.GetParent(p)
	end
	if p ~= root then return false, "stale" end
	for i = 1, #chain do ATT.SetExpanded(chain[i]) end

	-- Tag the target so ATT can find exactly this row (it compares row[field] == value).
	if lastMarked then rawset(lastMarked, MARK, nil) end
	token = token + 1
	rawset(group, MARK, token)
	lastMarked = group

	if not window:IsShown() then window:Show() end
	ATT.ScrollToAndRefresh(window, MARK, token)

	local rows = ATT.GetShownRows(window)
	if rows then
		for i = 1, #rows do
			if rows[i] == group then return true end
		end
	end
	return false, "filtered"
end
