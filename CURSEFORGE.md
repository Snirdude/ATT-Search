# ATT-Search: CurseForge upload sheet

What to type into each CurseForge field, ready to copy and paste. The steps for a first upload and for releasing an update are in `UPLOADING.md` in the wow-addons repo.

Update this sheet with every release: the zip, the display name and the changelog, and rewrite the description so it covers everything in the new version. The release script won't publish until the zip, display name and changelog name the new version.

## A. Project form

**Project name**
```
ATT-Search
```

**Summary**
```
Search bar for the All The Things main list: find anything, see if you have it, and jump or set a waypoint to it.
```

**Main category:** `Achievements`
**Additional categories:** `Plugins` (if there's a `Collections` or `Transmogrification` category, add that too)

**License:** `MIT License`

**Logo / avatar:** `ATT-Search\images\logo-400.png`

**Description** (paste everything between the lines)

---
```markdown
## Find anything in All The Things

ATT-Search adds a search bar to the top of the **All The Things** main list. Type any name (a zone, NPC, vendor, item, mount, quest, achievement...), pick a result, and the list expands to it, scrolls to it and highlights it. No more clicking through layers of headers.

Unofficial companion for All The Things, made with the ATT author's blessing. Not affiliated with the ATT team. **Requires All The Things.**

### Features
- **Results as you type**, each with its icon and where it sits in the list (e.g. Northrend > Borean Tundra > Quests).
- **See what you have at a glance:** a green check when it's collected or completed, a red cross when it's not, and progress like 5/12 for zones, NPCs and vendors. Same data as ATT's own list.
- **Know why something is hidden:** results your ATT settings hide are greyed out and name the exact filter, e.g. "Horde only (Race filter)" or "Already collected (Show Collected Things is off)". Results you can see in the list come first.
- **Waypoints:** Shift+click a result to set a waypoint to it, using TomTom if you have it or the map pin otherwise. Works for NPCs, treasures, quest givers and anything else ATT has coordinates for.
- **Move the ATT window** by dragging the search bar.
- **Fast and smooth:** the index builds in the background after login without stutters, and is ready again moments after a /reload.
- **Works on every game version ATT supports:** Retail, MoP Classic, Cata Classic, Wrath Classic, TBC Classic Anniversary, Classic Era and Forever.

### How to use
1. Open the ATT main list. The search bar sits on its top edge.
2. Type 3 or more letters.
3. Arrow keys or Tab to move, **Enter** or click to show it in the list, **Shift+Enter** or Shift+click for a waypoint, **Esc** to close.

### Commands
- **/atts**: open the main list and focus the search bar
- **/atts <text>**: search right away
- **/atts warmup**: load item names the game hasn't loaded yet, slowly in the background
- **/atts clearcache**: forget the saved names and rebuild the index
- Key binding: Options > Keybindings > AddOns > ATT-Search

### Good to know
- Indexing starts a few seconds after login; the bottom of the results shows its progress. Names are saved, so after a /reload the index is ready again in moments.
- Names the game hasn't loaded yet fill in gradually in the background, paused in combat. Items appear once the game has loaded them, or use **/atts warmup**.
- A big ATT update may need an ATT-Search update too.
```
---

**Source / Issues links:** leave empty unless you put the code on GitHub.

## B. Upload File form

**File:** `dist\ATT-Search-1.2.3.zip`

**Display name**
```
ATT-Search 1.2.3
```

**Release type:** `Release`

**Game versions:** tick every version listed for each of these (ATT supports them all):
- Retail: `12.1.0` and `12.1.5`
- MoP Classic: `5.5.x`
- Cata Classic: `4.4.x`
- Wrath Classic: `3.4.x`
- TBC Classic Anniversary: `2.5.x`
- Classic Era: `1.15.x`
- Forever (`1.60.x`), if CurseForge lists it

**Changelog** (paste every section newer than the last version on CurseForge; this sheet last went up as 1.1.5)
```markdown
1.2.3
- Fixed the highlighted result jumping back to the top of the list while you moved through it with the arrow keys or Tab. While names are still loading, the results refresh every few seconds; the highlight now stays on the same result, in the same spot, instead of resetting.

1.2.2
- The options page scrolls when it doesn't fit (a small settings window, or a long status), instead of running off the bottom. It uses the same thin scroll bar as the game's own settings, shown only when needed.
- Bigger text: nothing is smaller than the game's normal text size anymore. That includes the options page descriptions, the result paths and checkmarks, and the footer under the results. Result rows are a little taller to fit.

1.2.1
- Fixed the saved names starting over (on any character, or after a reload) once enough of them had loaded, so name loading began again from the start. The saved names also take about half the space now. Names saved by 1.2.0 that still load are kept.
- Fixed searches like "item" or a number matching every item. An item name now ranks as a match from its first letter.
- The saved names are shared by all characters on the account (they always were; the reset above made it look otherwise).

1.2.0
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

1.1.7
- Fixed the quest log, quest objectives (tooltips, map, minimap) and "Quest accepted" messages going missing for a while after login or party sync, mostly on a fresh game cache: building the search index held up the game's own quest data.
- Fixed quest names in ATT's list turning into "Quest #1234*" during party sync. Background name loading now pauses during party sync and for a while after it ends, and when the server is slow or refuses.
- New `/atts lookups off` (and `on`): stops ATT-Search's background name loading. Search still finds every name the game has already loaded. The setting is saved.
- New `/atts status`: shows whether background name loading is running or paused, and why. Handy for bug reports.

1.1.6
- Fixed a long freeze, and ATT's list staying on "Retrieving data", on a fresh game cache (new install, cleared Cache folder or a new patch). Background name loading now starts later and slower, and only speeds up while your frame rate is healthy.
- The rows you're looking at in ATT's list no longer wait behind ATT-Search's background loading.
```

**Related projects:** add as **Required Dependency**:
- `All The Things`
