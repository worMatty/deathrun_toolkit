# Deathrun Toolkit
## About
Deathrun Toolkit is a set of plugins which run and support the Deathrun game mode in TF2, TF2 Classic and Open Fortress. The main plugin `dtk.smx` runs the game mode. The other plugins are optional extras which mitigate exploits and improve quality of life in older or flawed maps.

## Installation
### Quick
Add these two files:
* `addons/sourcemod/plugins/dtk.smx`
* `addons/sourcemod/translationsdtk.phrases.txt`
That's it! The plugin will enable itself when it detects a deathrun map and go to sleep when it's not one. Multi-gamemode servers rejoice. 

Most modern deathrun maps support non-melee weapons, but if you're running an older map that has vulnerabilities that can be exploited using them, you can create a map-specific config file in `/cfg/mapname.cfg` and add `dtk_red_melee 1`. Turn it off in `/cfg/server.cfg` so it doesn't affect all maps.

### Advanced
Install the weapon restriction files in `addons/sourcemod/configs/dtk`. Add weapons you wish to restrict to `restrictions.cfg`. There are instructions in the files.

For a list of console variables and commands, at the server console type `sm cvars dtk` and `sm cmds dtk`. Type any of them without an argument and their functions will be returned to you.

If you use [Source Chat Relay](https://forums.alliedmods.net/showthread.php?p=2617899), game mode events will be sent to your Discord channels. The [SteamWorks](https://forums.alliedmods.net/showthread.php?t=229556) extension will enable the plugin to change your server's game description.

## Features
* A menu for setting activator preferences, and adding activator bans
* Activator suicide/team-switching prevention (optionally also during pre-round time)
* Various language translations
* Support for Open Fortress and TF2 Classic
* Does not interfere with other game modes on multi-mode servers. Safe to be left loaded all the time
* Player speed modification does not override speed-altering map mechanics (hooray!)
* Support for multiple activators (not recommended)
* Upon being enabled, executes `/cfg/config_deathrun.cfg` after all other config files

## Optional Toolkit Plugins
* **dtk_use** - Lets you +use buttons on old maps that only support damaging buttons to trigger them (QoL)
* **dtk_sacrifice** - Allows a runner to sacrifice themselves for a dead team mate
* **dtk_trains** - Disable user control of trains so players can't +use control them (anti-exploit)
* **dtk_damage_filter** - Filters damage types from one team to the other (anti-exploit)

## Design
### Current state and limitations
Weapon and ability restrictions are work-in-progress and as a result there are very few restrictions applied by the plugin by default.

Some convars and hard-coded things:
* `dtk_wip_enhanced_mobility` currently controls Demoman charging and accepts a value between 0-1
* `dtk_wip_extra_mobility` 'extra mobility' currently negates self-damage, disabling rocket/sticky jumping and similar

The plugin is in beta. If you're after something that is more complete and has ready-made restrictions, I recommend [Deathrun Neu](https://github.com/Mikusch/deathrun) by Mikusch. Feel free to submit bug reports and feature requests for DTK to the issues page.

### Future
A decent enough weapon restriction system that uses several ready-to-use configs for maps that require varying tiers of mobility and weapon restrictions. e.g. Some maps need melee-only, some demand no special mobility, some can get away with small jump boosts or trimping.

### Information for map authors
Speed-altering effects like stun triggers, conditions, attributes, buffs and so on work normally.

**tf_logic_arena is not required**. You are free to make maps that don't have Sudden Death as a core mechanic. They could for example have dead players respawn in a waiting area, or make a new variant of deathrun that revolves around having lives. You must handle what happens to players when they die, and what causes a team victory. Activator selection is triggered by a round restart.

There is **no health scaling in this plugin**. While convenient, plugin-forced health scaling varies between servers and interfers with map mechanics. Today, it's very easy to scale health yourself using VScript.

If you're interested in making deathrun maps and want help, visit the [Death Experiments Discord](http://deathrun.tf). We have ready-made scripts for things like health-scaling and the boss bar.

### Philosophy and considerations (preaching)
#### Stuff I won't support
* Glowing outlines ruin hide and seek, hiding in shadows and are a crutch for bad design
* Disabling spy disguises (why? What is the harm?)
* Setting all classes to the same run speed *as supplied*
* Melee-only *as supplied*

As a deathrun mapper I am against excessive restrictions because I believe they limit the possibilities. Class variety too is not something that should be homogenised but embraced to provide players with choices and different ways to play.

I believe that in most cases, it is the responsibility of the mapper to account for class abilities though I accept it is much simpler to disable everything. With a bit of thought it's not hard to counter most things. My concern is that new mappers believe this is normal for deathrun so they design and build assuming the restrictions are always present and no not dare to experiment or imagine what more could be done.

If we make the plugin maker or the server operator the person responsible for dealing with map design flaws, the manner of dealing with them and the side effects vary from server to server, so map makers have no choice but to design for a very limited environment and avoid building things which may work on some servers but will cause problems on others.