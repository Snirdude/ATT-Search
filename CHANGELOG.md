# Changelog

## 1.2.2
- The options page scrolls when it doesn't fit (a small settings window, or a long status), instead of running off the bottom. It uses the same thin scroll bar as the game's own settings, shown only when needed.
- Bigger text: nothing is smaller than the game's normal text size anymore. That includes the options page descriptions, the result paths and checkmarks, and the footer under the results. Result rows are a little taller to fit.

## 1.2.1
- Fixed the saved names starting over (on any character, or after a reload) once enough of them had loaded. The game can only load a saved file with up to about 262,000 different values in it, and a big cache went over that: the game skipped the file and the lookups began again from the start. Saved names are now packed into a few long strings, so the file stays far below the limit, and it's about half the size. Names saved by 1.2.0 that still load are kept.
- Fixed items being indexed as whole item links instead of their names, so searches like "item" or a number no longer match every item, and an item name now ranks as a match from its first letter.
- The saved names are shared by all characters on the account (they always were; the reset above made it look otherwise).

## 1.2.0
- Fixed for real: the quest log, quest objectives (tooltips, map, minimap), "Quest accepted" messages and ATT's quest names ("Retrieving data", "Quest #1234*") going missing after login, and especially during party sync. Quest data comes from the server one quest at a time, and the game gives each account a small allowance for it that the quest log and All The Things need too. ATT-Search used up that allowance:
  - Building the index asked the server about every quest in All The Things (tens of thousands) at every login. 1.1.7's fix didn't work: the check it switched to also loads the quest from the server. Reading some names from All The Things does the same.
  - Loading quest names in the background, even slowly, kept the game and All The Things waiting for their own quests.
- Quest names are now only loaded from the server if you ask for it: new option **Load all quest names** (Options > AddOns > ATT-Search, or `/atts quests on`), off by default. Turning it on might affect game performance. It asks for one quest at a time, at most two a second, and waits whenever the game or All The Things is loading quests. It also backs off when replies get slow, don't come, or keep being refused (30 seconds, then 1, 2, 3, 4 and 5 minutes each time in a row), and asks for unobtainable and removed quests last (the server has no data for many of them).
- Quests the server has no data for (refused in two separate sessions) are remembered and skipped until the next game patch, so Load all quest names doesn't keep asking for them.
- New option **Load all item names**, on by default (`/atts items on|off`): loads the names of items the game hasn't cached, at the same slow, limited rate as other names, so every item is searchable without running `/atts warmup` each session. `/atts warmup` now turns this option on.
- With Load all quest names off, quests the game loads anyway (your quest log, quests shown in All The Things) are still indexed as they load, and saved for next time.
- Nothing the index does while walking the list asks the server anymore:
  - A quest counts as loaded only when All The Things ships its name or the game reports it loaded. Hidden quest triggers, which have no data on the server, are skipped.
  - Achievement criteria use the game's own criteria text. Criteria without one are skipped: All The Things names those after a quest, NPC or item, which can ask the server (and you find them by that name anyway).
  - Objects that All The Things has no name for go through the slow background queue.
  - The once-a-minute re-check of names still loading never asks the server. It now also runs with `/atts lookups off`, so names the game loads on its own still get added.
- Other background lookups (NPCs, objects...) are gentler: 2 per second at first, at most 10, with no more than 4 waiting for a reply.
- New options page (the cog at the end of the search bar, Options > AddOns > ATT-Search, or `/atts options`) with everything the chat commands do: the three settings, Open search and Clear Cache buttons (Clear Cache asks first), and a live status. Settings are now saved apart from the saved names, so clearing them keeps your settings.
- `/atts status` shows the quest names on a line of their own, and no longer shows "quest names to repair". Refused quests are no longer looked up a second time.
- If an earlier version already got your account throttled, quest data can stay slow for a while after updating. It clears on its own.

## 1.1.7
- Fixed the quest log, quest objectives (tooltips, map, minimap) and "Quest accepted" messages going missing for a while after login or party sync. Building the search index checked every quest in All The Things with a function that turns out to ask the server when the quest isn't loaded yet. On a fresh cache that sent thousands of quest requests, unthrottled, and the game's own quest data waited behind them. The index now uses a check that never queries the server, and quests that aren't loaded go through the slow background queue like everything else.
- Fixed quest names in ATT's list turning into "Quest #1234*" during party sync. Background lookups now pause during party sync and for 90 seconds after it ends, while the game reloads your quests. They also pause for 30 seconds after the server refuses a lookup, and for 60 seconds when it stops answering. Each refused quest is looked up once more afterwards, which gives ATT its name back.
- The once-a-minute re-check of names still loading now pauses with everything else (party sync, combat, `/atts lookups off`). Names that might make All The Things ask the server (like achievement criteria named after a quest) now go through the slow background queue instead of being re-read every minute.
- New `/atts lookups off` (and `on`): stops ATT-Search from asking the server for names in the background. Search still finds every name the game has already loaded. The setting is saved.
- New `/atts status`: shows whether background lookups are running or paused (and why), whether party sync is detected, the queues, and how many quest lookups the server refused. Handy for bug reports.

## 1.1.6
- Fixed a long freeze, and ATT's list staying on "Retrieving data", on a fresh game cache (new install, cleared Cache folder or a new patch). Background name loading now starts 15 seconds after indexing, begins at 5 server requests per second and only speeds up (to 25) while your frame rate stays above 20. It drops back when the frame rate does.
- At most 8 background requests wait for a server reply at once, so ATT's own lookups for the rows you're looking at are never stuck behind them.

## 1.1.5
- Internal cleanup, no new features: the code is reorganized into smaller files, all use of All The Things' internals goes through one file (so ATT updates are quicker to support), and all text is ready for translation.
- Saved names for things that are no longer in All The Things are now removed, so the saved file doesn't keep growing across patches.

## 1.1.4
- Result tooltips show the entry's id (NPC ID, Quest ID, Achievement ID...), plus Item ID and Spell ID when it has them.

## 1.1.3
- Shift+click a result (or Shift+Enter) to set a waypoint to it, using ATT's own waypoint feature: TomTom if installed, otherwise the map pin on the nearest known location. Works for NPCs, treasures, quest givers and anything else ATT has coordinates for.
- The search index now survives /reload and relogging: names that are slow to look up (NPCs, quests, items) are saved and reused, so the index is ready again in moments without asking the server.
- Indexing starts on its own a few seconds after login, so it's usually done before your first search.
- New `/atts clearcache` command to forget the saved names and rebuild.

## 1.1.2
- Drag the search bar to move the ATT window. ATT's window lock is respected and the new position is saved.

## 1.1.1
- Hidden results now name the exact ATT filter or option hiding them, for example "Horde only (Race filter)", "Level requirement (Level filter), on Northrend" or "Already collected (Show Collected Things is off)".
- Results shown in the main list are listed before hidden ones.
- Background name loading is faster: names already in the game's cache no longer count toward the limit, and the limit for real server requests is now 25 per second (still paused in combat).

## 1.1.0
- Now loads on every game version All The Things supports: Classic Era, Forever, TBC Classic Anniversary, Wrath Classic (including Titanforged), Cata Classic, MoP Classic and Retail.
- Uses the quest and item functions available on each game version, and still throttles anything that may reach the server.
- Falls back to a plain search box if the game version has no search box template.
- Clicking a result (or pressing Enter) now always closes the results list, including when the result is hidden by your ATT filters.
- Background updates no longer reopen the results list after you close it. Click into the search box to bring the results back.
- Each result shows whether you have it: a green check when collected or completed, a red cross when not, and progress (like 5/12) for zones, NPCs and other groups. It uses the same data as ATT's own list.
- Results that the main list hides are greyed out and say why, for example "Horde only", "Not for your class" or "Hidden by your ATT filters".
- The results list now has a solid background, so ATT's rows no longer show through it.

## 1.0.1
- Fixed a freeze and server disconnect on clients with few names cached. Building the search index could send thousands of server requests per second.
- Names that need the server (NPCs, quests) now load in the background at most 10 per second, paused in combat. Each one is asked for once.
- Background work uses a smaller, shared time budget per frame, so typing stays smooth.
- `/atts warmup` uses the same slow, safe rate.

## 1.0.0
- First release.
- Search bar on top of the All The Things main list, with results as you type and keyboard navigation.
- Opening a result expands its parents and scrolls to it, and ATT highlights the row.
- `/atts`, `/atts <text>`, `/atts warmup`, and a key binding.
