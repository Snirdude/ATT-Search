# ATT-Search

Adds a search bar to the top of the **All The Things** main list. Type a name, pick a result, and the list expands to it, scrolls to it and highlights it.

Unofficial companion for [All The Things](https://www.curseforge.com/wow/addons/all-the-things), published with the ATT author's blessing. Not affiliated with the ATT team. Requires All The Things. Works on every game version ATT supports: Retail, Classic Era, Forever, TBC Classic Anniversary, Wrath Classic, Cata Classic and MoP Classic.

## Install
Copy the `ATT-Search` folder to `World of Warcraft\_retail_\Interface\AddOns\` and reload.

## Use
- Open the ATT main list. The search bar sits on its top edge.
- Type 3+ letters. Use the arrow keys or Tab to move through results, Enter or click to open one, and Esc to close.
- Shift+click a result (or Shift+Enter) to set a waypoint to it: TomTom if installed, otherwise the map pin.
- `/atts` opens the main list and focuses the search bar.
- `/atts <text>` searches right away.
- `/atts items on|off` turns Load all item names on or off (on by default). `/atts warmup` turns it on.
- `/atts quests on|off` turns Load all quest names on or off (see Notes). Off by default.
- `/atts lookups off` stops all background name requests to the server (`/atts lookups on` turns them back on). Search still finds every name the game has already loaded.
- `/atts status` shows what the background name loading is doing.
- The cog at the end of the search bar, or `/atts options`, opens the options page (also under Options > AddOns > ATT-Search). It has everything the chat commands do: the three settings, Open search and Clear Cache buttons, and a live status.
- Key binding: Options > Keybindings > AddOns > ATT-Search.

## Notes
- The search index builds in the background a few seconds after login (the footer shows its progress). Names that are slow to look up are saved, so after a /reload or relog the index is ready again in moments. `/atts clearcache` clears them.
- Building the index never makes the game ask the server for anything. Names the game hasn't loaded yet (NPCs, objects) load in the background: names already in the game's cache come in right away, and the rest go to the server slowly: starting at 2 per second, rising to at most 10 only while your frame rate is healthy, with only a few waiting for a reply at once, and never in combat or during party sync. Items the game hasn't cached load the same way (**Load all item names**, on by default); turn it off to only search items the game has cached. The game keeps item data, so this mostly happens once.
- Quests are different: the game gives each account a small allowance of quest data requests, and your quest log, quest objectives and All The Things need it too. So by default ATT-Search never asks for quests itself. Quests the game loads anyway (your quest log, quests shown in All The Things) are indexed as they load and saved for next time. Turn on **Load all quest names** to load all quest names: one at a time, at most two a second, waiting whenever the game or All The Things is loading quests. Turning it on might affect game performance while the first pass runs (it takes hours of play; names are saved, so it mostly happens once).
- If a result is hidden by your ATT filters (for example, "hide collected"), its parents are still expanded and you get a chat message.
- This uses ATT's internal functions (`AllTheThings.Windows.Prime`, `window:ScrollTo`, `window:Update`), so a large ATT update may need a patch here.
