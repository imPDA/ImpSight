# ImpSight

**A Spotlight-style universal search for The Elder Scrolls Online.**

ImpSight adds a single search box that lets you instantly find and jump to game settings, zones, skills, keybindings, item sets, and slash commands — without digging through menus. Type, fuzzy-match, hit Enter, and ImpSight navigates to the right place and highlights the exact row for you.

---

## Features

### 🔎 Universal Fuzzy Search

- One search box covering **six different data sources** at once:
  - **Settings** — all game options and their categories (Audio, Video, Gameplay, …)
  - **Zones** — every zone that has an available map
  - **Skills** — skill lines, passives (max rank 2), and every active/morph ability
  - **Keybindings** — all actual bindings (not headers)
  - **Item Sets** — every set in the Item Set Collections book
  - **Slash Commands** — all registered `/commands`
- **Fuzzy matching** powered by an FZY-style scorer — results are ranked by match score, not just substring presence.
- Case-insensitive matching.
- Matching characters in the result row are **highlighted in orange** (`FFA500`).
- Debounced input (200 ms) so typing stays snappy.
- Shows up to **10 results** at once.

### 🧠 Smart Caching & Query Optimization

- Query results are cached (up to **100 entries**, FIFO eviction).
- Only cached if the query takes **> 5 ms** and is at least **2 characters** long.
- **Prefix caching** — if you extend a cached query, ImpSight reuses the shorter query's result set instead of scanning the full haystack.
- **Follow-up optimization** — when each new query is a prefix-extension of the previous one, the previous result set is reused.
- A live hint shows the **query time (ms)** and **approximate cache memory (KB)**.
- Texture strings (`|t…|t`) are skipped during highlight colorization so icons aren't mangled.

### 🧭 Deep Navigation & Highlighting

When you select a result, ImpSight doesn't just open a panel — it navigates to the exact element and flashes a highlight over it.

- **Settings** — opens the Game Menu, selects the correct subcategory node, scrolls the setting into the central view, and highlights it.
- **Zones** — opens the Map category and switches to the zone's map via `WORLD_MAP_MANAGER:SetMapById`.
- **Skills** — opens the Skills window, selects the skill line, and highlights either the specific skill/morph or the skill-line header. Handles subclassing panels, including closing the subclassing view first when needed and opening it when the target line lives there.
- **Keybindings** — opens Game Menu → Controls, scrolls the binding to the center of the list, and highlights it.
- **Item Sets** — opens the Item Set Collections book, selects the correct category, scrolls the set row to center, and highlights it.
- **Slash Commands** — executes the command directly via `DoCommand`.
- **Highlight animation**: a green overlay fades in, stays for 1 second, then fades out (1 s fade), using `ZO_AlphaAnimation`. Repeated highlights cancel the pending hide task and restart the animation.

### 📜 Search History

- Stores up to **10** previous searches in account-wide saved variables (`IMP_ImpSight_SavedVariables`).
- **Up arrow** enters history mode (preserving your current input) and walks backward through entries; **Down arrow** walks forward and exits history at the end.
- A hint displays your position, e.g. `History: 1/5`.
- Duplicate entries are moved to the front rather than duplicated.
- Entering history hides the results table; exiting restores your saved input.

### ⌨️ Input Handling

- **Enter** uses the currently selected result row (or row 1 by default), adding it to history.
- If nothing matches and the input starts with `/`, ImpSight treats it as a raw slash command and executes it.
- **Up / Down arrows** navigate history as described above.
- Empty input clears results and hints immediately.
- Search box can be toggled open/closed with the addon's toggle function.

### ⚠️ Known Limitations (from the code)

- Duplicate strings across different sources are not yet disambiguated (`#duplicates` TODO) — the last gathered source wins in `sourceRef`.
- History row indexes are treated as slightly fragile (noted in `Use`).
- Some maps may fail to open via `SetMapById` (`#mapAvailability` TODO).
- Slash-command results with arguments won't match as valid commands during search; only exact command names are indexed.

---

*Version: `X`*