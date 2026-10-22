-- ATT-Search: Index
-- Walks ATT's main list tree and keeps a flat, lowercase name index to search.
--
-- Two rules keep this safe on any client:
-- 1. CPU: all work runs in coroutines that share one small time budget per frame.
-- 2. Network: building the index must never make the game ask the server for anything.
--    Many innocent-looking reads do: GetTitleForQuestID and HaveQuestData both query the
--    server for a quest that isn't loaded, and reading a name from ATT runs ATT code that may
--    look up a quest, NPC or item. So during the walk a name is only read when it's known to
--    be on the client already (see Classify). Everything else waits:
--    - Quests wait for the game to load them anyway (for the quest log, ATT's lists...), and
--      are indexed then. Only with the "Load all quest names" option on does ATT-Search ask for them
--      itself, in a strict lane of its own (see "Quest lane"): the server's allowance for quest
--      data is small, and the quest log, objectives and ATT itself need it too.
--    - Other names go into a queue that sends a few requests per second. The rate starts low,
--      rises only while the frame rate stays healthy, and only a few wait for a reply at once.
--    All server lookups pause in combat, while the game restricts addons, and during party sync.
-- Names that cost something are also saved between sessions (see "Saved names").
local _, ns = ...
local ATT, Util, Options = ns.ATT, ns.Util, ns.Options

local Index = {}
ns.Index = Index

local strlower, strfind, strsub, gsub, gmatch = string.lower, string.find, string.sub, string.gsub, string.gmatch
local tremove, sort, concat = table.remove, table.sort, table.concat
local debugprofilestop, type, tostring, coroutine = debugprofilestop, type, tostring, coroutine
local IsItemDataCachedByID = C_Item and C_Item.IsItemDataCachedByID
local DoesItemExistByID = C_Item and C_Item.DoesItemExistByID
local RequestLoadItemDataByID = C_Item and C_Item.RequestLoadItemDataByID
local RequestLoadQuestByID = C_QuestLog and C_QuestLog.RequestLoadQuestByID

local FRAME_BUDGET_MS = 3          -- shared by all jobs, per frame
local REMOTE_MIN_PER_SECOND = 2    -- starting rate of lookups that go to the server
local REMOTE_MAX_PER_SECOND = 10   -- rate reached after ramping up with a healthy frame rate
local REMOTE_RAMP_PER_SECOND = 0.5 -- how fast the rate rises (lookups per second, each second)
local REMOTE_LOW_FPS = 20          -- below this frame rate the rate drops back to the minimum
local REMOTE_START_DELAY = 15      -- seconds after the build before lookups start (lets ATT settle)
local UNANSWERED_BACKOFF_SECONDS = 60 -- pause after an item lookup gets no reply (throttled)
local AFTER_SYNC_SECONDS = 90      -- pause after party sync ends, while the game reloads quests
-- Quest lane (only with the "Load all quest names" option on)
local QUEST_INTERVAL = 0.5         -- at most one quest request per this many seconds
local QUEST_YIELD_SECONDS = 10     -- wait this long after the game or ATT loads a quest
local QUEST_SLOW_REPLY_SECONDS = 2 -- a reply slower than this means the server is busy...
local QUEST_SLOW_BACKOFF_SECONDS = 30 -- ...so pause this long
local QUEST_REFUSED_STREAK = 10    -- our quest requests refused in a row that mean we're throttled
                                   -- (single refusals are normal: some quests have no server data)
-- When the server seems to throttle us (a run of refusals, or a request with no reply at all),
-- the lane pauses this long, the next step each time in a row (the last one repeats). A
-- successful reply from the server goes back to the first.
local QUEST_THROTTLE_PAUSES = { 30, 60, 120, 180, 240, 300 }
local NO_DATA_SESSIONS = 2         -- sessions that must refuse a quest before it's skipped
local QUEST_SYNC_BATCH = 20        -- quests the game already has, answered on the spot, per tick
local MAX_IN_FLIGHT = 4            -- lookups waiting for a server reply at once
local IN_FLIGHT_TIMEOUT = 5        -- seconds before an unanswered lookup stops counting
local REMOTE_TICK = 0.1
local REMOTE_TICK_BUDGET_MS = 3    -- time per tick for lookups (cache hits are fast but not free)
local MAX_REMOTE_ATTEMPTS = 2
local MAX_COLLECT = 3000           -- matches collected before sorting (keeps very common queries cheap)
local MAX_RESULTS = 200            -- matches kept after sorting
local PENDING_RETRY_SECONDS = 60
local NOTIFY_THROTTLE = 2

-- Kinds whose ATT names come from data already on the client (no server query). Criteria and
-- objects usually do too, but not always, so Classify checks them one by one.
local LOCAL_KEYS = {
	achievementID = true, headerID = true, mapID = true, instanceID = true,
	difficultyID = true, encounterID = true, factionID = true, currencyID = true, titleID = true,
	spellID = true, recipeID = true, mountID = true, speciesID = true,
	flightpathID = true, flightPathID = true, explorationID = true, followerID = true, classID = true,
	raceID = true, professionID = true, illusionID = true, decorID = true, campsiteID = true,
	categoryID = true, expansionID = true, filterID = true, tierID = true, eventID = true,
	conduitID = true, runeforgePowerID = true, artifactID = true, ensembleID = true,
	garrisonbuildingID = true, garrisonmissionID = true, autoID = true, achievementCategoryID = true,
}

-- State (private; other files use the methods below)
local root               -- ATT root group being indexed
local state = "idle"     -- "idle" | "building" | "ready"
local names, groups = {}, {} -- names[i] (lowercase) belongs to groups[i]
local pending = {}       -- entries waiting for the client cache; checked without server queries
local remote, remoteHead = {}, 1 -- entries waiting for a throttled lookup (a queue)
local requested = {}     -- "kind:id" already asked for, so each id is requested once
local itemTries = {}     -- itemID -> requests sent (items get no reply when the server is busy)
local remoteTicker, retryTimer
local inFlight, inFlightCount = {}, 0 -- "kind:id" -> time the lookup stops counting
local remoteStartAt = 0  -- GetTime() before which queued lookups wait

-- Which quests the game has loaded this session (questID -> true), or has no data for (false).
-- No API answers this without loading the quest, so it's learned from QUEST_DATA_LOAD_RESULT,
-- whoever asked. It describes the game, not the index, so Reset keeps it.
local questLoaded = {}

-- Quests waiting for their data: questID -> groups to index once it arrives (from anyone).
local questWaiting, questWaitingCount = {}, 0
local questQueue, questHead = {}, 1 -- questIDs to ask for, when the "Load all quest names" option is on
-- The same for quests ATT marks unobtainable or removed, asked for last: the server has no data
-- for many of them, and refusals in a row look like throttling.
local questQueueLast = {}

-- A deferred name. kind is "item" | "quest" | "npc" | "other" | "local".
local function Entry(group, kind, id)
	return { group = group, kind = kind, id = id, attempts = 0 }
end

local NoDataQuests, NoDataItems, ItemRefused, GaveUp -- defined with the saved names

-- Names ----------------------------------------------------------------------

-- Reads a group's name, or uses `known` when Classify already found it. Only call this when
-- Classify said it's free, or from the queue.
-- Returns the lowercase name, or nil plus whether it's worth retrying later.
local function ResolveName(group, known)
	local text = known or ATT.GetText(group)
	if Util.IsSecret(text) then
		-- Read while the game restricted addons: ATT keeps it hidden on the group until a
		-- reload, but its NPC name table may have the readable one.
		local key, id = ATT.GetKey(group)
		text = (key == "npcID" or key == "creatureID") and type(id) == "number" and ATT.GetNPCName(id) or nil
	end
	if ATT.IsRetrieving(text) then return nil, true end
	local clean = Util.CleanText(text)
	if not clean then return nil, false end
	return strlower(clean), false
end

-- Decides whether reading this group's name is free, may cost a server query, or isn't worth
-- it at all. Never makes a query itself. Returns:
--   nil, nil, name   free to read now (name is set when it was found without asking ATT)
--   "skip"           don't index it
--   kind, id         read it later, through the throttled queue
local function Classify(group)
	local itemID = ATT.GetID(group, "itemID")
	if itemID and itemID > 0 then
		-- Without a free cache check, reading the name could query the server: throttle it.
		if not IsItemDataCachedByID then return "other", "item:" .. itemID end
		if IsItemDataCachedByID(itemID) then return nil end
		-- Not in the game's item data (ATT lists some removed items): asking for it gets no
		-- reply at all, which looks like a busy server and pauses every lookup. (The game's
		-- own item code makes the same check before it asks.)
		if DoesItemExistByID and not DoesItemExistByID(itemID) then return "skip" end
		-- The server has no data for it.
		if ItemRefused(itemID) or (NoDataItems()[itemID] or 0) >= NO_DATA_SESSIONS then return "skip" end
		return "item", itemID
	end
	local key, id = ATT.GetKey(group)
	if key == nil or LOCAL_KEYS[key] then return nil end
	if key == "questID" then
		if type(id) ~= "number" then return "skip" end
		if ATT.HasShippedQuestName(id) or questLoaded[id] then return nil end
		-- The server has no data for it, or it's a hidden trigger (never has any).
		if questLoaded[id] == false or ATT.IsHiddenQuest(group) then return "skip" end
		-- Refused in two earlier sessions of this game build: the server has no data for it.
		if (NoDataQuests()[id] or 0) >= NO_DATA_SESSIONS then return "skip" end
		return "quest", id
	elseif key == "npcID" or key == "creatureID" then
		if type(id) ~= "number" or id <= 0 then return nil end -- negative ids are ATT headers
		if ATT.IsNPCNameCached(id) then return nil end
		if GaveUp("npc", id) then return "skip" end
		return "npc", id
	elseif key == "criteriaID" then
		-- Without its own text, ATT names a criteria after a quest, NPC or item, and reading
		-- that may query the server (once per criteria). Those are found by that name anyway.
		local name = ATT.GetLocalCriteriaName(group)
		if name then return nil, nil, name end
		return "skip"
	elseif key == "objectID" then
		-- Without a name of its own, ATT names an object after an item or NPC.
		if type(id) == "number" and ATT.HasShippedObjectName(id) then return nil end
	end
	local otherID = key .. ":" .. tostring(id)
	if GaveUp("other", otherID) then return "skip" end
	return "other", otherID
end

-- Saved names ----------------------------------------------------------------
-- Names that cost something to look up are saved in ATTSearchDB, keyed by ATT's id
-- ("npcID:1234"), and reused after a reload with no lookup at all. Cheap names
-- (achievements, zones...) aren't saved, which keeps the file small. The cache resets when
-- the game language changes, and entries for things no longer in ATT are pruned after
-- each full build.
--
-- On disk the names are packed into a few long strings of "key<tab>name" lines. The game loads
-- a saved variables file as one Lua chunk, and a chunk holds at most 262,143 different
-- constants. As a plain table every key and every name was one, so a big cache went over that
-- limit: the file failed to load and the cache started over (1.2.0 and earlier).

local CACHE_VERSION = 2
local PACK_SIZE = 1000 -- names per saved string
local nameCache        -- key -> name, unpacked once per session

-- Keys whose names are free again next session, so they aren't saved (unless the group comes
-- with an item, see CacheKey).
local NOT_SAVED = setmetatable({ criteriaID = true, objectID = true }, { __index = LOCAL_KEYS })

-- ATTSearchDB, made current: a new language or an unknown version starts it over.
local function SavedDB()
	local db, locale = ATTSearchDB, GetLocale()
	if type(db) ~= "table" or db.locale ~= locale or (db.version ~= CACHE_VERSION and db.version ~= 1) then
		Options.Get("lookups") -- moves an old "lookups off" out of here before it's replaced
		db = { version = CACHE_VERSION, locale = locale }
		ATTSearchDB = db
	end
	return db
end

-- Reads the saved names. `pause`, when given, is called every so often (the build passes
-- Checkpoint, so a big cache doesn't freeze the game).
local function LoadNames(pause)
	if nameCache then return nameCache end
	local db, cache = SavedDB(), {}
	if db.version == 1 then
		-- 1.2.0 and earlier: a plain table, and items saved as whole links ("|hitem:...|h[name]|h").
		local old, count = type(db.names) == "table" and db.names or {}, 0
		for key, name in pairs(old) do
			if type(name) == "string" then
				cache[key] = gsub(name, "|h.-|h%[?(.-)%]?|h", "%1")
			end
			count = count + 1
			if pause and count % 100 == 0 then pause() end
		end
	elseif type(db.packed) == "table" then
		local packed = db.packed
		for i = 1, #packed do
			for key, name in gmatch(packed[i], "([^\t\n]+)\t([^\n]*)") do
				cache[key] = name
			end
			if pause then pause() end
		end
	end
	if nameCache then return nameCache end -- loaded meanwhile, while this one was paused
	-- Packed again at logout (see below); until then the table is the only copy.
	db.version, db.names, db.packed = CACHE_VERSION, nil, nil
	nameCache = cache
	return cache
end

local function NameCache()
	return nameCache or LoadNames()
end

local function PackNames(cache)
	local packed, lines, n = {}, {}, 0
	for key, name in pairs(cache) do
		n = n + 1
		lines[n] = key .. "\t" .. name
		if n == PACK_SIZE then
			packed[#packed + 1] = concat(lines, "\n", 1, n)
			n = 0
		end
	end
	if n > 0 then packed[#packed + 1] = concat(lines, "\n", 1, n) end
	return packed
end

local saver = CreateFrame("Frame")
saver:RegisterEvent("PLAYER_LOGOUT") -- also fires on /reload
saver:SetScript("OnEvent", function()
	if nameCache and type(ATTSearchDB) == "table" then
		ATTSearchDB.packed = PackNames(nameCache)
	end
end)

-- Quests and items the server had no data for, per game build: id -> sessions it was refused
-- in. A quest refusal can also mean the server is throttling us, so an id is only skipped after
-- NO_DATA_SESSIONS separate sessions refused it. A new game build starts the lists over, and an
-- id that loads after all is taken off.
-- Items the server never answered count as refused too, and so do NPC and other names that
-- never loaded (noDataNames, keyed "npc:id" / "other:key:id"). Without this they were asked
-- for again every session, ahead of the names still to load, and each unanswered item paused
-- all lookups for UNANSWERED_BACKOFF_SECONDS: a session could end before any new name loaded.
local noData, noDataItems, noDataNames
local refusedThisSession = {} -- "quest:id" / "item:id" / "npc:id"... -> true once counted in this session

local function GameBuild()
	local version, build = GetBuildInfo()
	return tostring(version) .. "." .. tostring(build)
end

local function NoDataLists()
	if noData then return noData, noDataItems, noDataNames end
	local db, build = SavedDB(), GameBuild()
	if type(db.noData) ~= "table" or db.noDataBuild ~= build then
		db.noData, db.noDataItems, db.noDataNames, db.noDataBuild = {}, {}, {}, build
	end
	if type(db.noDataItems) ~= "table" then db.noDataItems = {} end
	if type(db.noDataNames) ~= "table" then db.noDataNames = {} end
	noData, noDataItems, noDataNames = db.noData, db.noDataItems, db.noDataNames
	return noData, noDataItems, noDataNames
end

function NoDataQuests()
	return (NoDataLists())
end

function NoDataItems()
	local _, items = NoDataLists()
	return items
end

local function NoDataNames()
	local _, _, list = NoDataLists()
	return list
end

-- Counts a refusal (once per session). The list is keyed by id, or with `byKey` by "kind:id".
local function RecordNoData(list, kind, id, byKey)
	local key = kind .. ":" .. tostring(id)
	if refusedThisSession[key] then return end
	refusedThisSession[key] = true
	local slot = byKey and key or id
	list[slot] = (list[slot] or 0) + 1
end

-- An NPC or other name that never loaded (counted once per session).
local function RecordGaveUp(kind, id)
	RecordNoData(NoDataNames(), kind, id, true)
end

-- Whether an item was refused, or never answered, this session (its data never loads).
function ItemRefused(itemID)
	return refusedThisSession["item:" .. tostring(itemID)] or false
end

-- Whether an NPC or other name never loaded in NO_DATA_SESSIONS sessions of this game build.
function GaveUp(kind, id)
	return (NoDataNames()[kind .. ":" .. tostring(id)] or 0) >= NO_DATA_SESSIONS
end

-- How many ids are skipped for having no server data. With `prefix` (what turns a list key
-- into a session key: "item:" for items, "" for noDataNames), ids refused this session count too.
local function NoDataCount(list, prefix)
	local count = 0
	for id, sessions in pairs(list) do
		if sessions >= NO_DATA_SESSIONS or (prefix and refusedThisSession[prefix .. id]) then
			count = count + 1
		end
	end
	return count
end

local function CacheKey(group)
	local key, id = ATT.GetKey(group)
	if key == nil or type(id) ~= "number" or id <= 0 then return nil end
	-- A free kind that comes with an item (recipes, mounts, pets, decor...) goes through the
	-- item checks in Classify, so its name costs a lookup like an item's: save it too.
	-- (Without this, those names loaded again every session.)
	if NOT_SAVED[key] and not (LOCAL_KEYS[key] and (ATT.GetID(group, "itemID") or 0) > 0) then
		return nil
	end
	return key .. ":" .. id
end

-- Removes saved names whose key wasn't seen in a complete walk of the tree.
local function PruneCache(seen)
	local cache, stale = NameCache(), {}
	for key in pairs(cache) do
		if not seen[key] then stale[#stale + 1] = key end
	end
	for i = 1, #stale do cache[stale[i]] = nil end
end

-- Coroutine runner -----------------------------------------------------------

local deadline = 0
local function Checkpoint()
	if debugprofilestop() > deadline then coroutine.yield() end
end

local jobs = {} -- name -> coroutine
local JOB_ORDER = { "search", "build", "pending" } -- search first so typing stays responsive
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self)
	deadline = debugprofilestop() + FRAME_BUDGET_MS
	-- Jobs may start or cancel other jobs while running, so look each one up fresh.
	for i = 1, #JOB_ORDER do
		local name = JOB_ORDER[i]
		local co = jobs[name]
		if co and debugprofilestop() < deadline then
			local ok, err = coroutine.resume(co)
			if jobs[name] == co and (not ok or coroutine.status(co) == "dead") then
				jobs[name] = nil
			end
			if not ok then geterrorhandler()(err) end
		end
	end
	if not next(jobs) then self:Hide() end
end)

local function StartJob(name, fn)
	jobs[name] = coroutine.create(fn)
	driver:Show()
end

local function CancelJob(name)
	jobs[name] = nil
end

-- Change notifications -------------------------------------------------------

local listeners = {}

-- Registers fn to be called when the index grows or changes state.
function Index:OnChanged(fn)
	listeners[#listeners + 1] = fn
end

local function Notify()
	for i = 1, #listeners do Util.SafeCall(listeners[i]) end
end

local notifyTimer
local function NotifySoon()
	if notifyTimer then return end
	notifyTimer = C_Timer.NewTimer(NOTIFY_THROTTLE, function()
		notifyTimer = nil
		Notify()
	end)
end

-- Building -------------------------------------------------------------------

local function AddEntry(group, name)
	local n = #names + 1
	names[n] = name
	groups[n] = group
end

-- Adds a freshly looked-up name and saves it for the next session.
local function Add(group, name, cacheKey)
	AddEntry(group, name)
	cacheKey = cacheKey or CacheKey(group)
	if cacheKey then NameCache()[cacheKey] = name end
end

local function Defer(group, kind, id)
	if kind == "quest" then
		local waiting = questWaiting[id]
		if not waiting then
			waiting = {}
			questWaiting[id] = waiting
			questWaitingCount = questWaitingCount + 1
			local queue = ATT.IsUnobtainable(group) and questQueueLast or questQueue
			queue[#queue + 1] = id
		end
		waiting[#waiting + 1] = group
	elseif kind == "item" and not Options.Get("loadItems") then
		pending[#pending + 1] = Entry(group, kind, id)
	else
		remote[#remote + 1] = Entry(group, kind, id)
	end
end

local function RemoteCount()
	return #remote - remoteHead + 1
end

-- Throttled lookups ----------------------------------------------------------
-- Token bucket: each lookup needs a token, but one that turns out to be in the client cache
-- (the name comes back right away) gets its token back. So only lookups that really go to
-- the server count against the rate; cached ones run as fast as the per-tick time budget
-- allows. Each id is requested once; other groups sharing it wait in pending.
--
-- Every reply fires events that ATT, the quest log and other addons react to, and the server
-- answers at its own pace. So the rate ramps up slowly, drops back when the frame rate does,
-- and at most MAX_IN_FLIGHT lookups wait for a reply at once (quests and items free their slot
-- when the reply arrives, other kinds after IN_FLIGHT_TIMEOUT).

local function RequestKey(kind, id)
	return kind .. ":" .. tostring(id)
end

local function RequestOnce(kind, id)
	local key = RequestKey(kind, id)
	if requested[key] then return false end
	requested[key] = true
	return true
end

local stats = { sent = 0, questsSent = 0, refused = 0, refusedOurs = 0 } -- this session, for /atts status

-- Called for every lookup that goes to the server.
local function MarkInFlight(kind, id)
	stats.sent = stats.sent + 1
	local key = RequestKey(kind, id)
	if not inFlight[key] then inFlightCount = inFlightCount + 1 end
	inFlight[key] = GetTime() + IN_FLIGHT_TIMEOUT
end

local function ClearInFlight(key)
	if inFlight[key] then
		inFlight[key] = nil
		inFlightCount = inFlightCount - 1
	end
end

-- Frees the slots of lookups that got no reply in time. Returns true when an item lookup went
-- unanswered: those always get a reply event, so silence means the server is throttling us.
-- (NPC and other lookups have no reply event and always time out.)
local function ExpireInFlight()
	if inFlightCount == 0 then return false end
	local now, expired, unanswered = GetTime(), nil, false
	for key, expires in pairs(inFlight) do
		if expires <= now then
			expired = expired or {}
			expired[#expired + 1] = key
			if strfind(key, "^item:") then unanswered = true end
		end
	end
	if expired then
		for i = 1, #expired do ClearInFlight(expired[i]) end
	end
	return unanswered
end

-- Pausing --------------------------------------------------------------------
-- All lookups pause when turned off, in combat, while the game restricts addons, during party
-- sync and for a while after it (the game reloads the whole quest log then), and when an item
-- lookup gets no reply.

local rate = REMOTE_MIN_PER_SECOND -- current lookups per second (see StartRemote)
local resumeAt = 0                 -- GetTime() before which lookups wait

local function InPartySync()
	return C_QuestSession and C_QuestSession.Exists and C_QuestSession.Exists() or false
end

local function LookupsOff()
	return not Options.Get("lookups")
end

-- Whether the game restricts addons right now (Midnight: boss fights, Mythic+, PvP matches,
-- some maps). NPC names then come back hidden, and ATT keeps a hidden name until a reload.
local IsAddOnRestrictionActive = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
local function Restricted()
	local types = IsAddOnRestrictionActive and Enum and Enum.AddOnRestrictionType
	if not types then return false end
	for _, restriction in pairs(types) do
		local ok, active = pcall(IsAddOnRestrictionActive, restriction)
		if ok and active then return true end
	end
	return false
end

local function IsPaused()
	if InPartySync() then
		-- keeps the pause going for AFTER_SYNC_SECONDS after sync ends, even if the
		-- session events don't fire
		resumeAt = math.max(resumeAt, GetTime() + AFTER_SYNC_SECONDS)
		return true
	end
	return LookupsOff() or InCombatLockdown() or Restricted() or GetTime() < resumeAt
end

-- Waits at least `seconds` before the next lookup, and starts again from the lowest rate.
local function BackOff(seconds)
	resumeAt = math.max(resumeAt, GetTime() + seconds)
	rate = REMOTE_MIN_PER_SECOND
end

-- Counters for /atts status (stats is declared with the in-flight helpers).
local replyTimes = {} -- GetTime() of each quest reply (from anyone) in the last STATS_WINDOW
local STATS_WINDOW = 10

local function RecordReply(now)
	replyTimes[#replyTimes + 1] = now
	if #replyTimes > 500 and replyTimes[1] < now - STATS_WINDOW then
		local kept = {}
		for i = 1, #replyTimes do
			if replyTimes[i] >= now - STATS_WINDOW then kept[#kept + 1] = replyTimes[i] end
		end
		replyTimes = kept
	end
end

local function RecentReplies()
	local since, count = GetTime() - STATS_WINDOW, 0
	for i = #replyTimes, 1, -1 do
		if replyTimes[i] < since then break end
		count = count + 1
	end
	return count
end

-- Quest arrivals -------------------------------------------------------------
-- Whenever quest data arrives, whoever asked for it, the quests waiting for it are indexed.
-- That happens one frame later, after ATT has handled the same event (it may still hold an
-- old "no name" for the quest until then).

local arrived, arrivalTimer = {}, nil
local SchedulePendingRetry -- defined below

local function DropWaiting(questID)
	if questWaiting[questID] then
		questWaiting[questID] = nil
		questWaitingCount = questWaitingCount - 1
	end
end

local function IndexArrived()
	arrivalTimer = nil
	local ids = arrived
	arrived = {}
	local anyAdded = false
	for i = 1, #ids do
		local waiting = questWaiting[ids[i]]
		DropWaiting(ids[i])
		if waiting then
			for j = 1, #waiting do
				local name, retry = ResolveName(waiting[j])
				if name then
					Add(waiting[j], name)
					anyAdded = true
				elseif retry then
					-- ATT hasn't picked up the name yet: read it again later instead of asking
					-- the server for it again next session.
					pending[#pending + 1] = Entry(waiting[j], "local")
				end
			end
		end
	end
	if anyAdded then NotifySoon() end
	SchedulePendingRetry()
end

local function OnQuestLoaded(questID)
	if not questWaiting[questID] then return end
	arrived[#arrived + 1] = questID
	if not arrivalTimer then arrivalTimer = C_Timer.NewTimer(0, IndexArrived) end
end

-- Quest lane -----------------------------------------------------------------
-- Only runs with the "Load all quest names" option on. The game gives each account a small allowance
-- of quest data requests, and the quest log, quest objectives, chat messages and ATT's own
-- names all draw on it. So this lane asks for one quest at a time, at most one per
-- QUEST_INTERVAL, and steps aside: it waits QUEST_YIELD_SECONDS after the game or ATT loads a
-- quest, and backs off when replies get slow, don't come, or keep being refused.

local questTicker
local questInFlight, questSentAt -- the quest we're waiting on, and since when
local questResumeAt = 0
local questRefusedStreak = 0
local questThrottleSteps = 0     -- throttle pauses in a row (see QUEST_THROTTLE_PAUSES)
local lastForeignQuest = 0       -- GetTime() of the last quest reply we didn't ask for

local function QuestBackOff(seconds)
	questResumeAt = math.max(questResumeAt, GetTime() + seconds)
end

-- Pauses for the server throttling us: longer each time in a row, up to the last step.
local function QuestThrottled()
	questThrottleSteps = math.min(questThrottleSteps + 1, #QUEST_THROTTLE_PAUSES)
	QuestBackOff(QUEST_THROTTLE_PAUSES[questThrottleSteps])
end

-- Why the quest lane is waiting, or nil when it may ask: "off" (the option), and otherwise
-- the same as /atts status shows.
local function QuestLaneWait()
	if not Options.Get("searchQuests") then return "off" end
	if IsPaused() then return "paused" end
	local now = GetTime()
	if now < questResumeAt then return "backoff" end
	if now - lastForeignQuest < QUEST_YIELD_SECONDS then return "yield" end
end

local function StopQuestLane()
	if questTicker then questTicker:Cancel() questTicker = nil end
end

-- Asks for one quest. Returns true when the reply came back during the call (the game had it,
-- so nothing went to the server).
local function SendQuestRequest(questID)
	local waiting = questWaiting[questID]
	if not RequestLoadQuestByID then
		-- No request API on this client: reading the name is the request.
		DropWaiting(questID)
		local anyAdded = false
		for i = 1, #waiting do
			local name = ResolveName(waiting[i])
			if name then
				Add(waiting[i], name)
				anyAdded = true
			end
		end
		if anyAdded then NotifySoon() end
		stats.questsSent = stats.questsSent + 1
		return false
	end
	questInFlight, questSentAt = questID, GetTime()
	RequestLoadQuestByID(questID)
	if questInFlight == questID then
		stats.questsSent = stats.questsSent + 1
		return false
	end
	return true
end

local function StartQuestLane()
	if questTicker or (questHead > #questQueue and #questQueueLast == 0) or not Options.Get("searchQuests") then
		return
	end
	questTicker = C_Timer.NewTicker(QUEST_INTERVAL, function()
		if questInFlight and GetTime() - questSentAt > IN_FLIGHT_TIMEOUT then
			questInFlight = nil
			QuestThrottled()
		end
		if questInFlight or state ~= "ready" or GetTime() < remoteStartAt or QuestLaneWait() then
			return
		end
		local answered = 0
		while true do
			if questHead > #questQueue then
				if #questQueueLast == 0 then break end
				questQueue, questQueueLast, questHead = questQueueLast, {}, 1
			end
			local questID = questQueue[questHead]
			questQueue[questHead] = nil
			questHead = questHead + 1
			if questWaiting[questID] then -- otherwise it loaded meanwhile, or has no data
				if not SendQuestRequest(questID) then return end
				answered = answered + 1
				if answered >= QUEST_SYNC_BATCH then return end
			end
		end
		questQueue, questHead = {}, 1
		StopQuestLane()
	end)
end

local replies = CreateFrame("Frame")
replies:SetScript("OnEvent", function(_, event, id, success)
	if event == "QUEST_SESSION_LEFT" or event == "QUEST_SESSION_DESTROYED" then
		BackOff(AFTER_SYNC_SECONDS) -- the game reloads the whole quest log when sync ends
		return
	end
	if event == "ITEM_DATA_LOAD_RESULT" then
		ClearInFlight(RequestKey("item", id)) -- replies free their slot right away
		-- A refusal means the item has no data (removed from the game): the groups waiting for
		-- it are dropped at the next pending pass. (Only once the index has loaded the list.)
		if noDataItems then
			if success then
				noDataItems[id] = nil
				refusedThisSession["item:" .. tostring(id)] = nil -- a late reply after giving up
			else
				RecordNoData(noDataItems, "item", id)
			end
		end
		return
	end
	local now = GetTime()
	RecordReply(now)
	local ours = id == questInFlight
	if ours then
		questInFlight = nil
		if now - questSentAt > QUEST_SLOW_REPLY_SECONDS then QuestBackOff(QUEST_SLOW_BACKOFF_SECONDS) end
	else
		lastForeignQuest = now
	end
	if success then
		questLoaded[id] = true
		-- It has data after all. (Only once the index has loaded the list: this can run while
		-- the game is still loading, before ATTSearchDB is read.)
		if noData and noData[id] then noData[id] = nil end
		if ours then
			questRefusedStreak = 0
			-- answered by the server, not on the spot from the game's own data
			if now > questSentAt then questThrottleSteps = 0 end
		end
		OnQuestLoaded(id)
		return
	end
	-- A single refusal is normal: the server has no data for some quests (removed ones, for
	-- example). Several of ours in a row mean it's throttling us.
	stats.refused = stats.refused + 1
	if questLoaded[id] == nil then questLoaded[id] = false end
	DropWaiting(id)
	if ours then
		stats.refusedOurs = stats.refusedOurs + 1
		RecordNoData(NoDataQuests(), "quest", id)
		questRefusedStreak = questRefusedStreak + 1
		if questRefusedStreak >= QUEST_REFUSED_STREAK then
			questRefusedStreak = 0
			QuestThrottled()
		end
	end
end)
for _, event in ipairs({ "QUEST_DATA_LOAD_RESULT", "ITEM_DATA_LOAD_RESULT",
		"QUEST_SESSION_LEFT", "QUEST_SESSION_DESTROYED" }) do
	pcall(replies.RegisterEvent, replies, event)
end

-- Handles one queued entry. Returns tokens used (0 or 1) and whether a name was added.
local function ProcessRemote(entry)
	local group, kind, id = entry.group, entry.kind, entry.id
	-- It may have loaded meanwhile (another addon, or a shared id).
	local later, _, known = Classify(group)
	if later == "skip" then return 0, false end
	if not later then
		local name, retry = ResolveName(group, known)
		if name then Add(group, name) return 0, true end
		if retry then pending[#pending + 1] = entry end
		if kind == "local" then
			-- Its name is still loading, so reading it may have made ATT ask the server:
			-- count it as a lookup.
			entry.attempts = entry.attempts + 1
			return 1, false
		end
		return 0, false
	end
	if kind == "item" and not Options.Get("loadItems") then
		pending[#pending + 1] = entry -- the option was turned off: wait for the game instead
		return 0, false
	end
	if kind == "item" and RequestLoadItemDataByID then
		-- Tries count per item, so groups sharing an id share them.
		if inFlight[RequestKey(kind, id)] then
			pending[#pending + 1] = entry -- already asked: wait for the reply
			return 0, false
		end
		local tries = itemTries[id] or 0
		if tries >= MAX_REMOTE_ATTEMPTS then
			-- Never answered: give up, and count it like a refusal so later sessions stop asking.
			RecordNoData(NoDataItems(), "item", id)
			return 0, false
		end
		itemTries[id] = tries + 1
		MarkInFlight(kind, id)
		RequestLoadItemDataByID(id)
		pending[#pending + 1] = entry
		return 1, false
	end
	if entry.attempts == 0 and not RequestOnce(kind, id) then
		pending[#pending + 1] = entry -- another group with the same id already asked
		return 0, false
	end
	-- Otherwise reading the name is the lookup. If it comes back right away it was in the
	-- client cache and cost nothing; otherwise a server query went out.
	-- (NPCs are looked up in ATT's name table, not on the group, which may hold a hidden name.)
	if kind == "npc" then ATT.GetNPCName(id, true) end
	local name, retry = ResolveName(group)
	if name then Add(group, name) return 0, true end
	entry.attempts = entry.attempts + 1
	MarkInFlight(kind, id)
	if retry then
		pending[#pending + 1] = entry
	else
		RecordGaveUp(kind, id) -- it has no usable name
	end
	return 1, false
end

local function StartRemote()
	if remoteTicker or RemoteCount() <= 0 then return end
	local tokens = 0
	rate = REMOTE_MIN_PER_SECOND
	remoteTicker = C_Timer.NewTicker(REMOTE_TICK, function()
		if ExpireInFlight() then BackOff(UNANSWERED_BACKOFF_SECONDS) end
		if IsPaused() then
			rate = REMOTE_MIN_PER_SECOND
			return
		end
		if GetFramerate() < REMOTE_LOW_FPS then
			rate = REMOTE_MIN_PER_SECOND
		else
			rate = math.min(rate + REMOTE_RAMP_PER_SECOND * REMOTE_TICK, REMOTE_MAX_PER_SECOND)
		end
		tokens = math.min(tokens + rate * REMOTE_TICK, rate)
		local tickDeadline = debugprofilestop() + REMOTE_TICK_BUDGET_MS
		local anyAdded = false
		while tokens >= 1 and inFlightCount < MAX_IN_FLIGHT and remoteHead <= #remote
			and state == "ready" and GetTime() >= remoteStartAt
			and debugprofilestop() < tickDeadline do
			local entry = remote[remoteHead]
			remote[remoteHead] = nil
			remoteHead = remoteHead + 1
			local used, added = ProcessRemote(entry)
			tokens = tokens - used
			anyAdded = anyAdded or added
		end
		if anyAdded then NotifySoon() end
		if remoteHead > #remote then
			remote, remoteHead = {}, 1
			remoteTicker:Cancel()
			remoteTicker = nil
			NotifySoon()
			SchedulePendingRetry()
		end
	end)
end

-- Re-checks pending names using only what the client already has (never queries the server).
-- NPCs, unknown kinds and still-loading "local" names can't be checked for free, so they get
-- throttled lookups instead. Waits out combat, addon restrictions and party sync.
function SchedulePendingRetry()
	if #pending == 0 or retryTimer then return end
	retryTimer = C_Timer.NewTimer(PENDING_RETRY_SECONDS, function()
		retryTimer = nil
		if jobs.pending or #pending == 0 then return end
		if InCombatLockdown() or Restricted() or InPartySync() then SchedulePendingRetry() return end
		local forRoot = root
		StartJob("pending", function()
			local current = pending
			pending = {} -- new deferrals during this pass land here
			local anyAdded, requeued = false, false
			for i = 1, #current do
				if root ~= forRoot then return end
				local entry = current[i]
				local later, _, known = Classify(entry.group)
				if entry.kind == "local" then
					if entry.attempts < MAX_REMOTE_ATTEMPTS then
						remote[#remote + 1] = entry
						requeued = true
					end -- else give up: the name never loaded
				elseif later == nil then
					local name, retry = ResolveName(entry.group, known)
					if name then
						Add(entry.group, name)
						anyAdded = true
					elseif retry then
						pending[#pending + 1] = entry
					end
				elseif later ~= "skip" then -- "skip": the server has no data for it, drop it
					if (entry.kind == "npc" or entry.kind == "other") and entry.attempts > 0 then
						if entry.attempts < MAX_REMOTE_ATTEMPTS then
							remote[#remote + 1] = entry
							requeued = true
						else -- give up: the name never loaded
							RecordGaveUp(entry.kind, entry.id)
						end
					elseif entry.kind == "item" and Options.Get("loadItems") then
						-- Still not loaded: asks again, unless it's waiting for a reply or
						-- was asked for too often already (see ProcessRemote).
						remote[#remote + 1] = entry
						requeued = true
					else
						pending[#pending + 1] = entry
					end
				end
				if i % 10 == 0 then Checkpoint() end
			end
			if anyAdded then Notify() end
			if requeued then StartRemote() end
			SchedulePendingRetry()
		end)
	end)
end

-- Public API -----------------------------------------------------------------

function Index:Reset()
	CancelJob("build")
	CancelJob("pending")
	if remoteTicker then remoteTicker:Cancel() remoteTicker = nil end
	if retryTimer then retryTimer:Cancel() retryTimer = nil end
	StopQuestLane()
	root, state = nil, "idle"
	names, groups, pending, remote, remoteHead, requested, itemTries = {}, {}, {}, {}, 1, {}, {}
	inFlight, inFlightCount = {}, 0
	questWaiting, questWaitingCount, questQueue, questHead, questQueueLast = {}, 0, {}, 1, {}
	arrived = {}
end

-- Builds the index for this ATT root, unless it's already built or building.
function Index:Ensure(newRoot)
	if not newRoot then return end
	if newRoot ~= root then
		self:Reset()
		root = newRoot
	end
	if state ~= "idle" then return end
	state = "building"
	Notify()
	StartJob("build", function()
		local cache, seen = LoadNames(Checkpoint), {}
		local stack, top, visited = { root }, 1, 0
		while top > 0 do
			local group = stack[top]
			stack[top] = nil
			top = top - 1
			if group ~= root then
				local cacheKey = CacheKey(group)
				if cacheKey then seen[cacheKey] = true end
				local cached = cacheKey and cache[cacheKey]
				if cached then
					AddEntry(group, cached)
				else
					local kind, id, known = Classify(group)
					if kind == nil then
						local name, retry = ResolveName(group, known)
						if name then
							Add(group, name, cacheKey)
						elseif retry then
							pending[#pending + 1] = Entry(group, "local")
						end
					elseif kind ~= "skip" then
						Defer(group, kind, id)
					end
				end
			end
			local children = ATT.GetChildren(group)
			if type(children) == "table" then
				-- push in reverse so children are visited in list order
				for i = #children, 1, -1 do
					top = top + 1
					stack[top] = children[i]
				end
			end
			visited = visited + 1
			if visited % 10 == 0 then
				Checkpoint()
				if visited % 5000 == 0 then NotifySoon() end
			end
		end
		PruneCache(seen)
		state = "ready"
		Notify()
		remoteStartAt = GetTime() + REMOTE_START_DELAY
		local forRoot = root
		C_Timer.After(REMOTE_START_DELAY, function()
			if root == forRoot then
				StartRemote()
				StartQuestLane()
			end
		end)
		SchedulePendingRetry()
	end)
end

-- Starts or stops lookups when the options change.
-- Moves the items waiting for the game into the lookup queue ("Load all item names" turned on).
local function QueueItems()
	local still = {}
	for i = 1, #pending do
		local entry = pending[i]
		if entry.kind == "item" then
			remote[#remote + 1] = entry
		else
			still[#still + 1] = entry
		end
	end
	pending = still
end

Options.OnChanged(function(key, value)
	if key == "loadItems" and value then QueueItems() end
	if not value then
		if key == "searchQuests" then StopQuestLane() end
		return -- the lanes see "off" themselves and wait
	end
	StartRemote()
	StartQuestLane()
end)

local function QuestLookupsOn()
	return Options.Get("searchQuests") and not LookupsOff()
end

function Index:GetRoot() return root end
function Index:IsBuilding() return state == "building" end
function Index:IsReady() return state == "ready" end
function Index:GetCount() return #names end           -- names indexed so far
-- names waiting for a lookup (quests only count when ATT-Search will ask for them)
function Index:GetLoadingCount()
	return RemoteCount() + (QuestLookupsOn() and questWaitingCount or 0)
end
function Index:GetPendingCount() return #pending end  -- names waiting for the client cache

-- Forgets all saved names (the next build looks everything up again).
function Index:ClearCache()
	Options.Get("lookups") -- moves an old "lookups off" out of ATTSearchDB first
	ATTSearchDB = nil
	nameCache = nil
	noData, noDataItems, noDataNames = nil, nil, nil
end

-- A snapshot of the background lookups, for /atts status.
function Index:GetStatus()
	local pausedBy
	if LookupsOff() then pausedBy = "off"
	elseif InCombatLockdown() then pausedBy = "combat"
	elseif Restricted() then pausedBy = "restricted"
	elseif InPartySync() then pausedBy = "partysync"
	elseif GetTime() < resumeAt then pausedBy = "backoff"
	end
	local now = GetTime()
	local questWait = QuestLaneWait()
	local questBackoff = questWait == "yield" and (lastForeignQuest + QUEST_YIELD_SECONDS - now)
		or (questResumeAt - now)
	return {
		lookupsOn = not LookupsOff(),
		pausedBy = pausedBy,
		backoffSeconds = math.max(0, math.ceil(resumeAt - now)),
		partySyncAPI = Util.HasPartySync(),
		partySync = InPartySync(),
		state = state,
		count = #names,
		rate = rate,
		queued = RemoteCount(),
		waiting = inFlightCount,
		pending = #pending,
		sent = stats.sent,
		questsOn = Options.Get("searchQuests"),
		questWait = questWait, -- nil (running), "off" (the option), "paused" (like all lookups), "yield", "backoff"
		questBackoffSeconds = math.max(0, math.ceil(questBackoff)),
		questsWaiting = questWaitingCount,
		questsNoData = NoDataCount(NoDataQuests()),
		otherNoData = NoDataCount(NoDataItems(), "item:") + NoDataCount(NoDataNames(), ""),
		questsSent = stats.questsSent,
		refused = stats.refused,
		refusedOurs = stats.refusedOurs,
		recentReplies = RecentReplies(),
		statsWindow = STATS_WINDOW,
	}
end

-- Searching ------------------------------------------------------------------

local function CompareResults(a, b)
	if a.hidden ~= b.hidden then return not a.hidden end -- shown in the main list first
	if a.score ~= b.score then return a.score < b.score end
	if a.len ~= b.len then return a.len < b.len end
	return a.order < b.order
end

-- How well a match at position `at` fits: exact, then prefix, then word start, then anywhere.
local function Score(name, query, at)
	if at == 1 then return (#name == #query) and 0 or 1 end
	if strfind(strsub(name, at - 1, at - 1), "[%s%-%(%[':,]") then return 2 end
	return 3
end

-- Searches the current index. Calls onDone(results, totalMatches) when finished, where each
-- result is { group, name (lowercase), score, hidden, ... }. Starting a new search cancels
-- the previous one.
function Index:Search(query, onDone)
	CancelJob("search")
	query = strlower(Util.Trim(query or ""))
	if query == "" then onDone({}, 0) return end
	StartJob("search", function()
		local results, total = {}, 0
		for i = 1, #names do
			local name = names[i]
			local at = strfind(name, query, 1, true)
			if at then
				total = total + 1
				if #results < MAX_COLLECT then
					results[#results + 1] = { group = groups[i], name = name, score = Score(name, query, at), len = #name, order = i }
				end
			end
			if i % 1000 == 0 then Checkpoint() end
		end
		-- Mark results the main list hides, so they sort after the shown ones.
		for i = 1, #results do
			results[i].hidden = not ns.Filters.IsShownInList(results[i].group, root)
			if i % 50 == 0 then Checkpoint() end
		end
		sort(results, CompareResults)
		for i = #results, MAX_RESULTS + 1, -1 do tremove(results, i) end
		onDone(results, total)
	end)
end

function Index:CancelSearch()
	CancelJob("search")
end
