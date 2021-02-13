# Deathrun Toolkit

## What is Deathrun?

What is deathrun?! Have you been living under a rock?
Basically, there's one guy on blue and a bunch of guys on red. The blue guy has to trigger traps and try to kill reds, while the reds have to survive and at least one of them has to make it to the end for the team to win. It's like an obstacle course but fatal!

## What is Deathrun Toolkit?

It's a set of plugins for deathrun servers. The base plugin detects deathrun maps and handles the swapping of players to the right teams and the selection of the blu guy (_activator_) each round. It also does a bunch of other stuff, but I'll go into detail later. There are also a bunch of smaller plugins that deal with exploits and enhance the game.

## Installation

For the base deathrun experience you only need dtk.smx and the translation file. You can ignore the other plugins. 

### Dependencies
- [Asherkin's TF2 Attributes plugin](https://forums.alliedmods.net/showthread.php?t=210221) is used to set attributes on players and weapons to restrict them. This is recommended because most deathrun maps have some weaknesses that can be exploited by rocket jumpers, scout double jumps and so on.
- [Source Chat Relay](https://forums.alliedmods.net/showthread.php?p=2617899) is used to send the round start, end, and activator selection messages to a Discord channel.
- The [SteamTools extension](https://forums.alliedmods.net/showthread.php?t=236206) changes your game server's description.

### Optional Plugins

* dtk_use - Lets you +use buttons on old maps that only support damaging buttons to trigger them
* dtk_sacrifice - Allows a runner to sacrifice themselves for a dead team mate
* dtk_damage_filter - Filters damage types from one team to the other for maps where teams can attack each other
* ragdoll_effects - Mappers can do special effects on ragdolls by giving trigger_hurts special damage type integers

## Features

The plugin has all the bells and whistles you would expect of a deathrun plugin. Player preferences, a menu, etc. But here are some things that set it aside from others.

### Cool Things

* Activator health is shown via the use of the boss health bar during combat, and overhealing in a text element
* Mappers can change use logic to change a player's properties or give them weapons
* Mappers can use logic to trigger activator health scaling when appropriate, e.g. in an arena or fight mini game
* The plugin doesn't do anything to players that interferes with the workings of a map such as negate fall damage, grant resistances or force speed on every game frame

### Not So Cool Things

* When you die the plugin says what killed you
* Blue guy can be prevented from suiciding or switching teams
* It currently has full Turkish translations and some German
* It doesn't use on-screen text often so it's unlikely to interfere with map text

### Server Operator Stuff

* The plugin only works on deathrun maps so it's suitable for multi-game mode servers
* TF2 Workshop maps are properly detected
* Experimental support for multiple activators but I recommend against using this as it sucks to play
* Experimental support for Open Fortress and TF2 Classic
* If the plugin is enabled it will execute config_deathrun.cfg on each new deathrun map

## Note About The Current State

DTK is work in progress.

## Design Philosophy and Important Differences

#### Stuff I won't support

* Glowing outlines, because it ruins hide and seek on maps
* Setting all classes to the same run speed as supplied
* Melee-only as supplied
* Disabling spy disguises (why? What is the harm?)

My philosophy is that wherever possible, map-makers should fix problems in their maps and design them better, and that plugin makers shouldn't be compensating for shoddy practices in maps because we end up with new mappers thinking that deathrun maps are melee-only, and that every class is the same speed, and so on. We end up with a very flat experience where the only difference is the choice of character model. In order for the game mode to grow, we need class variety to add cool new ways to play, so we can't continue to restrict everything.

I build options in the plugin for speed changing and melee-only for backwards compatability with old maps with exploits or poor design.

* Customised replacement weapons

What weapons are given to the player are plain because I do not want to fuck around with the economy and devalue people's earned weapons.

## Boring Technical Things for Studs

* Player aspects such as run speed and cloak level are modified by adding TF2 attributes, instead of having their properties set on every game frame like how Deathrun Redux does it. This method does not prevent the map from affecting a player's speed using things like stun triggers, pickups, boost pads etc. Nor does it prevent the use of movement-enhancing abilities.
* DTK doesn't require that the map has a tf_logic_arena. Mappers are free to make maps that don't have Sudden Death as a core mechanic. They could for example have dead players respawn in a waiting area, or make a new variant of deathrun that revolves around having lives.
* Activator selection and replacement is more robust that on Deathrun Redux. If an activator switches teams or leaves the server during freeze time the next player in the queue takes their place immediately.
* Health scaling for the activator is handled a bit differently. By default the activator has the same amount of health as a normal player, but in combat mini games the map author can trigger health scaling using map logic. The health of the activator is then scaled up to a suitable figure based on the number of remaining red players. Their health pool is increased and contribution from health packs scaled down accordingly to keep it fair. 
* The potential for map authors to change player properties they normally can't using map logic. See 'Mapper Control'.

## Mapper Control (Special Functions for Mappers)

Right now you can change a player's class; set their speed; move type; give them weapons; remove weapons; give a weapon attributes; set the player's health, max health and scale it up (if they're an activator); send a message to their chat; switch them to a specific slot; force them to be melee-only; set a custom model for them and make it use class animations.

If you'd like to add such functionality to your map, hop along to the Death Experiments Discord server and ask us about it.

## Plans for the Future

A decent enough weapon restriction system that uses several ready-to-use options for maps that require varying levels of mobility and weapon restrictions. e.g. Some maps need melee-only, some demand no special mobility, some can get away with small jump boosts or trimping.
