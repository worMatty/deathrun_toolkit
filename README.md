# Deathrun Toolkit
Deathrun Toolkit is a set of plugins which run and support the Deathrun game mode in the videogame Team Fortress 2. The main plugin `dtk.smx` runs the game mode. The other plugins are optional extras which mitigate exploits and improve quality of life in older or flawed maps.

## Installation
### Dependencies
#### Mandatory
* Metamod:Source and SourceMod
#### Optional
* [SteamWorks](https://forums.alliedmods.net/showthread.php?t=229556) extension for changing the server's game description
* [Source Chat Relay](https://forums.alliedmods.net/showthread.php?p=2617899) for printing deathrun game mode information to Discord channels
* TF2Items is used for providing replacement weapons if present but the plugin will work fine without it
### Quick Setup
Upload these two files to your server's SourceMod installation
* `addons/sourcemod/plugins/dtk.smx`
* `addons/sourcemod/translations/dtk.phrases.txt`

That's all you need to do to get started. The plugin will enable itself when it detects a map with a `dr_` prefix and disable itself on map end.
#### Melee Weapon Restrictions
Most modern deathrun maps can function perfectly fine with primary and secondary weapons allowed and only require a small number of sensible restrictions such as disabling blast-jumping. The plugin comes with a ready-made restrictions config file to do this for you. Read the next installation section for information.

It is an outdated practice to restrict all players to melee weapons. However if you need to do this for some reason, you can set the console variables `dtk_red_melee` and `dtk_blue_melee` to `1`.

The best practice would be to do this on a per-map basis so you don't needlessly limit all of your maps. Add any console variables you want to change for the map to `cfg/mapname.cfg`, and put the default values in `cfg/server.cfg` so they are reset when the map changes.

### Advanced
The plugin comes with a ready-made item restriction config file which is used in modifying, removing or replacing any items which defeat the gamemode or can be used to cause a nuisance. Install the files contained in `addons/sourcemod/configs/dtk` and the plugin will do the rest. If you wish to add your own restrictions, you can find instructions in `restrictions.cfg`.

For a list of the plugin's console variables and commands, at the server console type `sm cvars dtk` and `sm cmds dtk`. Type any of the listed items in the console without any arguments and a description of their functions will be printed.

## Features
* Menu for preferences and banning players from becoming Activator (`/dr`)
* Activator suicide, self-damage and team-switching prevention
* Multiple language translations
* Only enables itself on deathrun maps so can be left loaded on multi-mode servers
* Player speed modification does not override speed-altering map mechanics
* Upon being enabled, executes `cfg/config_deathrun.cfg` after all other config files

## Optional Toolkit Plugins
* **dtk_use** - Lets you +use buttons on old maps that only support damaging buttons to trigger them (QoL)
* **dtk_sacrifice** - Allows a runner to sacrifice themselves for a dead team mate
* **dtk_trains** - Disable user control of trains so players can't +use control them (anti-exploit)
* **dtk_damage_filter** - Filters damage types from one team to the other (anti-exploit)
* **dtk_outlines** - Enables the server operator to display glowing outlines on players

## Design Information
I'm not a software developer by trade so I'm reluctant to 'release' the plugin as version 1. It is however essentially fully-functional. If you experience issues or have feature requests, please open an issue on this repository's tracker.
If you require a more advanced item restriction system, then I suggest [Deathrun Neu](https://github.com/Mikusch/deathrun) by Mikusch.

### Information for Map Authors
**tf_logic_arena is not required**. You are free to make maps that don't have Sudden Death as a core mechanic. They could for example have dead players respawn in a waiting area, or make a new variant of deathrun that revolves around having lives. You must handle what happens to players when they die, and what causes a team victory. Activator selection is triggered by a round restart.

There is **no health scaling in this plugin**. While convenient, plugin health scaling varies in the amount and manner granted between server communities, which can interfere with the map's smooth running and make the experience inconsistent. Today, it's very easy to scale health yourself using VScript. Indeed that should be what you do from now on. I have created VScripts for this and for the Merasmus Boss Bar. Come and speak with me on Discord at [Death Experiments](http://deathrun.tf).

### Philosophy and Approach
#### Things I will not support
* Glowing outlines. They ruin hide and seek games and hiding in shadows. They are a server-side patch for bad map design. We test deathrun maps without them and any lighting or vision issues become apparent during tests, and are (usually) fixed before release.
* Disabling spy disguises. I see no harm in them as there is only one Activator and they are on the other side of a wall. You can remove the disguise PDA if you wish, using the restriction system.
* Setting all classes to the same run speed as supplied. Variety of class abilities, strengths and weaknesses is good for the game mode. Players are required to choose their loadout with some thought. While a Heavy may find it harder to jump, their increased health pool lets them survive more damage and their minigun gives them an edge in combat games. You can set a flat run speed if you wish using the console variables. A pyro runs at 300 u/s and a scout at 400 u/s.
* Melee-only as supplied for the same reason. Restricting all players to melee may have been the best solution a decade ago but today's maps are more resilient to exploits and have more interactive features where projectile weapons can play a role.

As a deathrun mapper I am against excessive and redundant restrictions because they limit what we can create. Class variety too is not something that should be homogenised but embraced to provide players with choices and different ways to play.

It is the responsibility of the mapper to account for class abilities to a reasonable degree though I understand why it is much simpler to disable everything. I run a deathrun mapper community and we are very good at catching problems in our playtests. With a bit of thought during the design phase or some well-placed brushes, it's not challenging to counter the most common potential exploits. New map-makers tend to produce mechanics they are already familiar with, because they don't yet have the confidence, skill or experience to create new experiences which push boundaries. If the boundaries are already pushed back, then naturally they will produce more varied work. Originality and innovation help keep the game mode going.

As history has shown, if the responsibility of dealing with map flaws falls to plugin makers and server operators, the manner of dealing with them and the side effects inevitably vary from server to server. The landscape becomes varied in its restrictions and quirks, so faced with the possibility of their map not being playable on one or more communities, map-makers feel obliged to design for the narrow overlap and cut out unique and original concepts.
