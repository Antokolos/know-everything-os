# I Know Everything
I Know Everything is the trivia/quiz game for Steam made with [Godot engine](https://godotengine.org/).
You can find it in Steam here: https://store.steampowered.com/app/1040310/I_Know_Everything/

This game supports many Steam features, such as:
* Steam leaderboards
* Steam achievements
* Multiplayer support via P2P Steam API

Also this game is crossplatform (Windows, Mac and Linux) and supports controller.

The game uses several open-source libraries for Godot:
* [GodotSteam](https://github.com/Gramps/GodotSteam) (Steam integration)
* [GDSQLite](https://github.com/khairul169/gdsqlite-native) (SQLite database support)

Also this game can help you with:
* Creating user interfaces with Godot engine
* Translating your game to the different languages using the Godot way to do this (interface.csv file containing the translations of the UI elements)
* Using GDNative libraries in your project
* Creating particle effects (such as fireworks)
* Using controller in your game
* Various hacks & tricks (for example, getting full path to the game working directory in order to use the external files outside your pck file)

This repository contains test version of the game database. Full database is accessible in the Steam version.
Please also note, that the questions and answers are encrypted. The game uses really simple encryption, but this causes opensource version to crash when using the database from the Steam version.