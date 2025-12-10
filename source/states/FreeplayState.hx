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
	
	// 用于同时播放 Player 和 Opponent 音轨的引用
	public var playerVocals:FlxSound = null;
	public var opponentVocals:FlxSound = null;

	public var canEnterSong:Bool = true;
	public var isResettingScore:Bool = false; // 标志跟踪是否正在重置分数
	
	// thx psych engine devs
	public var colorTween:FlxTween;
	
	// pixel 风格 icon 动画相关变量
	public var isPixelStyle:Bool = false;
	public var pixelIconScaleTimer:Float = 0; // 动画计时器
	public var pixelIconScalePhase:Int = 0; // 动画阶段：0=无动画, 1-5=缩放阶段

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
		
		// 初始化音频信息显示
		audioInfoText = new FlxText(0, 0, 0, "", 16);
		audioInfoText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		audioInfoText.visible = false;
		audioInfoText.scrollFactor.set();
		
		audioInfoBG = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.BLACK);
		audioInfoBG.alpha = 0.6;
		audioInfoBG.visible = false;
		audioInfoBG.scrollFactor.set();
		
		add(audioInfoBG);
		add(audioInfoText);

		super.create();
		call("createPost");
	}

	public var mix:String = null;

	public var infoText:FlxText;
	public var infoBG:FlxSprite;
	
	// 音频信息显示相关
	public var audioInfoText:FlxText;
	public var audioInfoBG:FlxSprite;
	public var audioInfoVisible:Bool = false;
	public var lastPlayedSong:String = "";
	public var lastPlayedDifficulty:String = "";
	public var audioInfoTimer:FlxTimer;

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

		if (lastSelectedSong != -1 && scaleIcon != null) {
			if (isPixelStyle && pixelIconScalePhase > 0) {
				// Pixel 风格：五段式缩放动画
				pixelIconScaleTimer -= elapsed;
				
				if (pixelIconScaleTimer <= 0 && pixelIconScalePhase < 5) {
					// 缩放序列：1.3 -> 1.225 -> 1.15 -> 1.075 -> 1.0
					var scales:Array<Float> = [1.3, 1.225, 1.15, 1.075, 1.0];
					var scale:Float = scales[pixelIconScalePhase];
					scaleIcon.scale.set(scale * scaleIcon.startSize, scale * scaleIcon.startSize);
					
					pixelIconScalePhase++;
					if (pixelIconScalePhase >= 5) {
						// 动画结束
						pixelIconScaleTimer = 0;
						pixelIconScalePhase = 0;
					} else {
						// 继续下一阶段
						pixelIconScaleTimer = 0.05;
					}
				}
			} else if (!isPixelStyle) {
				// 非 pixel 风格：使用原始的 lerp 动画
				scaleIcon.scale.set(FlxMath.lerp(scaleIcon.scale.x, scaleIcon.startSize, elapsed * 9),
					FlxMath.lerp(scaleIcon.scale.y, scaleIcon.startSize, elapsed * 9));
			}
		}

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

				// 重置 pixel 状态
				isPixelStyle = false;
				pixelIconScaleTimer = 0;
				pixelIconScalePhase = 0;
				
				// 重置音频信息状态
				lastPlayedSong = "";
				lastPlayedDifficulty = "";
				hideAudioInfo();

				#if (target.threaded)
				stop_loading_songs = true;
				#end

				FlxG.switchState(() -> new MainMenuState());
			}

			var curSong:FreeplaySong = songs[curSelected];

			#if PRELOAD_ALL
			if (FlxG.keys.justPressed.SPACE) {
				var currentSong:String = curSong.name;
				var sameSongAndDifficulty:Bool = (currentSong == lastPlayedSong && curDiffString == lastPlayedDifficulty);
				
				// 如果不是相同曲目或难度，才销毁现有的音轨
				if (!sameSongAndDifficulty) {
					destroyFreeplayVocals();
				} else {
					// 相同曲目，只停止播放但不销毁UI元素
					destroyFreeplayVocalsWithoutUI();
				}

				// TODO: maybe change this idrc actually it seems ok now
				if (Assets.exists(SongLoader.getPath(curDiffString, curSong.name.toLowerCase(), mix))) {
					PlayState.SONG = SongLoader.loadFromJson(curDiffString, curSong.name.toLowerCase(), mix);
					Conductor.changeBPM(PlayState.SONG.bpm, curSpeed);
					
					// 检测 noteStyle 是否包含 pixel 字样
					isPixelStyle = false;
					// 检查 ui_Skin 字段（noteStyle 被转换到这里）
					if (PlayState.SONG.ui_Skin != null && PlayState.SONG.ui_Skin.toLowerCase().indexOf("pixel") != -1) {
						isPixelStyle = true;
						pixelIconScaleTimer = 0;
						pixelIconScalePhase = 0;
					}
				}

				var voicesDiff:String = (PlayState.SONG != null ? (PlayState.SONG.specialAudioName ?? curDiffString.toLowerCase()) : curDiffString.toLowerCase());
				
				// 扩展的人声检测逻辑：优先检测 Voices-Player 和 Voices-Opponent
				var playerVoicesPath:String = Paths.voices(curSong.name.toLowerCase(), voicesDiff, "player", mix ?? '');
				var opponentVoicesPath:String = Paths.voices(curSong.name.toLowerCase(), voicesDiff, "opponent", mix ?? '');
				var normalVoicesPath:String = Paths.voices(curSong.name.toLowerCase(), voicesDiff, mix ?? '');
				
				// 检测是否存在 Voices-Player 或 Voices-Opponent
				var playerExists:Bool = Assets.exists(playerVoicesPath);
				var opponentExists:Bool = Assets.exists(opponentVoicesPath);
				
				if (playerExists && opponentExists) {
					// 如果两者都存在，同时加载 Player 和 Opponent 人声
					FlxG.log.notice("检测到 Voices-Player 和 Voices-Opponent，同时加载两个音轨");
					
					// 创建两个独立的音轨并保存引用
					playerVocals = new FlxSound();
					opponentVocals = new FlxSound();
					
					playerVocals.loadEmbedded(playerVoicesPath);
					playerVocals.persist = false;
					playerVocals.looped = true;
					playerVocals.volume = 0.7;
					
					opponentVocals.loadEmbedded(opponentVoicesPath);
					opponentVocals.persist = false;
					opponentVocals.looped = true;
					opponentVocals.volume = 0.7;
					
					FlxG.sound.list.add(playerVocals);
					FlxG.sound.list.add(opponentVocals);
					
					// 使用现有的 vocals 变量作为主要引用，但实际上是 player vocals
					vocals = playerVocals;
				} else if (playerExists) {
					// 只有 Player 人声存在
					FlxG.log.notice("检测到 Voices-Player，加载 Player 人声: " + playerVoicesPath);
					playerVocals = new FlxSound();
					playerVocals.loadEmbedded(playerVoicesPath);
					playerVocals.persist = false;
					playerVocals.looped = true;
					playerVocals.volume = 0.7;
					FlxG.sound.list.add(playerVocals);
					vocals = playerVocals;
					opponentVocals = null;
				} else if (opponentExists) {
					// 只有 Opponent 人声存在
					FlxG.log.notice("检测到 Voices-Opponent，加载 Opponent 人声: " + opponentVoicesPath);
					opponentVocals = new FlxSound();
					opponentVocals.loadEmbedded(opponentVoicesPath);
					opponentVocals.persist = false;
					opponentVocals.looped = true;
					opponentVocals.volume = 0.7;
					FlxG.sound.list.add(opponentVocals);
					vocals = opponentVocals;
					playerVocals = null;
				} else {
					// 使用原始的 Voices 路径
					FlxG.log.notice("未检测到 Voices-Player/Opponent，使用原始 Voices 路径: " + normalVoicesPath);
					vocals = new FlxSound();
					if (Assets.exists(normalVoicesPath))
						vocals.loadEmbedded(normalVoicesPath);
					vocals.persist = false;
					vocals.looped = true;
					vocals.volume = 0.7;
					FlxG.sound.list.add(vocals);
					playerVocals = null;
					opponentVocals = null;
				}

				FlxG.sound.music = new FlxSound().loadEmbedded(Paths.inst(curSong.name.toLowerCase(), curDiffString.toLowerCase(), mix));
				FlxG.sound.music.persist = true;
				FlxG.sound.music.looped = true;
				FlxG.sound.music.volume = 0.7;

				FlxG.sound.list.add(FlxG.sound.music);

				FlxG.sound.music.play();
				
				// 播放音轨
				if (vocals != null) {
					vocals.play();
				}
				// 如果同时有 Player 和 Opponent 音轨，也需要播放 Opponent
				if (playerVocals != null && opponentVocals != null) {
					opponentVocals.play();
				}
				
				// 显示音频信息（只在曲目或难度不同时）
				if (!sameSongAndDifficulty) {
					var instPath:String = Paths.inst(curSong.name.toLowerCase(), curDiffString.toLowerCase(), mix);
					var voicePaths:Array<String> = [];
					
					if (playerExists && opponentExists) {
						voicePaths.push(playerVoicesPath);
						voicePaths.push(opponentVoicesPath);
					} else if (playerExists) {
						voicePaths.push(playerVoicesPath);
					} else if (opponentExists) {
						voicePaths.push(opponentVoicesPath);
					} else if (Assets.exists(normalVoicesPath)) {
						voicePaths.push(normalVoicesPath);
					}
					
					showAudioInfo(instPath, voicePaths, 4);
				}

				lastSelectedSong = curSelected;
				scaleIcon = iconArray[lastSelectedSong];
				
				// 延迟执行首拍缩放动画，等待音乐真正开始播放
				new FlxTimer().start(0.01, function(_) {
					if (scaleIcon != null) {
						if (isPixelStyle) {
							// Pixel 风格：开始五段式动画
							scaleIcon.scale.set(1.3 * scaleIcon.startSize, 1.3 * scaleIcon.startSize);
							pixelIconScaleTimer = 0.05;
							pixelIconScalePhase = 1;
						} else {
							// 非 pixel 风格：执行一次普通的缩放效果
							scaleIcon.scale.add(0.2 * scaleIcon.startSize, 0.2 * scaleIcon.startSize);
						}
					}
				});
			}
			#end

			if (FlxG.sound.music.active && FlxG.sound.music.playing && !FlxG.keys.justPressed.ENTER)
				FlxG.sound.music.pitch = curSpeed;
			
			// 对所有音轨应用 pitch 控制
			if (vocals != null && vocals.active && vocals.playing && !FlxG.keys.justPressed.ENTER)
				vocals.pitch = curSpeed;
			if (playerVocals != null && playerVocals.active && playerVocals.playing && !FlxG.keys.justPressed.ENTER)
				playerVocals.pitch = curSpeed;
			if (opponentVocals != null && opponentVocals.active && opponentVocals.playing && !FlxG.keys.justPressed.ENTER)
				opponentVocals.pitch = curSpeed;

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
		LoadingState.loadAndSwitchState(() -> new PlayState());
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
				
			// 切换歌曲时重置 pixel 状态
			isPixelStyle = false;
			pixelIconScaleTimer = 0;
			pixelIconScalePhase = 0;
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

	/**
	 * 显示音频信息
	 */
	public function showAudioInfo(instPath:String, voicePaths:Array<String>, delayBeats:Int = 4) {
		// 如果是同一首歌且同一难度，不重新显示，但确保信息保持可见
		var currentSong:String = songs[curSelected].name;
		if (currentSong == lastPlayedSong && curDiffString == lastPlayedDifficulty && audioInfoVisible) {
			return;
		}
		
		// 如果已有音频信息显示且是相同曲目，不要隐藏，直接返回
		if (audioInfoVisible && currentSong == lastPlayedSong && curDiffString == lastPlayedDifficulty) {
			return;
		}
		
		// 如果已有音频信息显示，先飞出
		if (audioInfoVisible) {
			hideAudioInfo(function() {
				// 延迟显示新信息
				showAudioInfoDelayed(instPath, voicePaths, delayBeats);
			});
		} else {
			showAudioInfoDelayed(instPath, voicePaths, delayBeats);
		}
		
		lastPlayedSong = currentSong;
		lastPlayedDifficulty = curDiffString;
	}
	
	/**
	 * 延迟显示音频信息
	 */
	private function showAudioInfoDelayed(instPath:String, voicePaths:Array<String>, delayBeats:Int) {
		// 计算延迟时间（基于BPM）
		var beatTime:Float = 60 / Conductor.bpm;
		var delay:Float = beatTime * delayBeats;
		
		// 构建音频信息文本 - 修复逻辑
		var instFileName:String = instPath.split('/').pop();
		var curSong:FreeplaySong = songs[curSelected];
		
		// 构建显示内容的各个部分
		var lines:Array<String> = [];
		lines.push("Song: " + curSong.name);
		lines.push("Diff: " + curDiffString.toUpperCase());
		
		// 添加箭头数量信息
		if (PlayState.SONG != null) {
			var playerNoteCount:Int = 0;
			var opponentNoteCount:Int = 0;
			
			// 构建轨道数量变化事件数组（完全复制 PlayState.generareNoteChangeEvents 逻辑）
			var maniaChanges:Array<Dynamic> = [];
			var allEvents:Array<Array<Dynamic>> = [];
			
			// 收集所有事件
			if (PlayState.SONG.events != null && PlayState.SONG.events.length > 0) {
				for (event in PlayState.SONG.events) {
					allEvents.push(event);
				}
			}
			
			// 尝试加载 songEvents 文件（类似 PlayState 的逻辑）
			var eventsPath:String = Paths.songEvents(PlayState.SONG.song.toLowerCase(), curDiffString.toLowerCase());
			if (Assets.exists(eventsPath)) {
				try {
					var eventFunnies:Array<Array<Dynamic>> = SongLoader.parseLegacy(Json.parse(Assets.getText(eventsPath)), PlayState.SONG.song).events;
					for (event in eventFunnies) {
						allEvents.push(event);
					}
				} catch (e:Dynamic) {
					FlxG.log.warn("Failed to load song events: " + e);
				}
			}
			
			// 提取轨道数量变化事件
			for (event in allEvents) {
				if (event[0].toLowerCase() == "change keycount" || event[0].toLowerCase() == "change mania") {
					// [事件时间, 玩家轨道数, 对手轨道数]
					maniaChanges.push([event[1], Std.parseInt(event[2]), Std.parseInt(event[3])]);
				}
			}
			
			// 按时间排序事件
			maniaChanges.sort((a, b) -> Std.int(a[0] - b[0]));
			
			// 遍历所有音符统计实际需要命中的箭头数
			for (section in PlayState.SONG.notes) {
				for (note in section.sectionNotes) {
					var noteStrumTime:Float = note[0];
					var noteData:Int = note[1];
					var noteLength:Float = note[2];
					var mustHit:Bool = section.mustHitSection;
					
					// 跳过事件音符
					if (noteData > -1) {
						// 获取当前时间的轨道数量（完全复制 PlayState.generateSong 逻辑）
						var currentParsingKeyCount:Int = PlayState.SONG.keyCount ?? 4;
						var currentParsingPlayerKeyCount:Int = PlayState.SONG.playerKeyCount ?? 4;
						
						// 应用轨道数量变化（找到最后一个符合条件的事件）
						for (mchange in maniaChanges) {
							if (noteStrumTime >= mchange[0]) {
								currentParsingKeyCount = mchange[2];
								currentParsingPlayerKeyCount = mchange[1];
							}
						}
						
						// 判断音符归属（完全复制 PlayState.generateSong 逻辑）
						var gottaHitNote:Bool = section.mustHitSection;
						
						if (noteData >= (!gottaHitNote ? currentParsingKeyCount : currentParsingPlayerKeyCount)) {
							gottaHitNote = !section.mustHitSection;
						}
						
						// 不考虑 characterPlayingAs，因为在 FreeplayState 中永远是 BF
						var isPlayerNote:Bool = gottaHitNote;
						
						// 统计箭头数量
						if (isPlayerNote) {
							playerNoteCount++;
						} else {
							opponentNoteCount++;
						}
					}
				}
			}
			
			lines.push("Notes: " + playerNoteCount + " (BF) | " + opponentNoteCount + " (Dad)");
		}
		
		lines.push("Inst: " + instFileName);
		
		// 添加人声音轨信息
		var hasPlayerVoices:Bool = false;
		var hasOpponentVoices:Bool = false;
		var hasNormalVoices:Bool = false;
		
		for (path in voicePaths) {
			var fileName:String = path.split('/').pop();
			if (fileName.indexOf("-player") != -1) {
				hasPlayerVoices = true;
			} else if (fileName.indexOf("-opponent") != -1) {
				hasOpponentVoices = true;
			} else {
				hasNormalVoices = true;
			}
		}
		
		// 根据分析结果添加人声信息
		if (hasPlayerVoices && hasOpponentVoices) {
			// 两个分离的人声音轨
			var playerFileName:String = "";
			var opponentFileName:String = "";
			
			for (path in voicePaths) {
				var fileName:String = path.split('/').pop();
				if (fileName.indexOf("-player") != -1) {
					playerFileName = fileName;
				} else if (fileName.indexOf("-opponent") != -1) {
					opponentFileName = fileName;
				}
			}
			
			lines.push("Vocal(BF): " + playerFileName);
			lines.push("Vocal(Dad): " + opponentFileName);
		} else if (hasPlayerVoices) {
			// 只有 Player 人声
			for (path in voicePaths) {
				var fileName:String = path.split('/').pop();
				if (fileName.indexOf("-player") != -1) {
					lines.push("Vocal(BF): " + fileName);
					break;
				}
			}
		} else if (hasOpponentVoices) {
			// 只有 Opponent 人声
			for (path in voicePaths) {
				var fileName:String = path.split('/').pop();
				if (fileName.indexOf("-opponent") != -1) {
					lines.push("Vocal(Dad): " + fileName);
					break;
				}
			}
		} else if (hasNormalVoices) {
			// 只有原始 Voices 人声
			for (path in voicePaths) {
				var fileName:String = path.split('/').pop();
				lines.push("Vocal: " + fileName);
				break;
			}
		}
		// 如果没有任何人声音轨，则不添加 Voice 行
		
		// 找出最长的行
		var maxLineLength:Int = 0;
		for (line in lines) {
			if (line.length > maxLineLength) {
				maxLineLength = line.length;
			}
		}
		
		// 计算需要的横线数量（最少3个，基于最长行长度）
		var dashCount:Int = Math.ceil((maxLineLength - 12) / 2); // " Player Info " 占12个字符
		if (dashCount < 3) dashCount = 3; // 最少3个横线
		
		// 构建最终文本
		var dashes:String = "";
		for (i in 0...dashCount) {
			dashes += "-";
		}
		var fullText:String = dashes + " Player Info " + dashes + "\n\n";
		fullText += lines.join("\n");

		
		audioInfoText.text = fullText;
		audioInfoText.alpha = 0;
		
		// 设置背景大小
		var textWidth:Float = audioInfoText.width + 20;
		var textHeight:Float = audioInfoText.height + 15;
		audioInfoBG.makeGraphic(Std.int(textWidth), Std.int(textHeight), FlxColor.BLACK);
		
		// 设置位置（右侧居中）
		var targetX:Float = FlxG.width - textWidth - 20;
		var targetY:Float = (FlxG.height - textHeight) / 2;
		
		audioInfoBG.x = targetX;
		audioInfoBG.y = targetY;
		audioInfoText.x = targetX + 10;
		audioInfoText.y = targetY + 7;
		
		// 初始位置在屏幕外
		audioInfoBG.x = FlxG.width + 50;
		audioInfoText.x = FlxG.width + 60;
		
		// 延迟后飞入
		audioInfoTimer = new FlxTimer().start(delay, function(_) {
			audioInfoBG.visible = true;
			audioInfoText.visible = true;
			audioInfoVisible = true;
			
			// 飞入动画
			FlxTween.tween(audioInfoBG, {x: targetX}, 0.5, {ease: FlxEase.quadOut});
			FlxTween.tween(audioInfoText, {x: targetX + 10}, 0.5, {ease: FlxEase.quadOut});
			FlxTween.tween(audioInfoBG, {alpha: 0.6}, 0.5);
			FlxTween.tween(audioInfoText, {alpha: 1}, 0.5);
		});
	}
	
	/**
	 * 隐藏音频信息
	 */
	public function hideAudioInfo(?onComplete:Void->Void) {
		if (!audioInfoVisible) {
			if (onComplete != null) onComplete();
			return;
		}
		
		// 飞出动画
		FlxTween.tween(audioInfoBG, {x: FlxG.width + 50}, 0.3, {
			ease: FlxEase.quadIn,
			onComplete: function(twn:FlxTween) {
				audioInfoBG.visible = false;
				if (onComplete != null) onComplete();
			}
		});
		FlxTween.tween(audioInfoText, {x: FlxG.width + 60}, 0.3, {
			ease: FlxEase.quadIn,
			onComplete: function(twn:FlxTween) {
				audioInfoText.visible = false;
				audioInfoVisible = false;
			}
		});
		FlxTween.tween(audioInfoBG, {alpha: 0}, 0.3);
		FlxTween.tween(audioInfoText, {alpha: 0}, 0.3);
		
		if (audioInfoTimer != null) {
			audioInfoTimer.cancel();
			audioInfoTimer = null;
		}
	}
	
	public function destroyFreeplayVocals(?destroyInst:Bool = true) {
		call("destroyFreeplayVocals", [destroyInst]);
		
		// 隐藏音频信息
		hideAudioInfo();
		
		destroyFreeplayVocalsWithoutUI(destroyInst);
		
		call("destroyFreeplayVocalsPost", [destroyInst]);
	}
	
	/**
	 * 销毁音轨但不影响UI元素（用于重新播放相同曲目）
	 */
	public function destroyFreeplayVocalsWithoutUI(?destroyInst:Bool = true) {
		// 销毁所有音轨
		if (vocals != null) {
			vocals.stop();
			vocals.destroy();
		}
		
		if (playerVocals != null && playerVocals != vocals) {
			playerVocals.stop();
			playerVocals.destroy();
		}
		
		if (opponentVocals != null && opponentVocals != vocals) {
			opponentVocals.stop();
			opponentVocals.destroy();
		}

		vocals = null;
		playerVocals = null;
		opponentVocals = null;

		if (!destroyInst)
			return;

		if (FlxG.sound.music != null) {
			FlxG.sound.music.stop();
			FlxG.sound.music.destroy();
		}

		FlxG.sound.music = null;
	}

	var scaleIcon:HealthIcon;

	override function beatHit() {
		call("beatHit");
		super.beatHit();

		if (lastSelectedSong >= 0 && scaleIcon != null) {
			if (isPixelStyle) {
				// Pixel 风格：每 beat 重新开始五段式动画
				scaleIcon.scale.set(1.3 * scaleIcon.startSize, 1.3 * scaleIcon.startSize);
				pixelIconScaleTimer = 0.05; // 0.05秒后进入下一阶段
				pixelIconScalePhase = 1; // 处于第一缩放阶段
			} else {
				// 原始效果：每次 beat 增加 0.2 倍
				scaleIcon.scale.add(0.2 * scaleIcon.startSize, 0.2 * scaleIcon.startSize);
			}
		}
		call("beatHitPost");
	}
}
