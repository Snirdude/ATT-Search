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
- **See what you have:** a green check when it's collected, a red cross when it's not, and progress like 5/12 for zones and vendors.
- **Know why something is hidden:** results your ATT settings hide are greyed out and name the filter, e.g. "Horde only (Race filter)".
- **Waypoints:** Shift+click a result for a waypoint, with TomTom or the map pin.
- **Every item searchable,** even ones the game hasn't loaded yet. Names load once and stay saved.
- **Gentle on your game:** it slows down when your frame rate drops, and pauses in combat, boss fights and Mythic+.
- **Move the ATT window** by dragging the search bar.
- **What's New:** after an update, a window shows what changed since the version you had.
- **Every game version ATT supports:** Retail, MoP Classic, Cata Classic, Wrath Classic, TBC Classic Anniversary, Classic Era and Forever.

### How to use
1. Open the ATT main list. The search bar sits on its top edge.
2. Type 3 or more letters.
3. Arrow keys or Tab to move, **Enter** or click to show it in the list, **Shift+Enter** for a waypoint, **Esc** to close.

Type **/atts** to open the list with the search bar ready, or **/atts <text>** to search right away. There's also a key binding.

### Options
Click the cog at the end of the search bar. Choose whether every item and quest name is searchable from the start (items on by default; quests off, since the game loads quest data slowly), and see what ATT-Search is loading right now.

### Good to know
- Ready a few seconds after login, and in moments after a /reload.
- A big ATT update may need an ATT-Search update too.

**Feedback and bug reports are welcome** in the comments.
```
---

**Source / Issues links:** leave empty unless you put the code on GitHub.

## B. Upload File form

**File:** `dist\ATT-Search-1.2.6.zip`

**Display name**
```
ATT-Search 1.2.6
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

**Changelog** (paste only the newest part; paste older parts too if they never went up)
```markdown
1.2.6
- Fixed results showing "Unknown" instead of an NPC's name, for example Delve vendors. It happened when All The Things couldn't show the name at that moment: after the game had hidden it from addons, or before it had loaded. Results, their tooltips and the chat message for hidden results now show the name.
- After an update, a What's New window shows what changed since the version you had.
```

**Related projects:** add as **Required Dependency**:
- `All The Things`
