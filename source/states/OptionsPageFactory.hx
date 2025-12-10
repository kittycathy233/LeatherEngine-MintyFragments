package states;

import haxe.Json;
import ui.Option;
#if MODDING_ALLOWED
import modding.ModList;
import modding.PolymodHandler;
#end
import openfl.utils.Assets;

/**
 * 懒加载页面工厂类，用于按需创建选项页面
 */
class OptionsPageFactory {
	/**
	 * 初始化指定的页面
	 * @param pageName 页面名称
	 * @param pages 页面Map的引用
	 */
	public static function initializePage(pageName:String, pages:Map<String, Array<Option>>):Void {
		switch (pageName) {
			case "Graphics":
				initializeGraphicsPage(pages);
			case "Misc":
				initializeMiscPage(pages);
			case "Miscellaneous":
				initializeMiscellaneousPage(pages);
			#if MODDING_ALLOWED
			case "Mod Options":
				initializeModOptionsPage(pages);
			#end
			case "Optimizations":
				initializeOptimizationsPage(pages);
			case "Info Display":
				initializeInfoDisplayPage(pages);
			case "Judgements":
				initializeJudgementsPage(pages);
			case "Input Options":
				initializeInputOptionsPage(pages);
			case "Note Options":
				initializeNoteOptionsPage(pages);
			case "Screen Effects":
				initializeScreenEffectsPage(pages);
			case "Developer Options":
				initializeDeveloperOptionsPage(pages);
		}
	}

	/**
	 * 初始化Graphics页面
	 */
	private static function initializeGraphicsPage(pages:Map<String, Array<Option>>):Void {
		if (pages.exists("Graphics")) return; // 已经初始化过

		pages.set("Graphics", [
			new PageOption("Back", "Categories", "Go back to the main menu."),
			new PageOption("Note Options", "Note Options", "Change note-related options."),
			new PageOption("Info Display", "Info Display", "Configure options related to the info display.\n(FPS counter, memory display, etc)."),
			new PageOption("Optimizations", "Optimizations", "Configure performance optimization options.\nAdjust graphics quality and resource usage."),
			new GameSubStateOption("Max FPS", substates.MaxFPSMenu, "Change the maximum framerate."),
			new BoolOption("VSync", "vSync", "Toggle VSync."),
			new BoolOption("Bigger Score Text", "biggerScoreInfo", "When toggled, the score text will have a larger font."),
			new BoolOption("Bigger Info Text", "biggerInfoText", "When toggled, the time bar will have a larger font."),
			new StringSaveOption("Time Bar Style", ["leather engine", "psych engine", "old kade engine"], "timeBarStyle", "Change the style of the time bar."),
			new PageOption("Screen Effects", "Screen Effects", "Toggle screen effect options, such as camera zooming and shaders."),
			new GameStateOption("Change Hud Settings", ui.HUDAdjustment, "Change the position of hud objects, such as the ratings.")
		]);
	}

	/**
	 * 初始化Misc页面
	 */
	private static function initializeMiscPage(pages:Map<String, Array<Option>>):Void {
		if (pages.exists("Misc")) return; // 已经初始化过

		pages.set("Misc", [
			new PageOption("Back", "Categories", "Go back to the main menu."),
			new BoolOption("Friday Night Title Music", "nightMusic", "When toggled, the music for playing\non a friday night will always play."),
			new BoolOption("Freeplay Music", "freeplayMusic", "When toggled, instrumentals for freeplay songs will auto play."),
			#if DISCORD_ALLOWED
			new BoolOption("Discord RPC", "discordRPC", "Toggles discord rich presence."),
			#end
			new StringSaveOption("Cutscenes Play On", ["story", "freeplay", "both"], "cutscenePlaysOn", "Change when cutscenes play."),
			new StringSaveOption("Play As", ["bf", "opponent"], "playAs", "Change which side of the chart you play."),
			new BoolOption("Disable Debug Menus", "disableDebugMenus", "Disable debug menus, such as the chart editor."),
			new BoolOption("Invisible Notes", "invisibleNotes", "Makes notes invisible.\n(why would you want this?)"),
			new BoolOption("Auto Pause", "autoPause", "Will the game automatically pause when losing focus."),
			#if (target.threaded)
			new BoolOption("Load Asynchronously", "loadAsynchronously", "Loads some elements of the game will be loaded\nasyncrnously to speed up load times."),
			#end
			new BoolOption("Flixel Splash Screen", "flixelStartupScreen", "Toggles the haxeflixel startup splash screen."),
			new BoolOption("Skip Results", "skipResultsScreen", "When toggled, the results screen will be skipped."),
			#if CHECK_FOR_UPDATES
			new DisabledOption("Check For Updates", "Update checking is currently disabled.\nThis feature has been temporarily suspended."),
			#end
			new BoolOption("Show Score", "showScore", "Shows the current score."),
			new BoolOption("Dinnerbone Mode", "dinnerbone", "Dinnerbone mode."),
			new BoolOption("Window Name Uses Mod", "windowNameUsesMod", "When toggled, the window title will display the current mod name."),
			new GameSubStateOption("Import Old Scores", substates.ImportHighscoresSubstate, "Import scores from legacy leather engine versions.")
		]);
	}

	/**
	 * 初始化Miscellaneous页面（为了兼容性保留）
	 */
	private static function initializeMiscellaneousPage(pages:Map<String, Array<Option>>):Void {
		// 重定向到Misc页面
		initializeMiscPage(pages);
		pages.set("Miscellaneous", pages.get("Misc"));
	}

	#if MODDING_ALLOWED
	/**
	 * 初始化Mod Options页面
	 */
	private static function initializeModOptionsPage(pages:Map<String, Array<Option>>):Void {
		if (pages.exists("Mod Options")) return; // 已经初始化过

		pages.set("Mod Options", [new PageOption("Back", "Categories", "Go back to the main menu.")]);

		// 添加mod选项
		for (mod in modding.ModList.getActiveMods(modding.PolymodHandler.metadataArrays)) {
			pages.get("Mod Options").push(new PageOption(mod, mod, modding.ModList.modMetadatas.get(mod)?.description ?? "no description"));
			pages.set(mod, [new PageOption("Back", "Mod Options", "Go back to mod options.")]);
			if (sys.FileSystem.exists('mods/$mod/data/options.json')) {
				var modOptions:modding.ModOptions = cast Json.parse(sys.io.File.getContent('mods/$mod/data/options.json'));
				for (option in modOptions.options) {
					switch (StringTools.trim(option.type).toLowerCase()) {
						case "bool":
							pages.get(mod).push(new BoolOption(option.name, option.save, option.description, mod));
						case "string":
							pages.get(mod).push(new StringSaveOption(option.name, option.values, option.save, option.description, mod));
						#if HSCRIPT_ALLOWED
						case "state":
							pages.get(mod).push(new GameStateOption(option.name, new modding.custom.CustomState(option.script), option.description));
						case "substate":
							pages.get(mod).push(new GameSubStateOption(option.name, new modding.custom.CustomSubstate(option.script), option.description));
						#end
						default:
							throw 'Option type \'${option.type}\' is not a valid option type!';
					}
				}
			}
		}
	}
	#end

	/**
	 * 初始化Optimizations页面
	 */
	private static function initializeOptimizationsPage(pages:Map<String, Array<Option>>):Void {
		if (pages.exists("Optimizations")) return; // 已经初始化过

		pages.set("Optimizations", [
			new PageOption("Back", "Graphics", "Go back to the graphics menu."),
			new BoolOption("Antialiasing", "antialiasing",
				"When toggled, antialiasing will be enabled,\nmaking sprites smoother at the cost of some performance.\n(Should only really matter on really low-end devices)"),
			new BoolOption("Low Quality", "lowQuality", "When toggled, the game will not load\nunneeded sprites to improve performance.\n(when possible)"),
			new BoolOption("Health Icons", "healthIcons", "Toggles health icons."),
			new BoolOption("Health Bar", "healthBar", "Toggles the health bar."),
			new BoolOption("Ratings and Combo", "ratingsAndCombo", "When toggled, ratings and combo popups will be displayed."),
			new BoolOption("Custom Ratings", "customRatings", "When toggled, additional custom ratings (ka11, ka22, etc.) will be displayed."),
			new BoolOption("Chars And BGs", "charsAndBGs", "When not toggled, the game will\nhide characters and stages while ingame."),
			new BoolOption("Menu Backgrounds", "menuBGs", "When not toggled, color rectangles will be\nloaded instead of the menu background image."),
			new BoolOption("Optimized Characters", "optimizedChars",
				"When toggled, the game will load optimized spritesheets,\nremoving all unneeded animations (when possible)"),
			new BoolOption("Animated Backgrounds", "animatedBGs",
				"When not toggled, the game will load non-animated\nversions of stage sprites (when possible)"),
			new BoolOption("Preload Stage Events", "preloadChangeBGs",
				"When toggled, the game will preload stage change events,\nincreasing memory usage,\nbut will prevent lag spikes on stage change."),
			new BoolOption("Persistent Cached Data", "memoryLeaks",
				"When toggled, the game will never clear stored memory,\nspeeding up load times.\n(WARNING: Can lead to VERY high memory usage)"),
			new BoolOption("VRAM Sprites", "vramSprites",
				"When toggled, the game will try and store\nsprites in your GPU, saving on RAM.\nTurn this off if you have a bad GPU."),
			#if MODCHARTING_TOOLS
			new BoolOption("Optimized Modcharts", "optimizedModcharts",
				"When toggled, modchart sustains will use a more\noptimized renderer,at the cost of stretchy sustains."),
			#end
		]);
	}

	/**
	 * 初始化Info Display页面
	 */
	private static function initializeInfoDisplayPage(pages:Map<String, Array<Option>>):Void {
		if (pages.exists("Info Display")) return; // 已经初始化过

		pages.set("Info Display", [
			new PageOption("Back", "Graphics", "Go back to the graphics menu."),
			new DisplayFontOption("Display Font", [
				"_sans",
				Assets.getFont(Paths.font("vcr.ttf")).fontName,
				Assets.getFont(Paths.font("pixel.otf")).fontName
			],
				"infoDisplayFont", "Change the font used for the info display."),
			new BoolOption("FPS Counter", "fpsCounter", "Should the FPS counter be shown?"),
			new BoolOption("Memory Counter", "memoryCounter", "Should the memory counter be shown?"),
			new BoolOption("Version Display", "versionDisplay", "Should the engine version be shown?"),
			new BoolOption("Commit Hash", "showCommitHash", "Should the hash for the current commit be shown?")
		]);
	}

	/**
	 * 初始化Judgements页面
	 */
	private static function initializeJudgementsPage(pages:Map<String, Array<Option>>):Void {
		if (pages.exists("Judgements")) return; // 已经初始化过

		pages.set("Judgements", [
			new PageOption("Back", "Gameplay", "Go back to the gameplay menu."),
			new GameSubStateOption("Timings", substates.JudgementMenu, "Edit the timings for ratings."),
			new StringSaveOption("Rating Mode", ["psych", "simple", "complex"], "ratingType", "Change how ratings are calculated."),
			new BoolOption("Marvelous Ratings", "marvelousRatings", "When toggled, marvelous ratings will be shown,\nelse, sick will be the max rating."),
			new BoolOption("Show Rating Count", "sideRatings", "Should ratings be shown on the side of the screen?")
		]);
	}

	/**
	 * 初始化Input Options页面
	 */
	private static function initializeInputOptionsPage(pages:Map<String, Array<Option>>):Void {
		if (pages.exists("Input Options")) return; // 已经初始化过

		pages.set("Input Options", [
			new PageOption("Back", "Gameplay", "Go back to the gameplay menu."),
			new StringSaveOption("Input Mode", ["standard", "rhythm"], "inputSystem", "Change how inputs work."),
			new BoolOption("Anti Mash", "antiMash", "When toggled, mashing keys will punish the player."),
			new BoolOption("Shit gives Miss", "missOnShit", "When toggled, getting a \"shit\" rating will also count as a miss."),
			new BoolOption("Ghost Tapping", "ghostTapping", "When not toggled, hitting a key\nat the wrong time will give a miss."),
			new BoolOption("Gain Misses on Sustains", "missOnHeldNotes", "When toggled, each sustain segment will give misses."),
			new BoolOption("Death On Miss", "noHit", "When toggled, getting a miss will cause a death.\n(useful for when trying to FC a song.)"),
			new BoolOption("Reset Button", "resetButton", "When toggled, enables a keybind for causing an instant death.")
		]);
	}

	/**
	 * 初始化Note Options页面
	 */
	private static function initializeNoteOptionsPage(pages:Map<String, Array<Option>>):Void {
		if (pages.exists("Note Options")) return; // 已经初始化过

		pages.set("Note Options", [
			new PageOption("Back", "Graphics", "Go back to the graphics menu."),
			new GameSubStateOption("Note BG Alpha", substates.NoteBGAlphaMenu, "Change the alpha of the note lane underlay."),
			new BoolOption("Enemy Note Glow", "enemyStrumsGlow", "When toggled, enemy strums will\nlight up when the enemy hits a note."),
			new BoolOption("Player Note Splashes", "playerNoteSplashes",
				"When toggled, note splashes will show up\nwhen the player hits a \"sick\" or higher rating."),
			new BoolOption("Enemy Note Splashes", "opponentNoteSplashes",
				"When toggled, note splashes will show up\nwhen the enemy hits a \"sick\" or higher rating."),
			new BoolOption("Note Accuracy Text", "displayMs", "Toggles a text popup showing how early or late you hit a note."),
			new GameSubStateOption("Note Colors", substates.NoteColorSubstate, "Change the colors of notes."),
			new BoolOption("Color Quantization", "colorQuantization", "When toggled, note colors will be changed depending on the beat."),
			new GameSubStateOption("UI Skin", substates.UISkinSelect, "Change the UI skin for notes and menus.")
		]);
	}

	/**
	 * 初始化Screen Effects页面
	 */
	private static function initializeScreenEffectsPage(pages:Map<String, Array<Option>>):Void {
		if (pages.exists("Screen Effects")) return; // 已经初始化过

		pages.set("Screen Effects", [
			new PageOption("Back", "Graphics", "Go back to the graphics menu."),
			new BoolOption("Camera Tracks Direction", "cameraTracksDirections", "When toggled, the camera will follow the direction of the note."),
			new BoolOption("Camera Bounce", "cameraZooms", "When toggled, the game and hud will zoom in on beat."),
			new BoolOption("Flashing Lights", "flashingLights", "Toggles flashing lights."),
			new BoolOption("Screen Shake", "screenShakes", "Toggles screen shake effects."),
			new BoolOption("Shaders", "shaders", "Toggles shaders.")
		]);
	}

	/**
	 * 初始化Developer Options页面
	 */
	private static function initializeDeveloperOptionsPage(pages:Map<String, Array<Option>>):Void {
		if (pages.exists("Developer Options")) return; // 已经初始化过

		pages.set("Developer Options", [
			new PageOption("Back", "Categories", "Go back to the main menu."),
			new BoolOption("Developer Mode", "developer", "When toggled, enables developer tools.\n(traced lines display, toolbox, etc)"),
			new DeveloperOption("Show Traced Lines", "showTracedLines",
				"When toggled, the info display will show the\nnumber of traced lines and errors by the game"),
			new DeveloperOption("Throw Exception On Error", "throwExceptionOnError",
				"When toggled, the game will throw an\nexception when an error is thrown."),
			new DeveloperOption("Auto Open Charter", "autoOpenCharter",
				"When toggled, the game will automatically\nopen the chart editor when no chart is found."),
			new StepperSaveDeveloperOption("Chart Backup Interval", 1, 10, "backupDuration", 1,
				"Change how long the game will wait\nbefore creating a chart backup.\n(in minutes.)"),
		]);
	}
}