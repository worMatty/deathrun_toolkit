# Deathrun Toolkit
## Changelog

## Version 0.4.7.1
Bug fixes:
* Replacement weapons were not being equipped

### Version 0.4.7
New features:
* Activator ban using Steam ID via console commands or admin menu
* Option to flag selected players to receive twice the amount of queue points so they become activator sooner. This is useful for playtesting.

Major changes:
* Map instructions system removed because VScript can do all that now
* Activator health displays removed so as not to interfere with VScript maps in future

Minor changes:
* Game description now works with SteamWorks, not SteamTools
* Players no longer see, or can reset their queue points. It's a transparent system
* Two new translation phrases awaiting translation
* Database records are now deleted six months after the player last played, up from one month
* Melee only mode no longer gives the 'Cannot switch from melee' condition
* Melee only mode removes all other weapons, not just primary and secondary
* The activator's backstab damage taken is no longer capped
* Blue melee-only convar
* All Spy watches have been added to the restrictions config for removal

Bug fixes
* Players who opt out of being an activator will no longer receive queue points

Code changes:
* Database functions and commands cleaned up, changed and improved
* New ArrayList methodmaps with custom methods for entities, players and activators
* Learned how to use enum structs a bit, for the player data array
* VScript is used to apply attributes instead of TF2 Attributes, saving a dependency
* No more hard-coded Spy cloak attributes. Use the item restrictions config


### Version 0.4.6.3
Minor changes:
* Plugin can be compiled with SP 1.11 without errors.

Bug fixes:
* The timer that refreshed the HUD text display of the Activators' health was active between map changes and while the plugin was not enabled (when switching to non-deathrun maps). It was checking the array of Activators, but it doesn't exist while the plugin is disabled, so it was throwing an exception every second. The timer is now stopped if the plugin is not enabled.


### Version 0.4.6.2
Bug fixes:
* Players that were moved to spec because they had no class mistakenly had their life state set to 'alive'. When they joined a team, the game thought they were alive so the round would not end when everyone else died.

Minor changes:
* Players with no class are no longer moved to spec. Instead, they are just dead, which is the game's normal behaviour.

Known issues:
* Players on red or blue who have not chosen a class are included in the activator pool. On servers with one activator this is not a problem as the player will be dead so the round will simply end. However with multiple activators, there will be at least one dead activator. Proposed future fix is to change how the plugin views players as participating.


### Version 0.4.6
Minor changes:
* sm_na can be used to set the next activator by an admin
* sm_na now always shows the next three activators and doesn't accept a quantity
* Next activator printed to chat every 120 seconds post round start

Major changes:
* Activator health scaling algorithm changed. Activator(s) have less scaled health now
* Added a WIP cvar to switch between different health scaling modes (new, overheal, old, multiply)

Bug fixes:
* sm_setclass no longer plays multiple message sounds to the command user
* sm_setclass was applying attributes to the command user instead of the targets
* Boss health bar was initially at the wrong value when activator's health got scaled
* Activator health scaling triggers were not working sometimes
* When using the admin menu option to scale activator health, health pack reduction attribute was not being applied to the activators

Known issues:
* Players who were an activator with scaled health in the previous round have an overheal

### Version 0.4.1
Fixed a bug preventing the Activator boost HUD displaying after a map change.

### Version 0.4
Major Changes
* Improved team balancing
* Improved activator queue
* Improved multiple activator support
* Added basic configurable weapon restriction system

Minor Changes
* /prefs gone, /drtoggle toggles activator preference directly
* New command for Next Activators: /na [number]
* Menu system simplified and options shortened
* Players with no class are moved to spec on round start
* Activator lock extended to pre-round freeze time

Other Stuff:
* ConVar added for team mate push-away
* Added a new fun mode: slap every ten seconds
* Retired some translation phrases and added new ones

__Improved Team Balancing__
Much better protection against players joining the blue team when they are not designated activators. Improved ‘ready state’ detection in TF2 Classic and Open Fortress to prevent stalled rounds. Worked around a behaviour in TF2 where the first round of a map would have two restarts, causing two activator selections, with the first one selected being instantly replaced and their points lost. Potentially fixed a bug where the plugin would not ‘work’ in the first round, players could join any team and the queue system would not function.

__Improved Activator Queue__
Half and full point awards are gone. Instead of each red player receiving ten queue points at the end of a round and only if they were present at the beginning of it, all red players receive one queue point every ten seconds. People who opt out of being an activator continue to accrue queue points. Queue points are no longer communicated to players as they are only used to manage the activator queue or for admins to influence by awarding points. It’s still possible to view and reset your points using /points and /reset. When sorting the queue, the plugin now factors in the last time a player was made activator, so if no one has any points or two players have the same points, the order will be fair regardless and no one should ever be activator twice in a very short time.

__Improved Multiple Activator Support__
There are two cvars for managing activator numbers: dtk_activators_max which acts as a maximum number, and dtk_activators_ratio which defines the fraction of players who will be selected. e.g. If the ratio is 0.2, then one fifth of players will be selected as activator, but only up to the max. There will always be at least one activator and at least one runner.

Now if an activator switches teams during pre-round freeze time, only they will be replaced instead of the whole blue team.

The boss bar now tracks the combined health of all activators, and correctly adapts to overheals by raising and fixing its ceiling. In TF2C and OF where there is no boss bar, up to two activator names and their health are drawn on-screen, and with more than that alive it displays a combined total. This is to prevent screen clutter.

__Next Activator Command__
/na can be used at any time to show you the next activator. If you specify a number, it will show you that many players in the queue. By default it will show you as many names as there should be activators on the next round (provided the player count is the same).

__Basic Weapon Restriction System__
This has been a long time coming. There are now the barebones of a system that lets you either replace or modify the attributes of a player’s weapon. Replacements are stored in a separate file. I have only added in a small number of weapons as this system is not finished.

__Team Mate Push-Away ConVar__
The plugin disables push-away when the game mode is enabled but if a server wanted to enable it on a per-map basis using a mapname.cfg file, the plugin would override it. Now a server can add dtk_push_away 1 to the config to enable it.

__Activator Lock During Freeze-Time__
You can now set dtk_lock_activator to 2 to prevent activators switching away from blue during pre-round freeze time after they have been selected. This is not normally something I recommend you do but it may be useful in some cases.

### Version 0.3
Complete rewrite.

Removed:
* System that turned on team mate pushaway at low reds.

Added:
* WIP activator speed boost by binding +speed. Works like HL2 sprint.
* Sounds to some text chat messages.
* WIP ratio of activators. dtk_activators now functions as a cap.
* Map instructions to set custom model and use class animations.
* ConVar to customise the game description that's displayed in the server browser

Changed:
* Standardised and simplified plugin chat messages.
* Disabld Waiting For Players time in OF and TF2C for better compatability.
* Improved the system that prevents players joining Blue.
* TF2 Attributes is required if you want to change player attributes.
* Red players only receive queue points on round end if they were there from the start.

Fixed:
* Periodic team checks in OF to start a round when enough players are present.
* In TF2C and OF, Health: 0 is no longer displayed on round restart
* In TF2C, picking up a health kit updates the boss health text

I like the idea of team mate pushaway because it makes a map need more skill and requires the player to be more patient and cooperate. Saxton Hell has this feature but Voidy disables it in certain parts of maps because it causes issues. In DTK I had a feature that enabled teammate pushway when there were only a few red players left. Through play testing it became clear than no one appreciated this feature other than me so I have removed it.

Activator run speed boost works like HL2's Sprinting. You have a HUD element that shows you your boost charge and when you run out you can't boost anymore and have to wait for it to fill up a bit. Activating the boost is done by binding a key to `+speed`. I suggest the Shift key as that is what is used in HL2 and by default is not bound to anything in TF2.

Part of my design brief for my Jailbreak plugin was to streamline text displayed to users to as few channels and messages as possible to reduce confusion. It was my experience on busy servers that important gameplay messages could often get lost in chat because of other plugin messages and chat pushing them out of view. For the few important messages sent to individual clients I decided to add a short sound effect to draw attention to them and to act as a kind of feedback response to confirm a player's actions to them. In DTK I refined this into a set of chat message functions to make the implementation of messages easier for me and more consistant. These functions also control the prefix style attached to the message.

While playing Mikusch's deathrun plugin I was impressed at the fact the messages sent to clients were customised with their team colour. I felt this was a great way to communicate team states and actions to players. I also realised that the colours I provided in my own deathrun plugin could be misinterpreted as belonging to the blue team, so I have switched to a different colour scheme that cannot be confused with team colours. I have used a traffic light system where green indicates a message sent to only one client, yellow prefixed messages are sent to all players and red prefixes are admin or plugin messages that are rarely seen. I also expanded the prefix from 'DR' to 'Deathrun' because IMO a word is easier to 'read' at a glance than an abbreviation so time needed to mentally process messages should hopefully be reduced slightly for some people (like me).

I used to give player attributes by creating a trigger_add_or_remove_tf_player_attributes. This had some pros and cons:
+ It didn't need a third party library like TF2 Attributes.
+ Attributes given to players this way would disappear on death. Convenient!
- Each function call created a temporary edict, so doing this at round restart could crash the server.
- Attributes given this way could not be removed or modified later.
TF2 Attributes plugin is now required if you want to change player attributes.

### Version 0.285
* Added ConVar to toggle map instructions.
* Added a map instruction to remove a weapon from a specified slot.
* Added a map instruction to switch to a specified weapon slot.

* Fixed taunting players reversing a slot switch when they stop taunting.

* Changed the way players are restricted to the red team. [1]

[1] I used to use the cvar mp_humans_must_join_team and value 'red' to prevent players joining the blue team but this was ignored by bots and doesn't function in Open Fortress or TF2 Classic. Now, if a player tries to join the blue team and they're not an activator they will be put on the red team. The same goes for bots. This works two ways: 1. Intercepts the jointeam command from players and changes its argument from blue to red. 2. Hook the player_team event that fires when a player switches teams, reads the new team and responds appropriately.

### Version 0.284
* DTK now executes config_deathrun.cfg after all other configs have been executed.
* The server's game description is now changed back to Team Fortress on map end. [1]
* Improved the menu code by simplifying it, and adding the ability to use translated phrases.
* Put English language toggle in the Preferences menu.
* Added chat command lists to the menu. Admin commands are only shown to admins.
* Added the beginnings of the map control framework used by mappers to affect players. [2]
* Replaced TF2 Items dependency with my own code for replacing weapons. [3]
* Restricted the Scout's cleaver completely because it can be thrown through all kinds of walls.
* More things work when you manually enable the plugin on non-deathrun maps. WIP.
* The plugin now also changes logic_branches named deathrun_enabled to true. [4]
* Added an Admin 'fun stuff' menu where experimental actions will go.
* Created Jetpack Game and added it to the Admin fun stuff menu.

* Fixed players not receiving their attributes on spawn (double jump and so on).
* Fixed causing a melee-only mode check when changing any DTK cvar during a match.
* Fixed players being able to switch from melee weapons after spawning when melee-only mode is in effect.
* Fixed the plugin not getting enabled on VSH or Workshop maps.

[1] Previously, DTK would change the server's game description to Team Fortress when a new map started and it determined that it wasn't a deathrun map. The problem with this is that on multi-game mode servers, it's possible it could override another plugin's attempt to change the description. Now, the description will be changed whenever the plugin is enabled or disabled, which happens at the start and end of every deathrun map. I will move more actions under this ConVar change hook in future to make the plugin even work even better on  multi-game mode servers.

[2] Using a logic_case, the mapper can apply properties to the player such as class, move type and even give them weapons and set weapon attributes. The emphasis is on doing things that aren't possible when using map logic, but there are some convenience functions such as run speed and health. You simply have the player trigger the logic_case through ordinary means, sending the input FireUser1 and it will apply all of its properties to its activator. I will post detailed information soon.

[3] I was always under the impression that you needed to use something like the TF2 Items extension to create weapons and give them to players. I've since come to understand you can do this using standard SourceMod functions as long as you have the required data for the weapon and set the right properties. Screwdriver showed me some code made by nosoop that does what I need, so thank you both.

[4] Player property changes are something all deathrun plugins could do if they are simple, like a class change, weapon change, etc. It is better to create a system that all deathrun plugin authors can use, so for these kinds of changes I will use logic_cases named deathrun_properties. A logic_branch named deathrun_enabled can be used by the map to check if the server supports these property changes. Features like activator health scaling involve a series of changes that could be different depending on the plugin, so for now I will keep using a dtk prefix for that, and the mapper can use a dtk_enabled logic_branch to check for it.
I settled on deathrun_properties because it better represents mid-round player property changes, and deathrun_settings can be used to tell the plugin to change certain environment variables for the map to work, such as the number of activators, air acceleration and turbo physics.

### Version 0.283
* Added an admin command to change a player's class. [1]
* Increased array sizes to accommodate Source TV client.
* Changed the way attributes are given to players. [2]
* Made the plugin compatible with Open Fortress. [3]


[1] sm_setclass <target> [class]. Leave the class field blank for a random class. You only need to type the first three letters of a class name, e.g. 'hea' for Heavy. This command should be used in place of any other class change plugin you have because it also gives players the attributes they should have for their class to control speed, if DTK is configured to do that.

[2] I now give players attributes by creating a trigger_add_or_remove_tf_player_attributes entity. This means server operators don't need to install TF2 Attributes if they only want to change a player's run speed. DTK still needs that plugin to change the attributes on weapons, but I will look for other ways to do it (TF2 Items or some MvM logic). This change is better for server operators as there is less to configure and less that can go wrong, and good for me because I get more control over the duration of attributes and can pass the player through filters.

[3] DTK Base now works on Open Fortress. Most things work fine. I had to replace some TF2-specific functions with general functions. The plugin is now in a better position to be adapted to other Source mods.

### Version 0.282
* Made dependencies optional. [1]
* Added some events for Source Chat Relay (Discord relay). [2]

[1] SteamTools, TF2 Items and TF2 Attributes are now optional. You can run DTK Base without them loaded but some features won't work. SteamTools changes the server's game description, TF2 Items replaces and issues new weapons, and TF2 Attributes sets run speed and ability recharge rates.

[2] Another optional dependency is Source Chat Relay (SCR). If you have an SCR server set up to relay chat between your game servers and Discord servers, you can turn on event messages using `dtk_scr 1`. If you don't have the plugin installed, DTK won't use it. At the moment I am only communicating round start, round end and activator selection.

### Version 0.281
* Changed the welcome message to be a bit more informative.
* Blast pushing cvar settings 0 and 1 are now the right way around.
* Removed the message in chat saying there aren't enough players to start.
* /drhelp to list commands.
* Added a hide timer to the activator health bar.
* Added some protection against late loading and unloading. [1]
* Added health scaling functions for mappers. [2]

[1] Previously when the plugin was reloaded, it lost all the data in its player data array, so when a client left the server their preferences and points would be overwritten with zeroes. Now, if the plugin is unloaded and players are present it saves all their data to the database. When it's loaded late and players are present, they are given default values and if a record exists for them it is retrieved.

[2] Trigger a logic_relay named either dtk_health_scalemax or -scaleoverheal and the activator will have their health scaled up with the number of live enemies. Scalemax increases their maximum health pool allowing them to pick up health kits, and the value of health kits is scaled down to match their standard class amount. Scaleoverheal just overheals them. They can't pick up health kits in this state and their overheal will decay over time. Personally I recommend scalemax as it allows the activator to deny health kits, making the game interesting. It also uses the boss health bar properly, whereas when the activator is overhealed the boss health bar is always at 100% when above their max health, and the overheal is displayed in numerical form in a text element which isn't as attractive or as intuitive.
Backstab damage is capped on the activator at 300. This is to prevent instant kills when their health is scaled, but will (in most cases) still kill them if their health has not been scaled. 300 is a significant chunk of health which still feels rewarding for enemy spies and alarming for the activator. I chose a flat amount because it is consistent with a player's expectations.

### Version 0.28
* Put plugin debug messages behind a cvar (dtk_debug).
* Spectators should no longer be shown in the 'Next Activators' message.
* The health bar now has an 'overheal' text element. [1]
* Boss health bar now correctly shows the current health.
* Team mate pushing 'remaining' is reevaluated if an admin changes the cvar value.
* Removed anything that affects a player's 'glow' outline. [2]
* Welcome message now appears the moment the new player chooses a class. [3]
* The number of old records pruned from the database is now logged.
* Switched to using a method map for most player and database functions.
* Changed the way users' values are set up and carried across maps. [4]
* This fixed a bug where players could inherit preferences from a previous player.
* /english has been moved to permanent preference storage.

[1] If the activator is overhealed the boss health bar will be 100% and the additional health will be displayed in text underneath. This is a much simpler solution for me than trying to remember the player's highest health value and using that instead of their max health value. Let me know what you think.

[2] Why did I even add glowing to begin with? Because Deathrun Redux did? Why did those authors do it? Probably because while playing as the activator in some maps it's hard to keep track of rushers. But that's not something we should concern ourselves with if we can help it. One of my design philosophies for DTK has been to try and avoid doing anything that the mapper can do themselves using logic and entities in Hammer. If the mapper wants to add a glow, they can do that using tf_glow. If the mapper wants to make a game that depends on the red team hiding from the blue player, a glowing outline is going to ruin that. Instead of building a system that lets mappers turn the glow off I asked myself if it was really worth adding the glow in the first place, and when I think about all the maps I have played, there have not been many times when a glow was necessary. As a member of a community of deathrun mappers, it would be wrong for me to ignore the weaknesses in someone's map and rely on a crutch.

[3] Previously the welcome message appeared thirty seconds after a player joined the server. Now it appears the first time they choose a class. I am considering repeating the message on every new map to remind the player of the existence of the menu system.

[4] When a map changes, every player is disconnected and reconnected to the server. They keep the same client index (between 1-24 or 32 on servers with expanded maxplayers) and User ID (a unique number given to them by the server, which you can see if you use the 'status' command in console). I store player data in an array (like a table) using their client index as a key. Some of that data is meant to last for the length of a player's session on a server (for example, if the player has been welcomed), so it shouldn't be reset when the player disconnects or connects.

There are two ways to detect when a player joins the server: 1. Hook the player_connect game event, which only fires the first time the player connects and not when the server changes map. 2. Use SourceMod's built-in forward functions OnClentAuthorized and OnClientDisconnected, which unfortunately also fire when the map changes.

Because I wanted to store data about a player for the length of their server session, I set up their array values by hooking the player_connect event. The problem with this is it fires quite early, before the client actually receives a client index. Instead the game gives you their client index number *-1* (minus one). Previously I was just adding 1 to this value to get the eventual client index, but it didn't seem very safe. What if the number was wrong? I could overwrite another player's data!

For this reason, and because I had a bug where a player could sometimes inherit the preferences of a previous player, I am now using SourceMod's functions but am also storing their User ID. When the player reconnects after a map change, if their User ID is the same as the one in the array their data is not touched in any way. If the User ID is different, the player must also be different so the data in the array for that client index is reset to defaults and the plugin checks if the player has a database record. This is much more robust than using player_connect and simplifies things a bit.

### Version 0.27
* Updated the localisation files (translation file!).
* New cvar to disable the round start message (dtk_roundstartmessages).
* Addressed a bug where players were not being distributed to blue on map start.
* Addressed a bug caused when trying to switch to the primary weapon and not finding a weapon in the slot. [1]
* The 'Next Activators' message won't be shown if there aren't enough willing activators.
* Implemented a work in progress health bar for the activator that shows up when they are damaged. [2]
* Set the game description when SteamTools has loaded, to stop the first map of a server session not having the right description.
* Added the plugin version to the game description.
* Set the value of a logic_branch named 'dtk_enabled' to true on round start [3].
* Work in progress English language preference command /english. [4]
* New debugging command /drdata outputs the points and preferences for all clients in your console. [5]
* Two new cvars to control the 'enabled' state of the plugin. [6]
* Chat kill feed now filters out causes beginning with 'w' (worldspawn, i.e. fall damage). [7]
* Stopped using a coloured chat include because it seemed to cause translation errors.
* Health bar for boss logic. [8]
* If players respawn and there are enough, team pushing will be disabled again.
* Attempted a fix for spies disguised as you causing a kill feed chat message for you when they 'die'.
* New cvar for controlling Thermal Thruster charges and recharge rate. [9]
:small_red_triangle_down: Known issue: `mp_forceautoteam` should not be set to 1 for now. [10]

[1] I'm not sure why the plugin can't find a weapon in the primary slot sometimes. The check happens after a player is given their inventory, so it should find the weapon. It's possible some weapons in the primary slot don't require an entity, so I have added a check to see if a weapon is found. If it's not, the plugin will just abandon the attempt to switch weapons and will add to the error log. Hopefully I'll find out what's causing this in future.

[2] The health bar is the same one you see when Merasmus or Monoculus appears. It starts hidden but shows up when the activator takes damage from the world or from another player. It hides when they die or leave the server, and when the round restarts. I implemented it this way so it works automatically and retroactively with existing maps that have a fight feature, but if the activator gets damaged somehow earlier in the round on their own the bar will stay on screen until the round is over. In future I will add a timer to hide it.

[3] The plugin will look for a logic_branch named 'dtk_enabled' on each round, and set it to true. Mappers can use this as a sort of if statement to run different logic depending on whether DTK is being used by the server or not. In the future, DTK will have functions to do things that aren't possible using map logic, such as changing a player's class and weapons. You could use this logic_branch to restrict access to certain events that require these functions on servers not running DTK. In future it may be necessary to check the plugin's version number as well but I expect its feature set and functions to grow with your requirements, so if you have any special requirements please speak to me about them.

[4] /english changes your SourceMod language to English. Using it again changes your SM language to your client language. At the moment this option only lasts for the session so will reset if you leave. We have German and Turkish translations so if your client language is either of those and you normally see DTK phrases in them please test this command and tell me the results. Let me know if this is a good addition or needs some improvement.

[5] /drdata is an admin command which spits out the contents of the player data arrays to your client console. These arrays are like tables which store player points and preferences like activator, points and forced English language. I made this command to check that player flags were correctly being set, retrieved and stored when players join, leave and transition between maps. You might find it useful for debugging and seeing at-a-glance which preferences people on the server have set. It uses bit flags (a binary digit stands for an on or off state).

[6] When the plugin reads the map filename and finds a recognised deathrun prefix it enables its functions. That has been the case since it became a standalone deathrun plugin. At the moment, the plugin needs to be enabled before any players connect to the server or their initial preferences and points won't be set correctly or pulled from the database. In future I will ensure the plugin can be loaded or enabled mid-way through a map session and will function normally, so I am laying some groundwork by adding a cvar to enable or disable it (dtk_enabled). On top of that, it occurred to me that some server operators might not want my plugin to take over the moment it detects a deathrun map, in case they run a different plugin for certain maps. For those people I have created a second cvar to disable automatic enabling (dtk_autoenable).

[7] As far as I know, 'worldspawn' is the only entity classname beginning with a 'w' that can cause death. Rather than match the whole string I am just checking the first character, which is simpler. If you know of any entity beginning with 'w' that can kill players feel free to let me know. Aside from that, keep an eye out for chat kill feed messages that don't sound right, like "You were killed by a rotating."

[8] Add a math_counter to the map named named 'dtk_health'. During the round, set its value and a health bar will appear on screen. The health bar uses the min value and max value of the math_counter as its minimum and maximum bounds when calculating progress. When it reaches 0, it will hide. Changing the counter's value will update the health bar. If its min and max have been changed, those changes will be reflected in the progress when it is updated. You can alter the bar's colour by sending it FireUser1 for blue (default) and FireUser2 for green. The health bar uses the entity 'monster_resource' which persists through rounds so you may need to reset its value and colour at round restart.

[9] dtk_thermalthruster values: 0 = No charges, 1 = Normal charge behaviour, 2 = Charges take one minute to recharge, 3 = Two charges with no recharging. Like with all the other weapon and ability modifications, if testing shows they should be different I will tweak them. The charge rate is controlled by applying the attribute item_meter_charge_rate to the weapon after the player's inventory is applied.

[10] If using `mp_forceautoteam 1` to force players onto a team when they join the server to prevent them from late spawning, you will bypass the cvar that DTK uses to prevent players joining the blue team. This will cause there to be more than one player on blue until the round resets. It's not a problem unless people join during the pre-round freeze time prior to a round starting, as anyone who joins blue while the round is active will be dead. You might want to disable this cvar for now until DTK has a better way of blocking blue joins and late spawning.

### Version 0.26
* New cvar to restrict engineer buildings (dtk_buildings).
* Streamlining of database values and player flags.
* Added basic weapon replacement functionality.
* Force switch to primary on receiving weapons if melee mode is not enabled.

The engineer building restriction cvar uses one value to restrict any combination of buildings. Add up the values to get your convar value:
Sentry = 1
Dispenser = 2
Teleporter Entrance = 4
Teleporter Exit = 8
For example, to block a teleporter entrance, set the value to 4. To also block sentries, sum 4 and 1 to get 5. It's like spawnflags in Hammer.
By default only teleporters are disallowed. This stops engineers from escaping mini games and traps and still lets them be helpful to their team.

I used to store the Steam ID of a player in its SteamID2 format of STEAM_0:0:523696, and the last-used name of the player. Both of these columns were text values, which use up more space in a database than simple byte-based integer values. I didn't need the player's name, I was just using it while testing the database. Now I have dropped that column and am using the base account ID of the SteamID3 auth format, which is just numbers. e.g. 1047392. It's smaller and faster to index. I also removed some bit flags for conditions which don't need to be recorded in the database because they don't need to be saved (such as 'connected' which is a bit silly because they are not) or aren't used.

When the plugin detects an engineer receiving the Eureka Effect, depending on a cvar setting it will intervene and change it to a standard wrench. This functionality uses the TF2 Items extension. I looked into weapon replacements without the use of the extension but what I found suggested I would need to provide a separate game data file with the plugin and update it if a Valve update made it necessary. I felt it was better to use the extension because it's used by other plugins so likely already exists on the server (DRR and VSH use it), and if new game data is needed there will be many people who will be able and eager to provide it. The Eureka Effect is the only weapon that's restricted at the moment because it can be used to escape traps and games. Going forward I think it would better to remove its teleport attribute but I had to start somewhere.

The change to switching players to primary when melee mode is not enabled for them comes from wanting to remind the activator they can use normal, non-melee weapons to activate traps. If the player was playing on the red team previously and melee only mode was enabled, they will still have their melee weapon equipped when they spawn on blue so they may not realise they can change.

### Version 0.25
* Included a coloured text native library and set up some nice text colours.
* Added a welcome message that informs new clients of the existence of the menu.
* Fixed a bug where clients who had chosen not to be activator were still being chosen because they had enough points.
* Player preferences are now stored in a bit flag array instead of an integer array.
* Changed the sm\_pref command to sm\_prefs. It shows usage info when the argument is "?" and outputs your preference flags to console.
* Changed the sm\_giveqp command to sm\_award.
* Players with a negative points value are no longer able to reset their points.
* The plugin now uses a database to store player points and preferences.
* Added the admin command sm\_resetdatabase to delete the plugin's table from the database.
* Added the admin command sm\_resetuser to delete a player's entry from the database.
* Added quick and dirty blast pushing control. Disable, reduce or allow in full.
* Changed cvars from sm\_dt\_ to dtk\_

Changing from an integer array to a bit flag array will only save a small amount of memory, but it makes things easier for me in the future, allowing me to add new settings without having to make many modifications, such as an option for admins to prevent a player from being the activator, and expanded personal preferences.

Switching to using a database to store points and preferences means they will be saved when the client leaves the server and restored when they come back later. The plugin uses SourceMod's default SQLite database, 'sourcemod-local' and creates a table in it called 'dtk_players'. Each time the map loads the plugin queries the database and deletes any records where the player's last recorded session is over a month ago. The new admin commands require the admin to have permission to either set convars, execute configs or use rcon. This change paves the way to the creation of a separate queue point plugin allowing a player to accrue points in one game mode and use them in another, such as Jailbreak.

I realised admins can award players negative points. Rather than fixing it I decided to harness and use it as a way for admins to temporarily prevent players from being the activator, delaying them based on the number of rounds they must play to get back to a positive figure. Players with a negative number of points won't be able to reset them. What do you think of this?

Blast pushing is something I would like to keep for fun, but only in a reduced form on maps where it can be used to easily escape traps. The amount of movement seems to relate to the amount of damage taken by a weapon imparting a blast force. For the time being, depending on the cvar value and for red soldiers and demomen, either the self-damage is discarded, reduced or allowed in full. Reducing it appears to work well for soldiers but demomen can still travel a very large distance using multiple stickies, as they each seem to be separate damage events rather than one big one. Getting it right requires tailoring the modifications for each weapon, but for now I will see what play testing shows me.

  [Name]                           [Value]
  dtk_activators                   1
  dtk_blastpushing                 2
  dtk_bluespeed                    420
  dtk_chatkillfeed                 1
  dtk_preventblueescape            1
  dtk_reddemocharge                2
  dtk_redglow                      0
  dtk_redglow_remaining            3
  dtk_redmeleeonly                 0
  dtk_redscoutdoublejump           0
  dtk_redscoutspeed                320
  dtk_redspeed                     0
  dtk_redspycloak                  2
  dtk_teampush                     0
  dtk_teampush_remaining           5
  dtk_usepoints                    1
  dtk_usesql                       1
  dtk_version                      0.25

### Version 0.24
* Queue point grants by admins are now shown in chat to other admins and logged.
* Changed some definitions to enumerations because they look prettier.
* Added a menu system to handle preferences and viewing and resetting points.
* At the end of the round, up to the next three eligible activators are displayed in chat.
* Players who opt out of being activator will no longer receive a message at the end of the round telling them they received 0 points.
* New kill feed option which tells players what entity and targetname killed them. sm_dt_chatkillfeed.

### Version 0.23
* New cvar: sm_dt_teampush_remaining [5]
	Controls when the plugin will activate team pushing based on the number of players alive. 0 is off.
* New cvars: sm_dt_redglow [0], sm_dt_redglow_remaining [3]
	Enable red team glow, or enable it when there are a specified number of reds remaining.
	Currently a little bit buggy.
	Note that the glow will disappear and return when a spy cloaks and decloaks!
* New cvar: sm_dt_redmeleeonly [0]
	Gives the client the 'no switch from melee' condition and makes them switch to melee, when spawned.
	Then deletes all their other weapons to save those sexy server edicts.
* New command: sm_pref 0/1/2
	Choose whether you would like to receive no points, half points or maximum points.
	Choosing no points also opts you out of being activator. If there aren't enough willing activators at the start of a round, the plugin will revert to a turn-based system.

### Version 0.22
* Added a points-based queue system and commands to show and reset points (see more).
* Fixed the bug caused by replacing an escaping activator during freeze time (see more).

Queue points: The queue points system is a better way for players to understand how near they are to becoming the activator and it gives them some control over their turn. At the moment there is no scoreboard and no way to see how many points other players have. There are commands to request your points total and to reset it to 0, and an admin command to award points to a player. Clients connecting for the first time are awarded ten points. This is sort of a fudge to make the sorting and selection system work a bit more nicely, and acts as a buffer to give players time to reset their points each round if they don't want to be the activator.

The bug: The activator can switch teams during the freeze time before the round is active. Previously the plugin replaced them so soon that it caused the reported number of red players to go up by one, and I think that was responsible for a server crash when the map ended. Now, the replacement player is requested to be switched on the next game frame. It seems to have solved the problem.

### Version 0.21
* Made players swap teams silently. No more death screams and dropped items.
* New player swapping logic replaces activators who leave or switch in freeze time.

### Version 0.2 - Limited Public Testing
* Basic team swapper using a turn-based system.
* Attributes set for demo charging and spy cloak, cvar. (see more)
* Cvar for controlling team mate pushing.
* Detects presence or lack of tf_logic_arena and sets minimum players needed. (see more)
* Adjusts mp_enableroundwaittime when there's no tf_logic_arena to match Arena prep time. (see more)
* Supports translation files and has Turkish phrases.
* Cycles through the round start messages found in the translation file.
* Red players can't join blue (uses a game cvar).

### Version 0.1
* Attributes for runner, activator and red scout run speeds, cvars (see more).
* Red scout (only) double jump attribute, cvar.
* Support for multiple activators, cvar (see more).
* Prevent the activator from suiciding or switching teams (see more).
* Recognises Workshop maps.

## Design Brief
Player and weapon attributes and restrictions:

Since the inception of the game mode in TF2, server environments have become more and more restrictive of weapons and player abilities in order to stop weaknesses in maps from being exploited. A blanket approach of removing any movement or health-altering item, and making all classes the same does provide a level playing field but limits what a map author can do. As a result of playing on servers with these restrictions, new map authors only design their maps with platform distances that can only be jumped by classes running at a minimum speed of 300u/s (pyro), and interactive elements that can only be punched instead of being shot. There is no reason to choose any particular class other than what character model and noises you like and what cosmetic you have. The innate class abilities and balance of TF2 are lost. Their strength actually lies in their limitations because a player can only fulfill one or two roles at a time and so team play is necessary, instead of making every class the same which encourages solo play and strips potential for rewarding cooperation.

In fear of the game mode becoming stale and full of unoriginal maps, I am envisaging a future where primary weapons and special abilities can have a purpose, where class choice is meaningful, where players must weigh up pros and cons and are presented with more options instead of fewer, and get more replay value and satisfaction from their achievements. For example, Heavy runs slower than all other classes, so his jump distance and agility is reduced. But he has more health, so he can take more damage than everyone else. Maps could design for class differences such as these by, for example, creating traps that, rather than just killing players instantly, instead cause damage. In those cases, Heavy's pros and cons are balanced. The higher-health Heavy can act as a damage sponge for the team, soaking up the occasional blast or laser to make the way safe. To balance this advantage, the player controlling the Heavy needs to be much more precise when jumping.

Some more examples of player abilities that could be useful in deathrun when helping team mates:
Pyro can withstand afterburn so he could run through a burning room to switch on a fire sprinkler system.
Sniper could shoot a distant set of buttons.
Spy could sap buildings and make the way safe for the team.
Soldier could rocket jump up a wall to turn off a sentry search light.
Engineer could build a dispenser to keep the team alive in a room full of poison gas.
A few class aspects and capabilities overlap with those of other classes, so players and mappers shouldn't feel forced to either only use one class or designed for all nine. If we simplify and categorise things like enhanced movement and damage reduction we can begin to create some design guidelines to make mapping easier.

Deathrun Redux alters player speed and empties the spy cloak meter by setting the maximum speed, and a cloak meter value of 0.0, on every game frame. That was probably a clever solution when the plugin was first developed but it has some drawbacks. Anything which modifies player run speed, such as a trigger_stun, Disciplinary Action condition, spinning up a minigun or charging, would be overriden. Today we can modify speed using TF2 attributes, so any modification to player speed will be kept. This lets us allow demoman charging and spy cloaking in some form and introduce them as additional tools in avoiding death. Charging through a trap could be problematic on maps with cheap traps with no obstacles, but on maps like Steamworks Extreme and Neonoir charging could get you killed, so we include a cvar to either disable, modify or leave such abilities untouched.

### No tf_logic_arena
Deathrun maps traditionally use a tf_logic_arena to force arena mode because it is convenient and fits the game mode. Players can only live once, and when all players on a team are dead a victor is declared. But Arena comes with its own limitations. For one, you need to have at least one player on each team to start a round. Another is you may not want to prevent players respawning completely or have the round automatically finish when everyone is dead. What if you wanted to let players play some mini games when they die, while waiting for the round to end, instead of being forced to spectate and do nothing for several minutes? What if you wanted to move dead red players to the blue team, like Zombie modes do? Or what if you wanted to make a map that has no activator? Steamworks Extreme and Neonoir have proven there is demand for automated maps, and from my experience building the former, it is a lot easier to make decent automated traps than it is to come up with ideas for manual traps that are fun and fair.

### mp_enableroundwaittime
mp_enableroundwaittime is the time before a round starts where you are frozen in place. During this time, you can change teams and will be respawned straight away. At the end of the period, the round start event is fired so the round is officially begun from a server logic perspective. In Arena you have ten seconds before the round begins but outside of that you only have five. To emulate the same length of time you can set this cvar to 2, which is a multiplier, so 2*5s is 10s.

### Support for multiple activators
While I don't expect this feature to be popular, it might be fun to occasionally have more than one activator, especially on larger servers where players won't get to be the activator for some time given that a map session lasts about ten rounds. It is probably dependent on the map as well. On maps with few useable traps there isn't enough for one player to do.

### Activator escape prevention
From what I have gathered from other deathrun players, it is annoying when an activator switches team or commits suicide in the middle of a round. It wastes everyone's time. I would prefer it if a player on blue actually tried to play properly but I can understand if they would rather be on red. But it's too easy to quit and it's tempting. By preventing the blue player from escaping we are more likely to have an uninterrupted round and players should feel more inclined to make use of any available deathrun options which keep them off the blue team.