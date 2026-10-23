-- ATT-Search: Locales
-- All player-facing text. English is the default; a missing key shows the key itself, so a
-- forgotten string is visible instead of breaking anything.
--
-- To translate, add a block at the bottom:
--   if GetLocale() == "deDE" then
--       L.SEARCH_PLACEHOLDER = "..."
--   end
local _, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

-- Search bar and key binding
L.SEARCH_PLACEHOLDER = "Search All The Things by name or ID..."
L.OPTIONS_BUTTON = "ATT-Search options"
L.BINDING_HEADER = "ATT-Search"
L.BINDING_FOCUS = "Focus the search bar"

-- Results footer
L.INDEXING_PROGRESS = "Indexing... %d names so far"
L.NO_MATCHES = "No matches"
L.TOP_MATCHES = "Top %d of %d matches"
L.MATCH_ONE = "%d match"
L.MATCH_MANY = "%d matches"
L.LOADING_NAMES = "Loading %d more names in the background"
L.NOT_LOADED = "%d not loaded yet"
L.ATT_LOADING_FOOTER = "All The Things is still loading..."

-- Collected / completed status
L.COLLECTED = "Collected"
L.NOT_COLLECTED = "Not collected"
L.ALL_COLLECTED = "Everything collected"
L.PROGRESS = "%d of %d collected"
L.COMPLETED = "Completed"
L.NOT_COMPLETED = "Not completed"

-- Result rows and tooltips
L.HIDDEN_ROW = "Hidden: %s"
L.HIDDEN_TOOLTIP = "Hidden in the main list: %s"
L.CLICK_HINT = "Click to show it in the main list"
L.SHIFT_CLICK_HINT = "Shift+click to set a waypoint"
L.SHIFT_CLICK_ACHIEVEMENT_HINT = "Shift+click to open it in the Achievements window"

-- Id labels in tooltips, by ATT field name (fields without a label show the field name)
L.ID_LABELS = {
	itemID = "Item ID", spellID = "Spell ID", npcID = "NPC ID", creatureID = "NPC ID",
	questID = "Quest ID", achievementID = "Achievement ID", criteriaID = "Criteria ID",
	mapID = "Map ID", instanceID = "Instance ID", encounterID = "Encounter ID",
	objectID = "Object ID", sourceID = "Appearance Source ID", speciesID = "Pet Species ID",
	mountID = "Mount ID", toyID = "Toy ID", currencyID = "Currency ID", factionID = "Faction ID",
	titleID = "Title ID", recipeID = "Recipe ID", illusionID = "Illusion ID", decorID = "Decor ID",
	flightpathID = "Flight Path ID", explorationID = "Exploration ID", followerID = "Follower ID",
	classID = "Class ID", raceID = "Race ID", professionID = "Profession ID", eventID = "Event ID",
}

-- Words that narrow an ID search to one kind ("item 19019", "quest:1234"), by ATT field name.
-- Lowercase. "itemid", "item id" and the like work too.
L.ID_KINDS = {
	item = "itemID", quest = "questID", npc = "npcID", creature = "npcID",
	achievement = "achievementID", ach = "achievementID", criteria = "criteriaID",
	spell = "spellID", map = "mapID", zone = "mapID", instance = "instanceID",
	encounter = "encounterID", object = "objectID", source = "sourceID", appearance = "sourceID",
	pet = "speciesID", species = "speciesID", mount = "mountID", toy = "toyID",
	currency = "currencyID", faction = "factionID", title = "titleID", recipe = "recipeID",
	illusion = "illusionID", decor = "decorID", flightpath = "flightpathID",
	exploration = "explorationID", follower = "followerID",
}

-- Why a result is hidden in the main list
L.REASON_UNOBTAINABLE = "Unobtainable filter"
L.REASON_EVENT = "Event not active"
L.REASON_EXPANSION = "Expansion filter"
L.REASON_PVP = "PvP filter"
L.REASON_CHALLENGE_MODE = "Challenge Mode filter"
L.REASON_PET_BATTLES = "Pet Battles filter"
L.REASON_SKYRIDING = "Skyriding filter"
L.REASON_PERSONAL_LOOT = "Unavailable Personal Loot filter"
L.REASON_CLASS = "Other class (Class filter)"
L.REASON_LEVEL = "Level requirement (Level filter)"
L.REASON_PROFESSION = "Profession required (Profession filter)"
L.REASON_REPUTATION = "Reputation required (Reputation filter)"
L.REASON_ITEM_TYPE = "Item type you don't use (Item filters)"
L.REASON_BOUND = "Bound items filter"
L.REASON_CUSTOM_COLLECT = "Special requirement (Custom Collect filter)"
L.REASON_FACTION_ONLY = "%s only (Race filter)" -- %s = Blizzard's localized faction name
L.REASON_RACE = "Other race (Race filter)"
L.REASON_SHOW_COLLECTED_OFF = "Already collected (Show Collected Things is off)"
L.REASON_SHOW_COMPLETED_OFF = "Already completed (Show Completed Groups is off)"
L.REASON_COMPLETED = "Already completed"
L.REASON_NOTHING_TO_COLLECT = "Nothing to collect with your ATT settings"
L.REASON_FILTERS = "Hidden by your ATT filters"
L.REASON_ON_PARENT = "%s, on %s" -- reason, parent name

-- Chat messages
L.HIDDEN_CHAT = "%s is hidden in the main list (%s). Its parents were expanded."
L.LIST_REBUILT = "ATT rebuilt its list, searching again..."
L.ATT_STILL_LOADING = "All The Things is still loading."
L.MAIN_LIST_NOT_READY = "The All The Things main list isn't ready yet."
L.NO_WAYPOINTS = "This version of All The Things can't set waypoints."
L.CACHE_CLEARED = "Saved names cleared. Rebuilding the index in the background."

-- /atts help
L.HELP_OPEN = "/atts - open the main list and focus the search bar"
L.HELP_SEARCH = "/atts <text> - search right away (a name, an ID, or a kind and an ID like \"item 19019\")"
L.HELP_ITEMS = "/atts items on|off - load the names of items the game hasn't cached yet (on by default)"
L.HELP_CLEARCACHE = "/atts clearcache - forget the saved names and rebuild the index"
L.HELP_QUESTS = "/atts quests on|off - also load quest names from the server, so every quest is searchable (off by default)"
L.HELP_LOOKUPS = "/atts lookups on|off - allow or stop asking the server for names in the background"
L.HELP_STATUS = "/atts status - show what the background name loading is doing"
L.HELP_OPTIONS = "/atts options - open the ATT-Search options"

-- Options page (Options > AddOns > ATT-Search)
L.OPT_LOOKUPS = "Load names in the background"
L.OPT_LOOKUPS_DESC = "Names the game hasn't loaded yet, like NPCs and objects, are asked from the server a few at a time, never in combat, boss fights, Mythic+, PvP matches or party sync. Turn this off and ATT-Search never asks the server for anything: search then finds only names the game has already loaded. (/atts lookups on|off)"
-- Party sync is Retail-only; other game versions use the _NO_SYNC texts.
L.OPT_LOOKUPS_DESC_NO_SYNC = "Names the game hasn't loaded yet, like NPCs and objects, are asked from the server a few at a time, never in combat. Turn this off and ATT-Search never asks the server for anything: search then finds only names the game has already loaded. (/atts lookups on|off)"
L.OPT_ITEMS = "Load all item names"
L.OPT_ITEMS_DESC = "Loads the names of items the game hasn't cached yet, a few at a time, so every item is searchable. The game keeps item data, so this mostly happens once. (/atts items on|off)"
L.OPT_QUESTS = "Load all quest names"
L.OPT_QUESTS_DESC = "Load the names of all quests in All The Things from the server, so every quest is searchable. Off by default: quests the game has already loaded (your quest log, quests shown in All The Things) are searchable either way. (/atts quests on|off)"
L.OPT_ACTIONS = "Actions"
L.OPT_OPEN = "Open search"
L.OPT_OPEN_DESC = "Opens the All The Things main list with the cursor in the search bar. (/atts)"
L.OPT_CLEAR = "Clear Cache"
L.OPT_CLEAR_DESC = "Forgets the saved names and rebuilds the index. Names the game hasn't loaded have to be looked up again. (/atts clearcache)"
L.OPT_CLEAR_CONFIRM = "Forget ATT-Search's saved names and rebuild the index?\n\nNames the game hasn't loaded will have to be looked up again."
L.OPT_STATUS = "Status"
L.OPT_FOOTER = "Key binding: Options > Keybindings > AddOns > ATT-Search. Type /atts <text> to search right away, or /atts help for all chat commands."
L.OPT_QUESTS_WARNING ="TURNING THIS ON MIGHT AFFECT GAME PERFORMANCE. Quest names come from the server one by one, and the game uses the same server allowance for your quest log, quest objectives and All The Things' own quest names. ATT-Search asks for at most two a second, one at a time, and waits whenever the game or All The Things is loading quests, but the first full pass takes hours of play and can still slow down quest loading while it runs. Names are saved, so this mostly happens once."

-- /atts quests, /atts lookups
L.QUESTS_ON = "Load all quest names is on: the missing quest names now load slowly in the background."
L.QUESTS_OFF = "Load all quest names is off. Quests the game loads anyway are still searchable."
L.ITEMS_ON = "Load all item names is on: uncached item names now load slowly in the background."
L.ITEMS_OFF = "Load all item names is off. Items the game has cached are still searchable."
L.NEEDS_LOOKUPS = "Background lookups are off, so nothing loads until you turn them on (/atts lookups on)."
L.LOOKUPS_ON = "Background name lookups are on."
L.LOOKUPS_OFF = "Background name lookups are off. Search still finds every name the game has already loaded. /atts lookups on to turn them back on."

-- Status (/atts status and the options page): a label and a value per row
L.STATUS_INDEX = "Search index"
L.STATUS_INDEX_READY = "Ready, %s names"
L.STATUS_INDEX_BUILDING = "Building, %s names so far"
L.STATUS_INDEX_IDLE = "Waiting for All The Things"
L.STATUS_LOOKUPS = "Background lookups"
L.STATUS_LOOKUPS_RUNNING = "Running, %.1f per second"
L.STATUS_LOOKUPS_OFF = "Off (turn on \"Load names in the background\")"
L.STATUS_PAUSED_COMBAT = "Paused: in combat"
L.STATUS_PAUSED_PARTYSYNC = "Paused: party sync"
L.STATUS_PAUSED_RESTRICTED = "Paused: the game limits addons here (boss fight, Mythic+, PvP match...)"
L.STATUS_PAUSED_BACKOFF = "Paused for %d s: the server is busy, or party sync just ended"
L.STATUS_PAUSED_BACKOFF_NO_SYNC = "Paused for %d s: the server is busy"
L.STATUS_QUESTS = "Quest names"
L.STATUS_QUESTS_RUNNING = "Loading, one at a time"
L.STATUS_QUESTS_OFF = "Not loaded from the server (turn on \"Load all quest names\")"
L.STATUS_QUESTS_YIELD = "Waiting %d s: the game or All The Things is loading quests"
L.STATUS_QUESTS_BACKOFF = "Paused for %d s: the server is slow or refusing quests"
L.STATUS_QUESTS_COUNTS = "%s not loaded yet, %s asked for this session, %s skipped (no data on the server)"
L.STATUS_OTHER = "Other names"
L.STATUS_OTHER_COUNTS = "%s queued, %s waiting for a reply, %s waiting for the game, %s skipped (never loaded, or no data on the server)"
L.STATUS_PARTY_SYNC = "Party sync"
L.STATUS_PARTY_SYNC_ON = "Active"
L.STATUS_PARTY_SYNC_OFF = "Not active"
L.STATUS_SERVER = "This session"
L.STATUS_SERVER_COUNTS = "%s other lookups sent, %s quest lookups refused (%s of them ours)"
L.STATUS_REPLIES = "Quest data, last %d s"
L.STATUS_REPLIES_COUNT = "%s replies (to any addon or the game)"
