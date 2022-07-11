# Deathrun Toolkit

## What is Deathrun?

What is deathrun?! Have you been living under a rock? It's a game mode where the majority of players are put on the red team and their task is to navigate through a hazard course and reach the end. One or more players are put on the blue team, and their task is to trigger the traps in the course to try and kill the red players. When a red player dies they don't respawn. If a red player reaches the end, their team wins, but if all the reds die, the blue team wins.

## What is Deathrun Toolkit?

It's a set of plugins for TF2, TF2 Classic and Open Fortress game servers which handle the running of the deathrun game mode and optionally fix exploits and make quality of life improvements in older or flawed maps.

## Installation

### Minimal

Place dtk.smx in addons/sourcemod/plugins, and dtk.phrases.txt in addons/sourcemod/translations. You do not need to configure the plugin, as it will automatically enable itself when it detects a deathrun map and disable itself when it ends.

### Advanced

Install the weapon restriction files in addons/sourcemod/configs/dtk. Add weapons you wish to restrict to restrictions.cfg.
For TF2, install [TF2 Attributes]([https://forums.alliedmods.net/showthread.php?t=210221](https://github.com/nosoop/tf2attributes) to enable the plugin to apply attributes to players and weapons to restrict or modify their abilities. This is necessary for a *lot* of maps to prevent players skipping traps. Unfortunately there's no way I know of currently to modify player attributes or aspects in TF2 Classic and Open Fortress, so you will need to seek alternative methods of limiting their abilities.

You can get a list of plugin cvars by typing `sm cvars dtk` or `find dtk` in server console.
If you only want to use DTK for certain deathrun maps, create a .cfg file in your game server's cfgs dir with the same name as the map. Put `dtk_auto_enable 0` in server.cfg and `dtk_auto_enable 1` in your map config. If you use another deathrun plugin you will need to disable it in your map config and enable it in server.cfg so both plugins aren't running the game mode at the same time.

### Optional Items

* dtk_use - Lets you +use buttons on old maps that only support damaging buttons to trigger them
* dtk_sacrifice - Allows a runner to sacrifice themselves for a dead team mate
* dtk_trains - Disable user control of trains so players can't +use control them
* dtk_damage_filter - Filters damage types from one team to the other for maps where teams can attack each other
* ragdoll_effects - Mappers can do special effects on ragdolls by giving trigger_hurts special damage type integers

* The third-party plugin [Source Chat Relay](https://forums.alliedmods.net/showthread.php?p=2617899) can be used to send informative messages to a Discord channel
* The third-party extension [SteamTools](https://forums.alliedmods.net/showthread.php?t=236206) can be used to change your game server's description

## Features

The plugin has all the bells and whistles you would expect from a typical deathrun plugin such as player preferences, a menu, an activator queue and so on, but here are some things which set it aside from others.

### Cool Things

* Activator health is shown via the use of the boss health bar during combat
* Mappers can use logic to change a player's properties or give them weapons
* Mappers can use logic to trigger activator health scaling when appropriate, e.g. in an arena or fight mini game
* The plugin doesn't do anything to players that interferes with the workings of a map such as negate fall damage, grant resistances or force speeds

### Not As Cool Things

* The plugin prints what killed you in chat
* The activator can be prevented from suiciding or switching teams
* There are translations of plugin phrases to a handful of languages
* It doesn't use on-screen text often so it's unlikely to interfere with map text

### Server Operator Stuff

* Auto enables and disables on deathrun map start and end
* Doesn't interfere with other game modes on multi-mode servers
* TF2 Workshop maps are properly detected
* Support for multiple activators
* Support for Open Fortress and TF2 Classic
* If enabled, executes config_deathrun.cfg after all other config files

## Note About The Current State

Weapon and ability restrictions are work in progress and as a result there are very few restrictions applied by the plugin. All self-damage is negated, which means players can't blast jump. Spies can only cloak for a fraction of a second. Scouts can't double jump but they can use the Force-a-Nature by design as it requires skill. Some player ability adjustments only work in TF2.

Blanket run speed and melee-only are not enabled by default but there are cvars you can add to your config files if projectile weapons or slower classes are a problem in some maps.

## Design Philosophy and Important Differences

#### Stuff I won't support

* Glowing outlines
* Disabling spy disguises (why? What is the harm?)
* Setting all classes to the same run speed *as supplied*
* Melee-only *as supplied*

While occasionally beneficial, forced glowing outlines on red players have consequences. They discourage the proper planning and building of the activator route because the mapper doesn't realise that visibility of the runners is important for an enjoyable activator experience. They also ruin hide and seek games, and purposely-dark environments. They are the equivalent to wall hack cheats in first-person shooters.

As a deathrun mapper I am *against* restrictions because I believe they are stifling the game mode. In order to improve and grow we should embrace class variety and make it a part of our design considerations to provide interesting new experiences.

I believe that in most cases, it is the responsibility of the mapper to account for class abilities though I accept it is much simpler to disable everything. My concern is that new mappers believe this is normal for deathrun so they design and build assuming the restrictions are always present.

If we make the plugin maker or the server operator the person responsible for dealing with map design flaws, the manner of dealing with them and the side effects vary from server to server, so map makers have no choice but to design for a very limited environment and avoid buildings things which may work on some servers but will cause problems on others.

## Detailed Technical Things for Studs

Player aspects such as run speed and cloak level are modified by adding TF2 attributes, instead of having their properties set on every game frame like how Deathrun Redux does it. This method does not prevent the map from affecting a player's speed using things like stun triggers, pickups, boost pads etc. Nor does it prevent the use of movement-enhancing abilities.

DTK doesn't require that the map has a tf_logic_arena. Mappers are free to make maps that don't have Sudden Death as a core mechanic. They could for example have dead players respawn in a waiting area, or make a new variant of deathrun that revolves around having lives.

Activator selection and replacement is more robust than on Deathrun Redux. If an activator switches away from the blue team or leaves the server during freeze time, the next player in the queue takes their place immediately. The queue system is very solid and uses queue points and the server time to eliminate the chance of a player being chosen as activator twice in a row. The server operator can optionally disable team switching during pre-round freeze time using a cvar.

Health scaling for the activator is handled a bit differently. By default the activator has the same amount of health as a normal player, but in combat mini games the map author can trigger health scaling using map logic. The health of the activator is then scaled up to a suitable figure based on the number of live red players. Their health pool is increased and contribution from health packs scaled down accordingly to keep it fair. 

The potential for map authors to change player properties they normally can't, using map logic. See 'Mapper Control'.

## Mapper Control (Special Functions for Mappers)

DTK lets a mapper change player properties that are normally not accessible, such as player class, weapon attributes, replacement weapons and so on. It works using a logic_case with special values.

At the moment you can change a player's class; set their speed; move type; give them weapons; remove weapons; give a weapon attributes; set the player's health, max health and scale it up (if they're an activator); send a message to their chat; switch them to a specific weapon slot; force them to be melee-only; set a custom model for them and make it use class animations.

If you're interested in adding such functionality to your map, pay us a visit at our deathrun design community [Death Experiments](https://steamcommunity.com/groups/death_experiments) and ask us about it. 

## Plans for the Future

A decent enough weapon restriction system that uses several ready-to-use configs for maps that require varying tiers of mobility and weapon restrictions. e.g. Some maps need melee-only, some demand no special mobility, some can get away with small jump boosts or trimping.

Expansions to the map instructions feature to let mappers use the boss bar for a boss 'entity' using a math_counter. Options to display or track health of more than one target.

Separating the map instructions system into a separate plugin.
