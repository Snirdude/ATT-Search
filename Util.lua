-- ATT-Search: Util
-- Small helpers shared by every file.
local _, ns = ...

local Util = {}
ns.Util = Util

local pcall, type, gsub = pcall, type, string.gsub

-- Values the game hides from addons (Midnight's "secret values") can't be read or compared.
local issecretvalue = issecretvalue or function() return false end
Util.IsSecret = issecretvalue

-- Reading a field on an ATT object can run ATT code (its objects compute fields on demand),
-- so reads are protected. One shared reader function means no closure is created per read,
-- which matters in loops over hundreds of thousands of objects.
local readField
local function Read(t) return t[readField] end
function Util.Get(t, field)
	readField = field
	local ok, value = pcall(Read, t)
	if ok then return value end
end

function Util.Trim(text)
	return (gsub(gsub(text, "^%s+", ""), "%s+$", ""))
end

-- Removes color, texture and atlas codes. Returns nil for anything that isn't readable text.
function Util.CleanText(text)
	if type(text) ~= "string" or issecretvalue(text) then return nil end
	text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = gsub(text, "|cn[^:]*:", "")
	text = gsub(text, "|r", "")
	text = gsub(text, "|T.-|t", "")
	text = gsub(text, "|A.-|a", "")
	text = gsub(text, "|H.-|h%[?(.-)%]?|h", "%1") -- links: just the shown name, no brackets
	text = gsub(text, "|n", " ")
	text = gsub(text, "[\r\n\t]", " ")
	text = Util.Trim(text)
	if text == "" then return nil end
	return text
end

-- Text as the game shows it (keeps ATT's colors), or a cleaned fallback.
function Util.DisplayText(text)
	if type(text) == "string" and not issecretvalue(text) then return text end
	return Util.CleanText(text) or UNKNOWN
end

-- Whether this game version has party sync (Retail only).
function Util.HasPartySync()
	return C_QuestSession ~= nil and C_QuestSession.Exists ~= nil
end

-- 234735 -> "234,735" (in the game's own number format when it has one).
local BreakUpLargeNumbers = BreakUpLargeNumbers
function Util.FormatNumber(n)
	if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
	local text = tostring(n)
	local k
	repeat text, k = gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
	return text
end

local PREFIX = "|cff4AA7FFATT-Search|r: "
function Util.Print(message)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

-- Runs fn(...) and reports an error through WoW's error handler instead of stopping.
function Util.SafeCall(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then geterrorhandler()(err) end
	return ok
end
