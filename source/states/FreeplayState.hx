package states;

import toolbox.ChartingState;
import sys.io.File;
import sys.FileSystem;
import haxe.Json;
#if (target.threaded)
import sys.thread.Thread;
#end
#if DISCORD_ALLOWED
import utilities.DiscordClient;
#end
import game.Conductor;
import utilities.Options;
import flixel.util.FlxTimer;
import substates.ResetScoreSubstate;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import game.SongLoader;
import game.Highscore;
import game.FreeplaySong;
import ui.HealthIcon;
import ui.Alphabet;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;

using StringTools;
using utilities.BackgroundUtil;

class FreeplayState extends MusicBeatState {
	public var songs:Array<FreeplaySong> = [];

	public var selector:FlxText;

	public static var curSelected:Int = 0;
	public static var curDifficulty:Int = 1;
	public static var curSpeed:Float = 1;

	public var scoreText:FlxText;
	public var diffText:FlxText;
	public var speedText:FlxText;
	public var lerpScore:Int = 0;
	public var intendedScore:Int = 0;

	public var grpSongs:FlxTypedGroup<Alphabet>;
	public var curPlaying:Bool = false;

	public var iconArray:Array<HealthIcon> = [];

	public static var songsReady:Bool = false;

	public var bg:FlxSprite;
	public var selectedColor:Int = 0xFF7F1833;
	public var scoreBG:FlxSprite;

	public var curRank:String = "N/A";

	public var curDiffString:String = "normal";
	public var curDiffArray:Array<String> = ["easy", "normal", "hard"];

	public var vocals:FlxSound = new FlxSound();

	public var canEnterSong:Bool = true;
	public var isResettingScore:Bool = false; // 标志跟踪是否正在重置分数

	// thx psych engine devs
	public var colorTween:FlxTween;

	#if (target.threaded)
	public var loading_songs:Thread;
	public var stop_loading_songs:Bool = false;
	#end

	public var lastSelectedSong:Int = -1;

	/**
		Current instance of `FreeplayState`.
	**/
	public static var instance:FreeplayState = null;

	override function create() {
		instance = this;

		MusicBeatState.windowNameSuffix = " Freeplay";

		var black:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);

		#if MODDING_ALLOWED
		CoolUtil.convertFromFreeplaySongList();
		#end

		#if NO_PRELOAD_ALL
		if (!songsReady) {
			Assets.loadLibrary("songs").onComplete(function(_) {
				FlxTween.tween(black, {alpha: 0}, 0.5, {
					ease: FlxEase.quadOut,
					onComplete: function(twn:FlxTween) {
						remove(black);
						black.kill();
						black.destroy();
					}
				});

				songsReady = true;
			});
		}
		#else
		songsReady = true;
		#end

		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			TitleState.playTitleMusic();

		var path:String = #if MODDING_ALLOWED 'mods/${Options.getData("curMod")}/data/freeplay.json'; #else 'assets/data/freeplay.json'; #end
		if (FileSystem.exists(path)) {
			songs = cast Json.parse(File.getContent(path)).songs;
		}

		if (curSelected > songs.length)
			curSelected = 0;

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		add(bg = new FlxSprite().makeBackground(0xFFE1E1E1));

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		scoreText = new FlxText(FlxG.width, 5, 0, "", 32);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 1, FlxColor.BLACK);
		scoreBG.alpha = 0.6;
		scoreBG.visible = false;

		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		scoreText.visible = false;

		diffText = new FlxText(FlxG.width, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		diffText.alignment = RIGHT;
		diffText.visible = false;

		speedText = new FlxText(FlxG.width, diffText.y + 36, 0, "", 24);
		speedText.font = scoreText.font;
		speedText.alignment = RIGHT;
		speedText.visible = false;

		#if (target.threaded)
		if (!Options.getData("loadAsynchronously") || !Options.getData("healthIcons")) {
		#end
			for (i => song in songs) {
				var songText:Alphabet = new Alphabet(0, (70 * i) + 30, song.name, true, false);
				songText.isMenuItem = true;
				songText.targetY = i;
				grpSongs.add(songText);

				if (Options.getData("healthIcons")) {
					var icon:HealthIcon = new HealthIcon(song.icon);
					icon.sprTracker = songText;
					iconArray.push(icon);
					add(icon);
				}
			}
		#if (target.threaded)
		}
		else {
			loading_songs = Thread.create(function() {
				var i:Int = 0;

				while (!stop_loading_songs && i < songs.length) {
					var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songs[i].name, true, false);
					songText.isMenuItem = true;
					songText.targetY = i;
					grpSongs.add(songText);

					var icon:HealthIcon = new HealthIcon(songs[i].icon);
					icon.sprTracker = songText;
					iconArray.push(icon);
					add(icon);

					i++;
				}
			});
		}
		#end

		// layering
		add(scoreBG);
		add(scoreText);
		add(diffText);
		add(speedText);

		selector = new FlxText();

		selector.size = 40;
		selector.text = "<";

		if (!songsReady) {
			add(black);
		} else {
			remove(black);
			black.kill();
			black.destroy();

			songsReady = false;

			new FlxTimer().start(1, function(_) songsReady = true);
		}

		if (songs.length != 0 && curSelected >= 0 && curSelected < songs.length) {
			selectedColor = FlxColor.fromString(songs[curSelected].color);
			bg.color = selectedColor;
			changeSelection();
		} else {
			bg.color = 0xFF7C689E;
		}

		#if PRELOAD_ALL
		var leText:String = "R: Reset Score\nSPACE: Play Song Audio\nShift + ←/→: Change Speed";
		#else
		var leText:String = "R: Reset Score\nShift + ←/→: Change Speed";
		#end

		infoText = new FlxText(5, FlxG.height - 60, 0, leText, 20);
		infoText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
		infoText.y = FlxG.height - infoText.height;
		infoText.scrollFactor.set();
		
		infoBG = new FlxSprite(infoText.x - 8, infoText.y - 8).makeGraphic(Std.int(infoText.width + 15), Std.int(infoText.height + 15), FlxColor.BLACK);
		infoBG.alpha = 0.3;
		infoBG.scrollFactor.set();
		add(infoBG);
		add(infoText);

		super.create();
		call("createPost");
	}

	public var mix:String = null;

	public var infoText:FlxText;
	public var infoBG:FlxSprite;

	/*public function addSong(songName:String, weekNum:Int, songCharacter:String) {
			call("addSong", [songName, weekNum, songCharacter]);
			songs.push(new FreeplaySong(songName, weekNum, songCharacter));
			call("addSongPost", [songName, weekNum, songCharacter]);
		}*/
	override function update(elapsed:Float) {
		call("update", [elapsed]);
		#if MODDING_ALLOWED
		if (FlxG.keys.justPressed.TAB) {
			openSubState(new modding.SwitchModSubstate());
			persistentUpdate = false;
		}
		#end

		super.update(elapsed);

		if (FlxG.sound.music.playing)
			Conductor.songPosition = FlxG.sound.music.time;

		for (i in 0...iconArray.length) {
			if (i == lastSelectedSong)
				continue;

			var _icon:HealthIcon = iconArray[i];

			_icon.scale.set(_icon.startSize, _icon.startSize);
		}

		if (lastSelectedSong != -1 && scaleIcon != null)
			scaleIcon.scale.set(FlxMath.lerp(scaleIcon.scale.x, scaleIcon.startSize, elapsed * 9),
				FlxMath.lerp(scaleIcon.scale.y, scaleIcon.startSize, elapsed * 9));

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, 0.4));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;

		var funnyObject:FlxText = scoreText;

		if (speedText.width >= scoreText.width && speedText.width >= diffText.width)
			funnyObject = speedText;

		if (diffText.width >= scoreText.width && diffText.width >= speedText.width)
			funnyObject = diffText;

		scoreBG.x = funnyObject.x - 6;

		// 只在宽度确实需要改变时才重新生成背景，避免不必要的闪动
		var targetWidth:Int = Std.int(funnyObject.width + 6);
		if (Std.int(scoreBG.width) != targetWidth && scoreBG.visible) {
			scoreBG.makeGraphic(targetWidth, 108, FlxColor.BLACK);
			// 保持背景的x位置不变，只更新宽度
			scoreBG.x = funnyObject.x - 6;
		}

		scoreText.x = FlxG.width - scoreText.width;
		scoreText.text = "PERSONAL BEST:" + lerpScore;

		diffText.x = FlxG.width - diffText.width;

		curSpeed = FlxMath.roundDecimal(curSpeed, 2);

		if (curSpeed < 0.25)
			curSpeed = 0.25;

		speedText.text = "SPEED: " + curSpeed;
		speedText.x = FlxG.width - speedText.width;

		var leftP = controls.LEFT_P;
		var rightP = controls.RIGHT_P;
		var shift = FlxG.keys.pressed.SHIFT;

		var upP = controls.UP_P;
		var downP = controls.DOWN_P;

		if (songsReady) {
			if (songs.length > 1) {
				if (-1 * Math.floor(FlxG.mouse.wheel) != 0 && !shift)
					changeSelection(-1 * Math.floor(FlxG.mouse.wheel));
				else if (-1 * (Math.floor(FlxG.mouse.wheel) / 10) != 0 && shift)
					curSpeed += -1 * (Math.floor(FlxG.mouse.wheel) / 10);

				if (upP)
					changeSelection(-1);
				if (downP)
					changeSelection(1);
			}

			if (leftP && !shift)
				changeDiff(-1);
			else if (leftP && shift)
				curSpeed -= 0.05;

			if (rightP && !shift)
				changeDiff(1);
			else if (rightP && shift)
				curSpeed += 0.05;

			if (FlxG.keys.justPressed.R && shift)
				curSpeed = 1;

			if (controls.BACK) {
				if (colorTween != null)
					colorTween.cancel();

				if (vocals.active && vocals.playing)
					destroyFreeplayVocals(false);
				if (FlxG.sound.music.active && FlxG.sound.music.playing)
					FlxG.sound.music.pitch = 1;

				#if (target.threaded)
				stop_loading_songs = true;
				#end

				FlxG.switchState(() -> new MainMenuState());
			}

			var curSong:FreeplaySong = songs[curSelected];

			#if PRELOAD_ALL
			if (FlxG.keys.justPressed.SPACE) {
				destroyFreeplayVocals();

				// TODO: maybe change this idrc actually it seems ok now
				if (Assets.exists(SongLoader.getPath(curDiffString, curSong.name.toLowerCase(), mix))) {
					PlayState.SONG = SongLoader.loadFromJson(curDiffString, curSong.name.toLowerCase(), mix);
					Conductor.changeBPM(PlayState.SONG.bpm, curSpeed);
				}

				vocals = new FlxSound();

				var voicesDiff:String = (PlayState.SONG != null ? (PlayState.SONG.specialAudioName ?? curDiffString.toLowerCase()) : curDiffString.toLowerCase());
				var voicesPath:String = Paths.voices(curSong.name.toLowerCase(), voicesDiff, mix ?? '');

				if (Assets.exists(voicesPath))
					vocals.loadEmbedded(voicesPath);

				vocals.persist = false;
				vocals.looped = true;
				vocals.volume = 0.7;

				FlxG.sound.list.add(vocals);

				FlxG.sound.music = new FlxSound().loadEmbedded(Paths.inst(curSong.name.toLowerCase(), curDiffString.toLowerCase(), mix));
				FlxG.sound.music.persist = true;
				FlxG.sound.music.looped = true;
				FlxG.sound.music.volume = 0.7;

				FlxG.sound.list.add(FlxG.sound.music);

				FlxG.sound.music.play();
				vocals.play();

				lastSelectedSong = curSelected;
				scaleIcon = iconArray[lastSelectedSong];
			}
			#end

			if (FlxG.sound.music.active && FlxG.sound.music.playing && !FlxG.keys.justPressed.ENTER)
				FlxG.sound.music.pitch = curSpeed;
			if (vocals != null && vocals.active && vocals.playing && !FlxG.keys.justPressed.ENTER)
				vocals.pitch = curSpeed;

		if (controls.RESET && !shift) {
			isResettingScore = true; // 设置重置分数标志
			openSubState(new ResetScoreSubstate(curSong.name, curDiffString));
		}

			if (FlxG.keys.justPressed.ENTER) {
				playSong(curSong.name, curDiffString);
			}
		}
		call("updatePost", [elapsed]);
	}

	// TODO: Make less nested

	/**
		 * Plays a specific song
		 * @param songName
		 * @param diff
		 */
	public function playSong(songName:String, diff:String) {
		if (!canEnterSong) {
			return;
		}
		if (!CoolUtil.songExists(songName, diff, mix)) {
			if (!Options.getData("autoOpenCharter")) {
				CoolUtil.coolError(songName.toLowerCase() + " doesn't seem to exist!\nTry fixing it's name in freeplay.json",
					"Leather Engine's No Crash, We Help Fix Stuff Tool");
			} else {
				if (Options.getData("developer")) {
					#if MODDING_ALLOWED
					var modPath:String = 'mods/${Options.getData('curMod')}';
					if (!FileSystem.exists('$modPath/data')) {
						FileSystem.createDirectory('$modPath/data');
					}
					if (!FileSystem.exists('$modPath/data/song data')) {
						FileSystem.createDirectory('$modPath/data/song data');
					}
					if (!FileSystem.exists('$modPath/data/song data/${songName.toLowerCase()}')) {
						FileSystem.createDirectory('$modPath/data/song data/${songName.toLowerCase()}');
					}
					File.saveContent('$modPath/data/song data/${songName.toLowerCase()}/${songName.toLowerCase()}-${diff.toLowerCase()}.json', Json.stringify({
						song: {
							validScore: true,
							keyCount: 4,
							playerKeyCount: 4,
							chartOffset: 0.0,
							timescale: [4, 4],
							needsVoices: true,
							song: songName,
							bpm: 100,
							player1: 'bf',
							player2: 'dad',
							gf: 'gf',
							stage: 'stage',
							speed: 1,
							ui_Skin: 'default',
							notes: [
								{
									sectionNotes: [],
									lengthInSteps: 16,
									mustHitSection: true,
									bpm: 0.0,
									changeBPM: false,
									altAnim: false,
									timeScale: [0, 0],
									changeTimeScale: false
								}
							],
							specialAudioName: null,
							player3: null,
							modchartingTools: false,
							modchartPath: null,
							mania: null,
							gfVersion: null,
							events: [],
							endCutscene: '',
							cutscene: '',
							moveCamera: false,
							chartType: LEGACY
						}
					}, '\t'));
					PlayState.SONG = SongLoader.loadFromJson(diff, songName.toLowerCase(), mix);
					PlayState.instance = new PlayState();
					PlayState.isStoryMode = false;
					PlayState.songMultiplier = curSpeed;
					PlayState.storyDifficultyStr = diff.toUpperCase();

					PlayState.storyWeek = songs[curSelected].week;

					#if (target.threaded)
					stop_loading_songs = true;
					#end

					colorTween?.cancel();

					PlayState.loadChartEvents = true;
					destroyFreeplayVocals();
					FlxG.switchState(() -> new ChartingState());
					#end
				}
			}
			return;
		}
		PlayState.SONG = SongLoader.loadFromJson(diff, songName.toLowerCase(), mix);
		if (!Assets.exists(Paths.inst(PlayState.SONG.song, diff.toLowerCase(), mix))) {
			if (Assets.exists(Paths.inst(songName.toLowerCase(), diff.toLowerCase(), mix)))
				CoolUtil.coolError(PlayState.SONG.song.toLowerCase() + " (JSON) does not match " + songName + " (FREEPLAY)\nTry making them the same.",
					"Leather Engine's No Crash, We Help Fix Stuff Tool");
			else
				CoolUtil.coolError("Your song seems to not have an Inst.ogg, check the folder name in 'songs'!",
					"Leather Engine's No Crash, We Help Fix Stuff Tool");
			return;
		}
		PlayState.isStoryMode = false;
		PlayState.songMultiplier = curSpeed;
		PlayState.storyDifficultyStr = diff.toUpperCase();

		PlayState.storyWeek = songs[curSelected].week;

		#if (target.threaded)
		stop_loading_songs = true;
		#end

		colorTween?.cancel();

		PlayState.loadChartEvents = true;
		PlayState.chartingMode = false;
		destroyFreeplayVocals();
		FlxG.switchState(() -> new PlayState());
	}

	override function closeSubState() {
		if (!isResettingScore) {
			changeSelection();
		} else {
			if (songs.length != 0) {
				var curSong:FreeplaySong = songs[curSelected];
				intendedScore = Highscore.getScore(curSong.name, curDiffString);
				curRank = Highscore.getSongRank(curSong.name, curDiffString);
				diffText.text = "< " + curDiffString + " ~ " + curRank + " >";
			}
			isResettingScore = false;
		}
		FlxG.mouse.visible = false;
		super.closeSubState();
	}

	function changeDiff(change:Int = 0) {
		call("changeDiff", [change]);
		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, curDiffArray.length - 1);
		curDiffString = curDiffArray[curDifficulty].toUpperCase();

		if (songs.length != 0) {
			var curSong:FreeplaySong = songs[curSelected];
			intendedScore = Highscore.getScore(curSong.name, curDiffString);
			curRank = Highscore.getSongRank(curSong.name, curDiffString);
		}

		if (curDiffArray.length > 1)
			diffText.text = "< " + curDiffString + " ~ " + curRank + " >";
		else
			diffText.text = curDiffString + " ~ " + curRank + "  ";
		call("changeDiffPost", [change]);
	}

	function changeSelection(change:Int = 0) {
		call("changeSelection", [change]);

		if (grpSongs.length <= 0) {
			return;
		}

		curSelected = FlxMath.wrap(curSelected + change, 0, grpSongs.length - 1);

		// Sounds

		// Scroll Sound
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var curSong:FreeplaySong = songs[curSelected];

		var showStats:Bool = (curSong?.menuConfig?.showStats) ?? true;
		
		if (showStats) {
			var elements = [scoreBG, scoreText, diffText, speedText];
			var alphas = [0.6, 1, 1, 1];
			var targetXs = [FlxG.width - scoreBG.width - 6, FlxG.width - scoreText.width, FlxG.width - diffText.width, FlxG.width - speedText.width];
			
			for (i => element in elements) {
				element.visible = true;
				
				// 只有在刚进入state时才有渐变动画，切换曲目时直接设置位置
				if (change == 0) {
					// 初次进入：使用渐变动画
					element.x = FlxG.width + 50;
					element.alpha = 0;
					FlxTween.tween(element, {x: targetXs[i], alpha: alphas[i]}, 0.4, {ease: FlxEase.quadOut});
				} else {
					// 切换曲目：直接设置位置，无动画
					element.x = targetXs[i];
					element.alpha = alphas[i];
				}
			}
		} else {
			scoreBG.visible = scoreText.visible = diffText.visible = speedText.visible = false;
		}

		// Song Inst
		if (Options.getData("freeplayMusic") && curSelected >= 0) {
			FlxG.sound.playMusic(Paths.inst(curSong.name, curDiffString.toLowerCase()), 0.7);

			if (vocals != null && vocals.active && vocals.playing)
				destroyFreeplayVocals(false);
		}

		if (songs.length != 0) {
			intendedScore = Highscore.getScore(curSong.name, curDiffString);
			curRank = Highscore.getSongRank(curSong.name, curDiffString);
			curDiffArray = curSong.difficulties;
			changeDiff();
		}

		var bullShit:Int = 0;

		if (iconArray.length > 0) {
			for (icon in iconArray) {
				icon.alpha = 0.6;
				if (icon.animation.curAnim != null) icon.animation.play("neutral");
			}

			if (curSelected >= 0 && curSelected < iconArray.length) {
				var selectedIcon:HealthIcon = iconArray[curSelected];
				selectedIcon.alpha = 1;
				selectedIcon.animation.play("win");
			}
		}

		for (item in grpSongs.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0) {
				item.alpha = 1;
			}
		}

		if (change != 0 && songs.length != 0) {
			var newColor:FlxColor = FlxColor.fromString(curSong.color);

			if (newColor != selectedColor) {
				if (colorTween != null) {
					colorTween.cancel();
				}

				selectedColor = newColor;

				colorTween = FlxTween.color(bg, 0.25, bg.color, selectedColor, {
					onComplete: function(twn:FlxTween) {
						colorTween = null;
					}
				});
			}
		} else {
			if (songs.length != 0) {
				bg.color = FlxColor.fromString(curSong.color);
			}
		}
		canEnterSong = (curSong?.menuConfig?.canBeEntered) ?? true;
		call("changeSelectionPost", [change]);
	}

	public function destroyFreeplayVocals(?destroyInst:Bool = true) {
		call("destroyFreeplayVocals", [destroyInst]);
		if (vocals != null) {
			vocals.stop();
			vocals.destroy();
		}

		vocals = null;

		if (!destroyInst)
			return;

		if (FlxG.sound.music != null) {
			FlxG.sound.music.stop();
			FlxG.sound.music.destroy();
		}

		FlxG.sound.music = null;
		call("destroyFreeplayVocalsPost", [destroyInst]);
	}

	var scaleIcon:HealthIcon;

	override function beatHit() {
		call("beatHit");
		super.beatHit();

		if (lastSelectedSong >= 0 && scaleIcon != null)
			scaleIcon.scale.add(0.2 * scaleIcon.startSize, 0.2 * scaleIcon.startSize);
		call("beatHitPost");
	}
}
