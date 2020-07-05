# Deathrun Toolkit

## What is Deathrun?

It's a game mode for Team Fortress 2. One player gets put on the blue team (the activator) and the rest get put on Red (the runners) and must run a hazard course. The objective of the blue guy is to spring traps to kill the reds, while the reds have to reach the end of the course without dying.

## What Does This Plugin Do?

It detects deathrun maps and handles the swapping of players to the right teams and the selection of the activator each round. It also does a bunch of other stuff, but I'll go into detail later. The 'Base' plugin is part of a planned suite of plugins aimed at making deathrun more fun and servers easier to manage.

## How do I Install It?

Add the .smx file to sourcemod/plugins and the .txt file to sourcemod/translations.

### Optional Extras

* Asherkin's TF2 Attributes plugin is used to set attributes on player weapons and limit them.
* Source Chat Relay is used to send the round start, end, and activator selection messages to a Discord channel.
* The SteamTools extension changes your game server's description.

## List of Features

### For Players

* Players take it in turns to be the activator by earning queue points for playing
* Players can change their preferences in a menu
* If you don't like non-English SourceMod messages you can toggle your client language to English
* Activator health is shown via the use of the boss health bar during combat, and overhealing in a text element
* When you die, the type and name of the entity that killed you is shown in chat
* Optionally, team mate push-away is enabled at three players for a slight increase in challenge

### For Server Operators

* Player preferences and queue points are saved to the server's local database. Records older than thirty days are purged
* The blue player can optionally be prevented from switching teams or committing suicide during a round
* All publicly-displayed plugin messages can be translated. We currently have full Turkish translations and some German
* Chat message prefixes and colours can be altered in the translation file
* The plugin disables itself when the map is not a deathrun map, which is good for multi-game mode servers
* While disabled, for convenience some functions still work, such as the menu and some admin commands
* TF2 Workshop maps are properly detected
* Experimental support for multiple activators but I recommend against using this as it sucks to play
* Experimental support for Open Fortress
* If the plugin is enabled it will execute config_deathrun.cfg on each new deathrun map

### For Mappers

* DTK enables you to change player properties and issue weapons using logic entities
* DTK does not give a player properties such as damage resistance or fall damage negation
* DTK does not use on-screen text very often so it's unlikely to interfere with your game_text text

## Note About The Current State

DTK is work in progress.

## Design Philosophy and Important Differences

Glowing outlines.
Flat rate speed modification as supplied.
Melee-only as supplied.
Spy disguise disabling.
Custom weapon replacements.

* Player aspects such as run speed and cloak level are modified by adding TF2 attributes, instead of having their properties set on every game frame. This method does not prevent the map from affecting a player's speed using things like stun triggers, pickups, boost pads etc. Nor does it prevent the use of movement-enhancing bilities, which opens up new ways to play.
* DTK doesn't require that the map has a tf_logic_arena. Mappers are free to make maps that don't have Sudden Death as a core mechanic. They could for example have dead players respawn in a waiting area, or make a new variant of deathrun that revolves around having lives.
* Activator selection and replacement is more robust that on Deathrun Redux. If an activator switches teams or leaves the server during freeze time the next player in the queue takes their place immediately.
* Health scaling for the activator is handled a bit differently. By default the activator has the same amount of health as a normal player, but in combat mini games the map author can trigger health scaling using map logic. The health of the activator is then scaled up to a suitable figure based on the number of remaining red players. Their health pool is increased and contribution from health packs scaled down accordingly to keep it fair. 
* The potential for map authors to change player properties they normally can't using map logic. See 'Mapper Control'.

## Restrictions
Blast pushing
Back stabbing activator
Engineer buildings
TT
Cleaver
Spy cloak
Charging

## Commands

The client commands can be found in the menu's help section. To open the menu, type sm_dr in console or /dr in chat. Here are the admin commands:

* sm_draward: Award a target some queue points. You can also give them a negative value to take them away or push them into negative figures, which can be used as a sort of time-based activator ban
* sm_drdata: Show data about the players in console such as queue points and DTK bit flags
* sm_drresetdatabase: Remove the DTK table from your SourceMod local database
* sm_drresetuser: Delete a player from the database
* sm_drscalehealth: Manually trigger the activator health scaling (based on remaining red players)
* sm_setclass: Change a target's TF2 class. The function accepts the first three characters of a class name

## ConVars



## Mapper Control (Special Functions for Mappers)

logic_case
Health scaling

## Plans for the Future

