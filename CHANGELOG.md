# Changelog

## 1.3.0
- Search by ID: type a number to find every item, quest, NPC, achievement, spell and more whose ID starts with it, the exact ID first. It finds things whose names haven't loaded yet, too.
- Put a kind in front to narrow it down: `item 19019`, `quest:1234`, `npc 5`, `ach 6` (also spell, mount, pet, toy, recipe, currency, faction, title, map, instance, encounter, object, criteria, decor and illusion).
- ID searches work with just one or two digits, and each result shows the ID it matched.

## 1.2.6
- Fixed results showing "Unknown" instead of an NPC's name, for example Delve vendors. It happened when All The Things couldn't show the name at that moment: after the game had hidden it from addons, or before it had loaded. Results, their tooltips and the chat message for hidden results now show the name.
- After an update, a What's New window shows what changed since the version you had.

## 1.2.5
- Fixed "Loading ... more names in the background" starting over at every login. Recipe, mount, pet, housing decor and other item names loaded while you played but weren't kept, so they loaded again every session and the number never went down. Names now stay loaded across logins and /reloads; only new things (after a game patch or an All The Things update) load again.
- Fixed background name loading stalling on items that no longer exist in the game. They held up every other name, often for a whole session.
- Names that never load (items the server doesn't answer, some NPCs) are now skipped until the next game patch, like quests that can't be loaded, instead of being tried again at every login. `/atts status` counts them with the other skipped names.

## 1.2.4
- Fixed "not loaded yet" getting stuck at the same number with Load all item names on. Items the game has no data for (usually ones removed from the game) waited forever; they're now skipped, and `/atts status` shows how many. Items the server didn't answer are asked for again.
- Background name loading now also pauses in boss fights, Mythic+ keys, PvP matches and other places where the game limits addons. NPC names loaded there came back unreadable and stayed missing from search until a reload.
- NPCs whose names All The Things itself loaded in those places are searchable again once you leave.

## 1.2.3
- Fixed the highlighted result jumping back to the top of the list while you moved through it with the arrow keys or Tab. While names are still loading, the results refresh every few seconds; the highlight now stays on the same result, in the same spot, instead of resetting.

## 1.2.2
- The options page scrolls when it doesn't fit (a small settings window, or a long status), instead of running off the bottom. It uses the same thin scroll bar as the game's own settings, shown only when needed.
- Bigger text: nothing is smaller than the game's normal text size anymore. That includes the options page descriptions, the result paths and checkmarks, and the footer under the results. Result rows are a little taller to fit.

## 1.2.1
- Fixed the saved names starting over (on any character, or after a reload) once enough of them had loaded, so name loading began again from the start. The saved names also take about half the space now. Names saved by 1.2.0 that still load are kept.
- Fixed searches like "item" or a number matching every item. An item name now ranks as a match from its first letter.
- The saved names are shared by all characters on the account (they always were; the reset above made it look otherwise).

## 1.2.0
- Fixed for real: the quest log, quest objectives (tooltips, map, minimap), "Quest accepted" messages and ATT's quest names ("Retrieving data", "Quest #1234*") going missing after login, and especially during party sync. The game loads quest data slowly, and the quest log and All The Things need it too; ATT-Search was holding it up, both while building the search index and while loading quest names in the background. 1.1.7's fix didn't fully solve it.
- Quest names are now only loaded if you ask for it: new option **Load all quest names** (Options > AddOns > ATT-Search, or `/atts quests on`), off by default. Turning it on might affect game performance. It loads slowly, gives way whenever the game or All The Things is loading quests, and backs off when the server is slow or refuses.
- Quests that can't be loaded are skipped until the next game patch, so Load all quest names doesn't keep trying them.
- New option **Load all item names**, on by default (`/atts items on|off`): loads the names of items the game hasn't loaded yet, slowly in the background, so every item is searchable without running `/atts warmup` each session. `/atts warmup` now turns this option on.
- With Load all quest names off, quests the game loads anyway (your quest log, quests shown in All The Things) are still indexed as they load, and saved for next time.
- Building the search index no longer slows down the game's own loading.
- Achievement criteria named after a quest, NPC or item are no longer listed on their own; search for that quest, NPC or item instead.
- With `/atts lookups off`, names the game loads on its own still get added.
- Background name loading (NPCs, objects...) is gentler.
- New options page (the cog at the end of the search bar, Options > AddOns > ATT-Search, or `/atts options`) with everything the chat commands do: the three settings, Open search and Clear Cache buttons (Clear Cache asks first), and a live status. Clear Cache keeps your settings.
- `/atts status` shows the quest names on a line of their own.
- If an earlier version already slowed down your quest data, it can stay slow for a while after updating. It clears on its own.

## 1.1.7
- Fixed the quest log, quest objectives (tooltips, map, minimap) and "Quest accepted" messages going missing for a while after login or party sync, mostly on a fresh game cache: building the search index held up the game's own quest data.
- Fixed quest names in ATT's list turning into "Quest #1234*" during party sync. Background name loading now pauses during party sync and for a while after it ends, and when the server is slow or refuses.
- New `/atts lookups off` (and `on`): stops ATT-Search's background name loading. Search still finds every name the game has already loaded. The setting is saved.
- New `/atts status`: shows whether background name loading is running or paused, and why. Handy for bug reports.

## 1.1.6
- Fixed a long freeze, and ATT's list staying on "Retrieving data", on a fresh game cache (new install, cleared Cache folder or a new patch). Background name loading now starts later and slower, and only speeds up while your frame rate is healthy.
- The rows you're looking at in ATT's list no longer wait behind ATT-Search's background loading.

## 1.1.5
- Behind-the-scenes cleanup, no new features: big All The Things updates are quicker to support, and all text is ready for translation.
- Saved names no longer keep piling up across patches.

## 1.1.4
- Result tooltips show the entry's id (NPC ID, Quest ID, Achievement ID...), plus Item ID and Spell ID when it has them.

## 1.1.3
- Shift+click a result (or Shift+Enter) to set a waypoint to it: TomTom if installed, otherwise the map pin on the nearest known location. Works for NPCs, treasures, quest givers and anything else ATT has coordinates for.
- The search index now survives /reload and relogging: names are saved, so the index is ready again in moments.
- Indexing starts on its own a few seconds after login, so it's usually done before your first search.
- New `/atts clearcache` command to forget the saved names and rebuild.

## 1.1.2
- Drag the search bar to move the ATT window. ATT's window lock is respected and the new position is saved.

## 1.1.1
- Hidden results now name the exact ATT filter or option hiding them, for example "Horde only (Race filter)", "Level requirement (Level filter), on Northrend" or "Already collected (Show Collected Things is off)".
- Results shown in the main list are listed before hidden ones.
- Background name loading is faster (still paused in combat).

## 1.1.0
- Now loads on every game version All The Things supports: Classic Era, Forever, TBC Classic Anniversary, Wrath Classic (including Titanforged), Cata Classic, MoP Classic and Retail.
- Game versions without the standard search box get a plain one.
- Clicking a result (or pressing Enter) now always closes the results list, including when the result is hidden by your ATT filters.
- Background updates no longer reopen the results list after you close it. Click into the search box to bring the results back.
- Each result shows whether you have it: a green check when collected or completed, a red cross when not, and progress (like 5/12) for zones, NPCs and other groups. It uses the same data as ATT's own list.
- Results that the main list hides are greyed out and say why, for example "Horde only", "Not for your class" or "Hidden by your ATT filters".
- The results list now has a solid background, so ATT's rows no longer show through it.

## 1.0.1
- Fixed a freeze and server disconnect while the search index was building, on a fresh game cache.
- Names the game hasn't loaded yet (NPCs, quests) now fill in slowly in the background, paused in combat.
- Typing stays smooth while the index builds.
- `/atts warmup` loads at the same slow, safe pace.

## 1.0.0
- First release.
- Search bar on top of the All The Things main list, with results as you type and keyboard navigation.
- Opening a result expands its parents and scrolls to it, and ATT highlights the row.
- `/atts`, `/atts <text>`, `/atts warmup`, and a key binding.
