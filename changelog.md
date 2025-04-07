# Day 1
4/5/2025 - 9:03 AM CET
- Set up file structure
- Added simple menu scene (start and quit button)
- Added simple game scene (2D character controller with gravity)
- Added object/scene template 

4/5/2025 - 12:03 PM CET
- Set up exporting/distributing
- Added a respawn mechanic

4/5/2025 - 11:52 PM CET
- Added placeholder sprite for the player with direction tracking
- Added placeholder parralax background (shout out to [lil-cthulhu](https://lil-cthulhu.itch.io/pixel-art-cave-background))
- Added placeholder sprite for the canary with anchoring to the player 
- Added oxygen meters for the player and canary (with death when oxygen is at 0)
- Split player and canary into seperate files from game.lua

4/5/2025 - 21:54 PM CET
- Added a map generator to generate and calculate the map

# Day 2
4/6/2025 12:30 AM CET
- Added alert sound when canary is low on oxygen
- Added proper oxygen refilling (test by pressing i to toggle oxygen)

4/6/2025 9:12 AM CET
- Added actual chirp sound for the canary
- Added physics swining for the canary cage

4/6/2025 11:02 AM CET
- Added a walk cycle for the player (using cycle from [nathan van der stoep](https://nathanvanderstoep.itch.io/walk-cycle-template) as basis)

4/6/2025 14:52 PM CET
-Added a World generator to display and generate the world from the map

4/6/2025 19:12 PM CET
- Added Player and world collition
- Added camera following player

4/6/2025 21:55 PM CET
- Added key j, g and f3 for super speed, generating seeds and viewing debug map
- Spruced up the main menu
- Set up the build file with an icon and correct game info

4/6/2025 23:05 PM CET
- Added shacks as a tile
- Added oxygen refilling when in shack tile (only registers in a very small radius currently)

# Day 3
4/7/2025 16:40 PM CET
- Added functionality to enter the shack to refill oxygen, instead of just refilling when near the shack

4/7/2025 18:58 PM CET
- Added lighting! Way more atmosphere now
- Fixed shack rendering

4/7/2025 19:57 PM CET
- Heavily optimized the game

4/7/2025 21:20 PM CET
- Added a "spawner" tile which spawns entities
- Added a stalker entity

4/7/2025 21:49 PM CET
- Added a spider entity

4/7/2025 23:13 PM CET
- Fixed spider entity
- Made new cover art
- Properly set up LDjam.com and itch.io pages