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

4/6/2025 19:12 pm CET
- Added Player and world collition
- Added camera following player