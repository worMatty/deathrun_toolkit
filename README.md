# Deathrun Toolkit

## What is Deathrun?

What is deathrun?! Have you been living under a rock?
Basically, there's one guy on blue and a bunch of guys on red. The blue guy has to trigger traps and try to kill reds, while the reds have to survive and at least one of them has to make it to the end for the team to win. It's like an obstacle course but fatal!

## What is Deathrun Toolkit?

It's a set of plugins for deathrun servers. The base plugin detects deathrun maps and handles the swapping of players to the right teams and the selection of the blu guy (_activator_) each round. It also does a bunch of other stuff, but I'll go into detail later. There are also a bunch of smaller plugins that deal with exploits and enhance the game.

## Installation

For the base deathrun experience you only need dtk.smx and the translation file. You can add the weapon restriction and replacement configs as well if you like but they are very limited at the moment. You can ignore the other plugins. 

### Optional Libraries
- [Asherkin's TF2 Attributes plugin](https://forums.alliedmods.net/showthread.php?t=210221) is used to set attributes on players and weapons to restrict them. This is recommended because most deathrun maps have some weaknesses that can be exploited by rocket jumpers, scout double jumps and so on.
- [Source Chat Relay](https://forums.alliedmods.net/showthread.php?p=2617899) is used to send the round start, end, and activator selection messages to a Discord channel.
- The [SteamTools extension](https://forums.alliedmods.net/showthread.php?t=236206) changes your game server's description.

You don't need to add any cvars to your server configs, the plugin will take care of all that. You only need to change a plugin convar when you want to tweak a default setting, such as number of activators. If you only want to use DTK for some maps, put dtk_auto_enable 0 in server.cfg and dtk_auto_enable 1 in your map's config. You can get a list of plugin cvars by doing `sm cvars dtk` or `find dtk` in server console.

### Optional Plugins

* dtk_use - Lets you +use buttons on old maps that only support damaging buttons to trigger them
* dtk_sacrifice - Allows a runner to sacrifice themselves for a dead team mate
* dtk_trains - Disable user control of trains so players can't +use control them
* dtk_damage_filter - Filters damage types from one team to the other for maps where teams can attack each other
* ragdoll_effects - Mappers can do special effects on ragdolls by giving trigger_hurts special damage type integers

## Features

The plugin has all the bells and whistles you would expect of a deathrun plugin. Player preferences, a menu, etc. But here are some things that set it aside from others.

### Cool Things

* Activator health is shown via the use of the boss health bar during combat
* Mappers can use logic to change a player's properties or give them weapons
* Mappers can use logic to trigger activator health scaling when appropriate, e.g. in an arena or fight mini game
* The plugin doesn't do anything to players that interferes with the workings of a map such as negate fall damage, grant resistances or force speeds

### Not As Cool Things

* When you die the plugin says what killed you
* Blue guy can be prevented from suiciding or switching teams during a round (and pre-round)
* It currently has ~~full~~ some Turkish translations and some German
* It doesn't use on-screen text often so it's unlikely to interfere with map text

### Server Operator Stuff

* Automatically enables on deathrun maps and disables when they end
* TF2 Workshop maps are properly detected
* Support for multiple activators
* Support for Open Fortress and TF2 Classic
* If enabled, executes config_deathrun.cfg after all other config files

## Note About The Current State

The plugin has a lack of weapon and ability restrictions so you probably won't be able to use it on your existing rotation without some problems. Blast jumping is disabled by hooking and negating self-damage. Spies can only cloak for a fraction of a second. Scouts can't double jump but they can use the Force-a-Nature by design as it requires skill. 

## Design Philosophy and Important Differences

#### Stuff I won't support

* Glowing outlines, because it ruins hide and seek on maps
* Setting all classes to the same run speed as supplied
* Melee-only as supplied

My philosophy is that wherever possible, map-makers should fix problems in their maps and design them better. If we depend on plugin makers to patch these issues all the time, new mappers get the impression that by default, deathrun maps are melee-only, or that every class has the same speed, and so on. We didn't get to this point because it was better for the game mode. We got to it because of successive and perhaps thoughtless 'fixes' to bad maps, and now people think that's all that deathrun is. If things continue this way we will end up with a very flat experience similar to CSS and GMod deathrun, where the only difference is the choice of character model. In order for the game mode to grow, we need to bring back class variety so we can come up with cool new ways to play. Restricting everything reduces potential for exploits but it limits creative freedom and innovation.

I have built options into the plugin for speed changing and melee-only just for backwards compatability with old maps with exploits or poor design. I appreciate though, that some mappers will want to provide a pure experience and melee-only is required for that, but there are ways for the map-maker to achieve this themselves using game logic! If you need help, come to our Discord server: https://steamcommunity.com/groups/death_experiments

* Customised replacement weapons

Weapons given to the player are plain because I do not want to fuck around with the economy and devalue people's earned weapons.

* Disabling spy disguises (why? What is the harm?)

## Detailed Technical Things for Studs

Player aspects such as run speed and cloak level are modified by adding TF2 attributes, instead of having their properties set on every game frame like how Deathrun Redux does it. This method does not prevent the map from affecting a player's speed using things like stun triggers, pickups, boost pads etc. Nor does it prevent the use of movement-enhancing abilities.

DTK doesn't require that the map has a tf_logic_arena. Mappers are free to make maps that don't have Sudden Death as a core mechanic. They could for example have dead players respawn in a waiting area, or make a new variant of deathrun that revolves around having lives.

Activator selection and replacement is more robust than on Deathrun Redux. If an activator switches teams or leaves the server during freeze time the next player in the queue takes their place immediately.

Health scaling for the activator is handled a bit differently. By default the activator has the same amount of health as a normal player, but in combat mini games the map author can trigger health scaling using map logic. The health of the activator is then scaled up to a suitable figure based on the number of remaining red players. Their health pool is increased and contribution from health packs scaled down accordingly to keep it fair. 

The potential for map authors to change player properties they normally can't, using map logic. See 'Mapper Control'.

## Mapper Control (Special Functions for Mappers)

DTK lets a mapper change player properties that are normally not accessible, such as player class, weapon attributes, replacement weapons and so on. It works using a logic_case with special values.

At the moment you can change a player's class; set their speed; move type; give them weapons; remove weapons; give a weapon attributes; set the player's health, max health and scale it up (if they're an activator); send a message to their chat; switch them to a specific weapon slot; force them to be melee-only; set a custom model for them and make it use class animations (the latter is not possible using map logic).

If you're interested in adding such functionality to your map, pay us a visit at the Death Experiments Discord server and ask us about it.

## Plans for the Future

A decent enough weapon restriction system that uses several ready-to-use configs for maps that require varying tiers of mobility and weapon restrictions. e.g. Some maps need melee-only, some demand no special mobility, some can get away with small jump boosts or trimping.

Expansions to the map instructions feature to let mappers use the boss bar for a boss 'entity' using a math_counter. Options to display or track health of more
than one target.
