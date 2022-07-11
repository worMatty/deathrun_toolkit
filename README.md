# Deathrun Toolkit

## About

Deathrun Toolkit is a set of plugins which run and support the Deathrun game mode in TF2, TF2 Classic and Open Fortress. The main plugin `dtk.smx` runs the game mode. The other plugins are optional extras which mitigate exploits and improve quality of life in older or flawed maps.

## Installation

### Quick

Upload **dtk.smx** to addons/sourcemod/plugins, and **dtk.phrases.txt** to addons/sourcemod/translations. The plugin will enable when it detects a deathrun map and disable when the map ends. It doesn't do anything if the map isn't a deathrun map.

Most modern deathrun maps support non-melee weapons, but if you're running an older map that has vulnerabilities that can be exploited using them, you can set the convar `dtk_red_melee` to `1` in tf/cfg/\<mapname\>.cfg. 

### Advanced

Install the weapon restriction files in addons/sourcemod/configs/dtk. Add weapons you wish to restrict to restrictions.cfg.

For TF2, install [TF2 Attributes](https://github.com/nosoop/tf2attributes), which enables the plugin to apply attributes to players and weapons in order to restrict or modify their abilities. Open Fortress and TF2 Classic do not support attributes, so you will need to investigate alternative methods of modifying player abilities and weapons.

Type `sm cvars dtk` or `find dtk_` in server console for a list of convars.
Type `sm cmds dtk` in server console for a list of commands.

If you only want to use DTK with specific deathrun maps, create a \<mapname\>.cfg file in tf/cfg containing `dtk_auto_enable 1`, and in server.cfg put `dtk_auto_enable 0`. If you use another deathrun plugin for all other maps, you will need to disable it in \<mapname\>.cfg and enable it server.cfg, so both plugins aren't running at the same time.

## Features

### Basic stuff

* Menu (`/dr`)
* Opting out of becoming the activator
* An ordered activator queue based on internal points and time last selected
* Boss health bar for activator's health
* Activator suicide/team-switching prevention (optionally also during pre-round time)
* Various language translations

### Cool stuff

* The map author can use logic entities to change a player's properties and give them weapons
* The map author can trigger activator health scaling when appropriate, e.g. in an arena or fight mini game
* Player speed modification does not override speed-altering map mechanics
* Support for multiple activators (not recommended)
* Support for Open Fortress and TF2 Classic
* Upon being enabled, executes _config_deathrun.cfg_ after all other config files
* Does not interfere with other game modes on multi-mode servers. Safe to be left loaded all the time

## Optional Toolkit Plugins

* **dtk_use** - Lets you +use buttons on old maps that only support damaging buttons to trigger them (QoL)
* **dtk_sacrifice** - Allows a runner to sacrifice themselves for a dead team mate
* **dtk_trains** - Disable user control of trains so players can't +use control them (anti-exploit)
* **dtk_damage_filter** - Filters damage types from one team to the other (anti-exploit)
* **ragdoll_effects** - Map authors can add special effects to ragdolls by giving trigger_hurts special damage type integers

* The third-party plugin [Source Chat Relay](https://forums.alliedmods.net/showthread.php?p=2617899) can be used to send round event and activator selection messages to a Discord channel
* The third-party extension [SteamTools](https://forums.alliedmods.net/showthread.php?t=236206) can be used to change the game server's description

## Design

### Current state and limitations

Weapon and ability restrictions are work-in-progress and as a result there are very few restrictions applied by the plugin by default.

Some convars and hard-coded things:
* `dtk_wip_enhanced_mobility` (default: 0) accepts a value of 0, 1 and 2. It currently controls Demoman charging. 0 disables it, 1 limits it, 2 allows it.
* `dtk_wip_extra_mobility` (default: 0) controls 'extra mobility', which currently negates any self-damage, disabling rocket/sticky jumping and similar.
* `dtk_wip_blue_boost` (default: 0) is an experimental feature which allows blue players to sprint by binding +speed, with a charge meter. Try it, it's fun!
* Spies can only cloak for a fraction of a second (on purpose)

The plugin is in beta. If you're after something that is more complete and has ready-made restrictions, I recommend [Deathrun Neu](https://github.com/Mikusch/deathrun) by Mikusch. Feel free to submit bug reports and feature requests for DTK to the issues page.

### Future

A decent enough weapon restriction system that uses several ready-to-use configs for maps that require varying tiers of mobility and weapon restrictions. e.g. Some maps need melee-only, some demand no special mobility, some can get away with small jump boosts or trimping.

Expansions to the map instructions feature to let mappers use the boss bar for a boss 'entity' using a math_counter. Options to display or track health of more than one target.

Possibly separating the map instructions system into a separate plugin so it can be used in other games modes and independently of this deathrun plugin.

### Information for map authors

Player aspects such as run speed and cloak level are modified by adding TF2 attributes, instead of having their properties set on every game frame like how Deathrun Redux does it. This method does not prevent the map from affecting a player's speed using things like stun triggers, pickups, boost pads etc. Nor does it prevent the use of movement-enhancing abilities.

DTK doesn't require that the map has a tf_logic_arena. Mappers are free to make maps that don't have Sudden Death as a core mechanic. They could for example have dead players respawn in a waiting area, or make a new variant of deathrun that revolves around having lives.

Activator selection and replacement is more robust than on Deathrun Redux. If an activator switches away from the blue team or leaves the server during freeze time, the next player in the queue takes their place immediately. The queue system is very solid and uses queue points and the server time to eliminate the chance of a player being chosen as activator twice in a row. The server operator can optionally disable team switching during pre-round freeze time using a convar.

Health scaling for the activator is handled a bit differently. By default the activator has the same amount of health as a normal player, but in combat mini games the map author can trigger health scaling using map logic. The health of the activator is then scaled up to a suitable figure based on the number of live red players. Their health pool is increased and contribution from health packs scaled down accordingly to keep it fair. 

### Map Instructions (give weapons, change class, print to chat, etc.)

DTK lets a mapper change player properties that are normally not accessible, such as player class, weapon attributes, replacement weapons and so on. It works using a logic_case with special values.

At the moment you can:
* Change a player's class
* Set their speedand move type
* Give them weapons, remove weapons, give a weapon attributes
* Set the player's health, max health and scale it up (if they're an activator)
* Send a message to their text chat
* Switch them to a specific weapon slot
* Force them to be melee-only
* Give them a custom model and make it use class animations

If you're interested in adding such functionality to your map, pay us a visit at our deathrun design community [Death Experiments](https://steamcommunity.com/groups/death_experiments) and ask us about it. 

### Philosophy and considerations (preaching)

#### Stuff I won't support

* Glowing outlines
* Disabling spy disguises (why? What is the harm?)
* Setting all classes to the same run speed *as supplied*
* Melee-only *as supplied*

While occasionally beneficial, forced glowing outlines on red players have consequences. They discourage the proper planning and building of the activator route because the mapper doesn't realise that visibility of the runners is important for an enjoyable activator experience. They also ruin hide and seek games, and purposely-dark environments. These are map design issues.

As a deathrun mapper I am *against* restrictions because I believe they are stifling the game mode. In order to improve and grow we should embrace class variety and make it a part of our design considerations to provide interesting new experiences.

I believe that in most cases, it is the responsibility of the mapper to account for class abilities though I accept it is much simpler to disable everything. My concern is that new mappers believe this is normal for deathrun so they design and build assuming the restrictions are always present.

If we make the plugin maker or the server operator the person responsible for dealing with map design flaws, the manner of dealing with them and the side effects vary from server to server, so map makers have no choice but to design for a very limited environment and avoid building things which may work on some servers but will cause problems on others.
