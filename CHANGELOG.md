# 1.1.2

- Moved windows are marked so the game keeps no copy of their spot of its own (SetDontSavePosition), even when a drag is cut short.

# 1.1.1

- A protected window whose drag a fight cut into is let go of right after the fight, instead of the game blocking the addon.
- Reset and turning the addon off put windows back at the game's spot even when they are closed (the Esc menu was left where it had been moved).
- The quest tracker stays invisible in a fight even after Alt+Z.
- A drag cut short by a window closing no longer leaves the window flagged as placed by hand.
- Damaged saved data (a broken spot, an unknown drag mode) is cleaned up at login instead of breaking a window.
- The hidden quest tracker no longer comes back during a fight when quest progress updates: in combat it turns invisible, and it is hidden once the fight ends.
- Turning the option off no longer shows an empty tracker the game had hidden itself.
- `/fw tracker` says so when the addon is off instead of claiming the tracker is hidden.
- The tracker help mentions that timed quest countdowns are hidden with it.

# 1.1.0

- Hide the quest tracker: a switch in the window (or `/fw tracker`) keeps the list of quests and objectives at the right edge of the screen hidden. In a fight the change waits for its end.
- The friends window shows its name in the list of moved windows instead of "SocialUI".

# 1.0.1

- Window spots no longer drift when the game shrinks a window (the bags while the bank is open, panels that don't fit the screen).
- The maximized world map is left where the game puts it.
- A window closed in the middle of a drag keeps its saved spot from then on.
- The loot window is left to Edit Mode.
- The Options page follows a language change.

# 1.0.0

- First release.
