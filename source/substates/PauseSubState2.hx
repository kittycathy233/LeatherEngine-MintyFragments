package substates;

import states.OptionsMenu;
import flixel.util.FlxStringUtil;
import flixel.FlxCamera;
import game.Conductor;
import states.FreeplayState;
import states.StoryMenuState;
import states.PlayState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.utils.Assets;
import openfl.geom.Rectangle;
import ui.Option;
import modding.helpers.FlxTweenUtil;
import spine.animation.AnimationStateData;
import spine.animation.AnimationState;
import spine.atlas.TextureAtlas;
import spine.SkeletonData;
import spine.flixel.SkeletonSprite;
import spine.flixel.FlixelTextureLoader;

using StringTools;

@:publicFields
class PauseSubState2 extends MusicBeatSubstate {
	var grpMenuShit:FlxTypedGroup<FlxText> = new FlxTypedGroup<FlxText>();

	var curSelected:Int = 0;

	// Spine: 清月角色实例
	var qingye:SkeletonSprite;

	// 倒计时相关变量
	var isCountingDown:Bool = false;
	var countdownTimer:FlxTimer;
	var preShakeTimer:FlxTimer;
	var countdownBeats:Int = 0;
	var maxCountdownBeats:Int = 3;
	var interruptionCount:Int = 0; // 打断次数计数器

	// Qingye 仇恨系统
	static var qingyeHoldingGrudge:Bool = false; // 是否记仇（跨暂停保存）
	static var totalInterruptions:Int = 0; // 总打断次数（跨暂停保存）
	static var qingyeHasPlayedFearAnimation:Bool = false; // 是否已播放过初始害怕动画
	static var shakeIsActive:Bool = false; // 抖动效果是否已激活（跨暂停保存）
	static var qingyeFeatureTriggered:Bool = false; // 是否已触发一次性特性
	
	// 管理员权限特性
	static var isRunningAsAdmin:Bool = false; // 是否以管理员权限运行

	// 重置qingye仇恨状态（新曲目时调用）
	public static function resetQingyeGrudge():Void {
		qingyeHoldingGrudge = false;
		totalInterruptions = 0;
		qingyeHasPlayedFearAnimation = false; // 重置害怕动画标记
		shakeIsActive = false; // 重置抖动状态
	}
	
	// 初始化管理员状态检测
	public static function initializeAdminStatus():Void {
		#if sys
		try {
			#if windows
			var process = new sys.io.Process('net', ['session']);
			var exitCode = process.exitCode();
			process.close();
			isRunningAsAdmin = exitCode == 0;
			#elseif linux
			var process = new sys.io.Process('id', ['-u']);
			var uid = StringTools.trim(process.stdout.readAll().toString());
			process.close();
			isRunningAsAdmin = uid == "0";
			#else
			isRunningAsAdmin = false;
			#end
		} catch (e:Dynamic) {
			isRunningAsAdmin = false;
		}
		#else
		isRunningAsAdmin = false;
		#end
	}

	// 倒计时显示相关
	var countdownText:FlxText;
	var originalMenuItems:Array<FlxText> = []; // 保存原始菜单项
	var menuItemsAreHidden:Bool = false;
	var resumeWasActiveThisPause:Bool = false; // 本次暂停期间是否曾触发 resume 倒计时
	var preShakePlayed:Bool = false; // 本次暂停是否已触发预抖动

	// Tween 管理系统
	var activeTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	var animationLock:Bool = false;

	var pauseCamera:FlxCamera = new FlxCamera();

	var menus:Map<String, Array<String>> = [
		"default" => ['Resume', 'Restart Song', 'Options', 'Exit To Menu'],
		"restart" => ['Back', 'No Cutscenes', 'With Cutscenes'],
	];

	var menu:String = "default";

	var pauseMusic:FlxSound = new FlxSound().loadEmbedded(Paths.music('breakfast'
		+ (Assets.exists(Paths.music('breakfast-' + PlayState.boyfriend.curCharacter, 'shared')) ? '-' + PlayState.boyfriend.curCharacter : ''),
		'shared'),
		true, true);

	var curTime:Float = Math.max(0, Conductor.songPosition);

	public function new() {
		super();

		// 预先检测管理员状态以避免在按键时执行阻塞操作
		initializeAdminStatus();

		// 从静态变量恢复中断次数
		interruptionCount = totalInterruptions;

		pauseCamera.bgColor.alpha = 0;
		FlxG.cameras.add(pauseCamera, false);

		var optionsArray = menus.get("default");

		if (PlayState.chartingMode) {
			optionsArray.insert(optionsArray.length - 1, "Skip Time");
			menus.set("default", optionsArray);
		}
		if (Options.getData("developer") && PlayState.isStoryMode) {
			optionsArray.insert(2, "Skip Song");
		}

		pauseMusic.volume = 0;
		pauseMusic.play();
		FlxG.sound.list.add(pauseMusic);

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		// 歌曲信息
		var levelInfo:FlxText = new FlxText(20, 15, 0, "", 32);
		levelInfo.text = PlayState.SONG.song;
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		levelInfo.updateHitbox();
		add(levelInfo);

		// 难度信息
		var levelDifficulty:FlxText = new FlxText(20, 15 + 32, 0, "", 24);
		levelDifficulty.text = PlayState.storyDifficultyStr.toUpperCase();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, RIGHT);
		levelDifficulty.updateHitbox();
		add(levelDifficulty);

		// BPM信息
		var levelBPM:FlxText = new FlxText(20, 15 + 32 + 28, 0, "", 20);
		levelBPM.text = "BPM: " + Math.round(Conductor.bpm);
		levelBPM.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.YELLOW, RIGHT);
		levelBPM.updateHitbox();
		add(levelBPM);

		// 时间信息
		var levelTime:FlxText = new FlxText(20, 15 + 32 + 28 + 24, 0, "", 18);
		var currentTime = FlxStringUtil.formatTime(Math.max(0, Math.floor(Conductor.songPosition / 1000)), false);
		var totalTime = FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false);
		levelTime.text = 'Time: $currentTime / $totalTime';
		levelTime.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.CYAN, RIGHT);
		levelTime.updateHitbox();
		add(levelTime);

		// 设置初始透明度为0
		levelDifficulty.alpha = 0;
		levelInfo.alpha = 0;
		levelBPM.alpha = 0;
		levelTime.alpha = 0;

		// 设置位置（右上角对齐）
		var rightMargin = 20;
		levelInfo.x = FlxG.width - (levelInfo.width + rightMargin);
		levelDifficulty.x = FlxG.width - (levelDifficulty.width + rightMargin);
		levelBPM.x = FlxG.width - (levelBPM.width + rightMargin);
		levelTime.x = FlxG.width - (levelTime.width + rightMargin);

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(levelBPM, {alpha: 1, y: levelBPM.y + 3}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.6});
		FlxTween.tween(levelTime, {alpha: 1, y: levelTime.y + 2}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});

		add(grpMenuShit);

		updateAlphabets();

		// 初始动画：菜单项从左侧飞入
		for (i in 0...grpMenuShit.members.length) {
			var item = grpMenuShit.members[i];
			var targetX = 100; // 目标X位置
			var targetY = FlxG.height - 250 + (45 * i); // 目标Y位置

			// 从左侧屏幕外开始飞入
			item.x = targetX - 400;
			item.y = targetY;
			item.alpha = 0;

			FlxTween.tween(item, {
				x: targetX,
				alpha: 1
			}, 0.4, {
				ease: FlxEase.backOut,
				startDelay: i * 0.05
			});
		}

		// 加载清月 Spine 角色
		loadQingye();
		shakeIsActive = false;

		cameras = [pauseCamera];
		if (PlayState.instance.usedLuaCameras)
			cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	var justPressedAcceptLol:Bool = true;

	var holdTime:Float = 0;

	public var MAX_MUSIC_VOLUME:Float = 0.5;
	public var MUSIC_INCREASE_SPEED:Float = 0.02;

	override function update(elapsed:Float) {
		if (pauseMusic.volume < MAX_MUSIC_VOLUME)
			pauseMusic.volume += MUSIC_INCREASE_SPEED * elapsed;

		super.update(elapsed);

		var upP = controls.UP_P;
		var downP = controls.DOWN_P;
		var accepted = controls.ACCEPT;

		// 如果正在倒计时，检查是否被打断
		if (isCountingDown) {
			if (!animationLock && ((upP || downP || (accepted && !justPressedAcceptLol)) || FlxG.keys.justPressed.ENTER)) {
				interruptCountdown();
			}
			return;
		}

		if (!accepted)
			justPressedAcceptLol = false;

		// 键盘选择
		if (upP)
			changeSelection(-1);
		if (downP)
			changeSelection(1);

		if (FlxG.keys.justPressed.F6) {
			PlayState.instance.toggleBotplay();
		}

		if (menus.get(menu)[curSelected].toLowerCase().contains("skip time")) {
			if (controls.LEFT_P) {
				curTime -= 1000;
				holdTime = 0;
				updateAlphabets(false);
			}
			if (controls.RIGHT_P) {
				curTime += 1000;
				holdTime = 0;
				updateAlphabets(false);
			}

			if (controls.LEFT || controls.RIGHT) {
				holdTime += elapsed;
				if (holdTime > 0.5) {
					curTime += 45000 * elapsed * (controls.LEFT ? -1 : 1);
				}

				if (curTime >= FlxG.sound.music.length)
					curTime -= FlxG.sound.music.length;
				else if (curTime < 0)
					curTime += FlxG.sound.music.length;
				updateAlphabets(false);
			}
		}

		if (accepted && !justPressedAcceptLol) {
			justPressedAcceptLol = true;

			var daSelected:String = menus.get(menu)[curSelected];

			switch (daSelected.toLowerCase()) {
				case "resume":
					if (!isCountingDown)
						startCountdown();
				case "restart song":
					menu = "restart";
					updateAlphabets();
				case "skip song":
					cleanupAndClose();
					PlayState.instance.endSong();
				case "no cutscenes":
					resetSongState();
					FlxG.resetState();
				case "with cutscenes":
					resetSongState();
					FlxG.resetState();
				case "skip time":
					if (curTime < Conductor.songPosition) {
						PlayState.startOnTime = curTime;
						resetSongState();
						FlxG.resetState();
					} else {
						if (curTime != Conductor.songPosition) {
							PlayState.instance.clearNotesBefore(curTime);
							PlayState.instance.setSongTime(curTime);
						}
						cleanupAndClose();
					}
				case "options":
					cleanupAndClose();
					FlxG.switchState(() -> new PauseOptions2());
					PlayState.chartingMode = false;
				case "back":
					menu = "default";
					updateAlphabets();
				case "exit to menu":
					cleanupAndClose();
					PlayState.chartingMode = false;


					qingyeHoldingGrudge = false;
					totalInterruptions = 0;
					qingyeHasPlayedFearAnimation = false;
					shakeIsActive = false;
					qingyeFeatureTriggered = false;

					if (PlayState.isStoryMode) {
						FlxG.switchState(() -> new StoryMenuState());
					} else {
						FlxG.switchState(() -> new FreeplayState());
					}
					PlayState.playingReplay = false;
			}
		}
	}

	// 加载清月 Spine 角色的方法
	function loadQingye():Void {
		try {
			var atlasPath = "assets/images/spine/CH0288_spr.atlas";
			var skelPath = "assets/images/spine/CH0288_spr.skel";
			var atlasFile = Assets.getText(atlasPath);
			var skeletonFile = Assets.getBytes(skelPath);
			var atlas = new TextureAtlas(atlasFile, new FlixelTextureLoader(atlasPath));
			var skeletonData = SkeletonData.from(skeletonFile, atlas, 0.8);
			var animationStateData = new AnimationStateData(skeletonData);

			qingye = new SkeletonSprite(skeletonData, animationStateData);
			
			// 根据是否记仇设置初始动画
			if (qingyeHoldingGrudge) {
				qingye.state.setAnimationByName(0, "04", true);
			} else {
				qingye.state.setAnimationByName(0, "03", true);
			}
			qingye.state.setAnimationByName(1, "Idle_01", true);

			qingye.scaleY = 0.5;
			qingye.scaleX = 0.5;

			// 设置初始位置在屏幕右上角外，准备飞入
			var targetX = FlxG.width - qingye.width + 100;
			var targetY = FlxG.height - qingye.height + (qingye.height / 3);

			// 如果记仇，初始Y轴位置偏下500
			if (qingyeHoldingGrudge) {
				qingye.y = targetY + 500;
			} else {
				qingye.y = FlxG.height - qingye.height + (qingye.height / 3) - 100;
			}
			
			qingye.x = FlxG.width + 200; // 从屏幕外右上角开始
			qingye.alpha = 0; // 初始透明度为0

			add(qingye); // 直接添加到 substate

			// 飞入动画
			if (qingyeHoldingGrudge) {
				// 记仇状态的特殊飞入动画
				FlxTween.tween(qingye, {
					x: targetX,
					y: targetY,
					alpha: 1
				}, 0.6, {
					ease: FlxEase.quartOut,
					startDelay: 0.2,
					onComplete: function(t:FlxTween) {
						// 管理员模式下qingye不害怕，但保持仇恨状态
						if (isRunningAsAdmin) {
							// 管理员模式：保持26动画（愤怒）而不是害怕动画
							qingye.state.setAnimationByName(0, "26", true);
							return;
						}
						
						// 检查是否已经播放过初始害怕动画
						if (!qingyeHasPlayedFearAnimation) {
							// 首次进入记仇状态：播放害怕动画序列
							qingye.state.setAnimationByName(0, "08", true);
							// 0.8秒后改为更害怕的动画并抖动
							new FlxTimer().start(0.8, function(tmr:FlxTimer) {
								qingye.state.setAnimationByName(0, "20", true);
								startFearShake();
								qingyeHasPlayedFearAnimation = true; // 标记已播放过
							});
						} else {
							// 之后的所有暂停：直接播放20动画
							qingye.state.setAnimationByName(0, "20", true);
							startFearShake();
						}
					}
				});
			} else {
				// 正常飞入动画
				FlxTween.tween(qingye, {
					x: targetX,
					y: targetY,
					alpha: 1
				}, 0.6, {
					ease: FlxEase.quartOut,
					startDelay: 0.2 // 稍微延迟，确保角色已加载
				});
			}
		} catch (e:Dynamic) {
			trace("Failed to load Qingye character: " + e);
			var placeholder = new FlxSprite(FlxG.width / 2 - 300, FlxG.height - 500);
			placeholder.makeGraphic(200, 300, FlxColor.BLUE);

			// 为占位符也添加飞入效果
			placeholder.x = FlxG.width + 200;
			add(placeholder);

			FlxTween.tween(placeholder, {
				x: FlxG.width / 2 - 300
			}, 0.5, {
				ease: FlxEase.quartOut,
				startDelay: 0.2
			});

			// placeholder 已经是 FlxSprite，qingye 保持为 null，后续代码会处理这种情况
		}
	}

	function updateAlphabets(?jump:Bool = true) {
		grpMenuShit.clear();
		originalMenuItems = [];

		for (i in 0...menus.get(menu).length) {
			var menuText:String;
			if (menus.get(menu)[i].toLowerCase().contains('skip time')) {
				menuText = "Skip Time "
					+ FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false)
					+ ' / '
					+ FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false);
			} else {
				menuText = menus.get(menu)[i];
			}

			// 确保菜单项位置正确，从左下角向上排列
			var targetX = 100;
			var targetY = FlxG.height - 250 + (45 * i);

			var songText:FlxText = new FlxText(targetX, targetY, 0, menuText);
			songText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, LEFT);
			songText.borderStyle = FlxTextBorderStyle.OUTLINE;
			songText.borderColor = FlxColor.BLACK;
			songText.borderSize = 2;

			grpMenuShit.add(songText);
			originalMenuItems.push(songText);
		}

		if (jump) {
			curSelected = 0;
			changeSelection();
		} else {
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
	}

	function changeSelection(change:Int = 0):Void {
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);

		curSelected += change;

		if (curSelected < 0)
			curSelected = menus.get(menu).length - 1;
		if (curSelected >= menus.get(menu).length)
			curSelected = 0;

		for (i in 0...grpMenuShit.members.length) {
			var item = grpMenuShit.members[i];

			// 确保菜单项位置正确
			var targetY = FlxG.height - 250 + (45 * i);
			if (item.y != targetY) {
				item.y = targetY;
			}

			if (i == curSelected) {
				item.alpha = 1;
				item.color = FlxColor.YELLOW;
			} else {
				item.alpha = 0.7;
				item.color = FlxColor.WHITE;
			}
		}
	}

	// Tween 管理辅助函数
	function startTween(id:String, target:Dynamic, values:Dynamic, duration:Float, ?options:Dynamic):FlxTween {
		cancelTween(id);
		
		var onComplete = function(t:FlxTween) {
			activeTweens.remove(id);
		};
		
		if (options != null && Reflect.hasField(options, "onComplete")) {
			var originalOnComplete = Reflect.field(options, "onComplete");
			onComplete = function(t:FlxTween) {
				activeTweens.remove(id);
				if (originalOnComplete != null) {
					Reflect.callMethod(null, originalOnComplete, [t]);
				}
			};
		}
		
		var finalOptions = options != null ? options : {};
		Reflect.setField(finalOptions, "onComplete", onComplete);
		
		var tween = FlxTween.tween(target, values, duration, finalOptions);
		activeTweens.set(id, tween);
		return tween;
	}

	function cancelTween(id:String):Void {
		if (activeTweens.exists(id)) {
			var tween = activeTweens.get(id);
			if (tween != null && tween.active) {
				tween.cancel();
				tween.destroy();
			}
			activeTweens.remove(id);
		}
	}

	function cancelAllTweens():Void {
		for (id in activeTweens.keys()) {
			cancelTween(id);
		}
	}

	function cancelMenuTweens():Void {
		var idsToRemove:Array<String> = [];
		for (id in activeTweens.keys()) {
			if (!id.startsWith("countdown")) {
				idsToRemove.push(id);
			}
		}
		for (id in idsToRemove) {
			cancelTween(id);
		}
	}

	function setAnimationLock(locked:Bool):Void {
		animationLock = locked;
	}

	// 开始倒计时
	function startCountdown():Void {
		isCountingDown = true;
		// 标记本次暂停由 resume 引起的倒计时
		resumeWasActiveThisPause = true;
		countdownBeats = 0;
		
		// 确保清理任何现有的倒计时文本
		if (countdownText != null) {
			remove(countdownText);
			countdownText.destroy();
			countdownText = null;
		}
		
		// 预先创建倒计时文本（初始不可见）
		precreateCountdownText();
		
		// 飞出所有元素
		flyOutMenuItems();
		
		// 延迟0.2秒后开始显示文本并倒计时
		new FlxTimer().start(0.1, function(tmr:FlxTimer) {
			if (countdownText != null) {
		setAnimationLock(true);
		startTween("countdown_fadein", countdownText, {alpha: 1}, 0.3, {
			ease: FlxEase.quartOut,
			onComplete: function(t:FlxTween) {
				setAnimationLock(false);
				startCountdownTimer();
			}
		});
			}
		});
		
		menuItemsAreHidden = true;
	}

	// 打断倒计时
	function interruptCountdown():Void {
		if (!isCountingDown)
			return;

		// 检查动画锁，防止在动画进行时打断
		if (animationLock) {
			return;
		}

		isCountingDown = false;
		// 本次 resume 倒计时已被打断
		resumeWasActiveThisPause = false;

		// 取消预抖动计时器（如果存在）
		if (preShakeTimer != null) {
			try { preShakeTimer.cancel(); preShakeTimer.destroy(); } catch(e:Dynamic) {}
			preShakeTimer = null;
		}

		if (countdownTimer != null) {
			try {
				countdownTimer.cancel();
				countdownTimer.destroy();
			} catch (e:Dynamic) {
				trace("Error destroying countdownTimer: " + e);
			}
			countdownTimer = null;
		}

		if (countdownText != null) {
			setAnimationLock(true);
			cancelTween("countdown_fadein");

			// 生成-5到5度的随机角度
			var randomAngle = FlxG.random.float(-5, 5);
			
			// 如果超过15次打断，修改文本和颜色
			startTween("countdown_interrupt", countdownText, {
				y: countdownText.y + 60,
				angle: randomAngle,
				alpha: 0
			}, 0.7, {
				ease: FlxEase.quadIn,
				onComplete: function(t:FlxTween) {
					setAnimationLock(false);
				}
			});
			
			flyBackMenuItems();
		} else {
			setAnimationLock(false);
			flyBackMenuItems();
		}

		interruptionCount++;
		totalInterruptions++; // 更新总中断次数

		if (interruptionCount == 1) 		qingye.state.setAnimationByName(0, "00", true);
		else if (interruptionCount == 3) 	qingye.state.setAnimationByName(0, "04", true);
		else if (interruptionCount == 5) 	qingye.state.setAnimationByName(0, "05", true);
		else if (interruptionCount == 8) 	qingye.state.setAnimationByName(0, "06", true);
		else if (interruptionCount == 12) 	qingye.state.setAnimationByName(0, "15", true);
		else if (interruptionCount == 15) {
			qingye.state.setAnimationByName(0, "26", true);
			// 达到15次时，启用记仇状态
			qingyeHoldingGrudge = true;
			// 尝试触发一次性特性（仅当本次暂停触发过 resume 倒计时且非管理员）
			tryTriggerQingyeFeature();
		}
		else if (interruptionCount >= 30 && !qingyeHasPlayedFearAnimation) {
			qingye.state.setAnimationByName(0, "27", true);
			if (!shakeIsActive) {
				startShakeAnimation();
				shakeIsActive = true;
			}
		}

		if (interruptionCount >= 15) {
			countdownText.text = "RESUME INTERRUPTED " + interruptionCount + " TIMES...";
			countdownText.screenCenter(X);
			countdownText.color = FlxColor.RED;
		} else {
			countdownText.text = "RESUME INTERRUPTED..";
			countdownText.screenCenter(X);
		}

		menuItemsAreHidden = false;
	}

	// 清理并关闭暂停菜单
	function cleanupAndClose():Void {
		// 清理所有tween
		cancelAllTweens();

		// 清理定时器
		if (countdownTimer != null) {
			try {
				countdownTimer.cancel();
				countdownTimer.destroy();
			} catch (e:Dynamic) {
				trace("Error destroying countdownTimer: " + e);
			}
			countdownTimer = null;
		}

		pauseMusic.stop();
		pauseMusic.destroy();
		FlxG.sound.list.remove(pauseMusic);
		FlxG.cameras.remove(pauseCamera);
		PlayState.instance.call("onResume", []);
		#if LUA_ALLOWED
		for (tween in modding.scripts.languages.LuaScript.lua_Tweens) {
			FlxTweenUtil.resumeTween(tween);
		}
		#end
		close();
	}

	// 重置歌曲状态
	function resetSongState():Void {
		PlayState.SONG.speed = PlayState.previousScrollSpeed;
		PlayState.playCutscenes = true;
		PlayState.SONG.keyCount = PlayState.instance.ogKeyCount;
		PlayState.SONG.playerKeyCount = PlayState.instance.ogPlayerKeyCount;
	}

	// 飞出菜单项（与清月同步）
	function flyOutMenuItems():Void {
		setAnimationLock(true);
		cancelAllTweens();

		for (i in 0...originalMenuItems.length) {
			var item = originalMenuItems[i];
			startTween("menuItem_" + i, item, {
				x: item.x - 600,
				y: item.y - 50,
				alpha: 0
			}, 0.45, {
				ease: FlxEase.quartOut,
				startDelay: i * 0.03
			});
		}

		if (qingye != null && !qingyeHoldingGrudge && interruptionCount < 15) {
			startTween("qingye_flyout", qingye, {
				x: qingye.x + 400,
				y: qingye.y - 80,
				alpha: 0
			}, 0.45, {
				ease: FlxEase.quartOut
			});
		}

		new FlxTimer().start(0.5, function(tmr:FlxTimer) {
			setAnimationLock(false);
		});
	}

	// 飞回菜单项（与清月同步）
	function flyBackMenuItems():Void {
		var needsLock = !animationLock;
		if (needsLock) setAnimationLock(true);

		cancelMenuTweens();

		for (i in 0...originalMenuItems.length) {
			var item = originalMenuItems[i];
			var targetX = 100;
			var targetY = FlxG.height - 250 + (45 * i);

			item.x = targetX - 600;
			item.y = targetY - 50;
			item.alpha = 0;
			item.color = FlxColor.WHITE;

			startTween("menuItem_" + i, item, {
				x: targetX,
				y: targetY,
				alpha: i == curSelected ? 1.0 : 0.7
			}, 0.4, {
				ease: FlxEase.quartOut,
				startDelay: i * 0.03
			});
		}

		if (qingye != null && !qingyeHoldingGrudge && interruptionCount < 15) {
			var targetX = FlxG.width - qingye.width + 100;
			var targetY = FlxG.height - qingye.height + (qingye.height / 3) - 100;

			qingye.x = targetX + 400;
			qingye.alpha = 0;
			qingye.y = targetY;
			
			startTween("qingye_flyback1", qingye, {
				x: targetX,
				y: targetY + 100,
				alpha: 1
			}, 0.4, {
				ease: FlxEase.quartOut
			});
		}

		if (needsLock) {
			new FlxTimer().start(0.5 + (originalMenuItems.length * 0.03), function(tmr:FlxTimer) {
				setAnimationLock(false);
			});
		}
	}

	// 预先创建倒计时文本（初始不可见）
	function precreateCountdownText():Void {
		try {
			var remaining = maxCountdownBeats;
			countdownText = new FlxText(0, 0, 0, "RESUME IN " + remaining, 64);
			countdownText.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
			countdownText.screenCenter();
			countdownText.alpha = 0; // 初始不可见
			add(countdownText);
		} catch (e:Dynamic) {
			trace("Error creating countdown text: " + e);
			countdownText = null;
		}
	}

	// 开始倒计时定时器
	function startCountdownTimer():Void {
		if (countdownText != null && countdownTimer == null) {
			updateCountdownText();
			
			// 基于BPM的倒计时
			var beatTime = (60.0 / Conductor.bpm) * 1000; // 转换为毫秒
			
			countdownTimer = new FlxTimer().start(beatTime / 1000, function(tmr:FlxTimer) {
				if (!isCountingDown) {
					// 如果倒计时被打断，停止timer
					tmr.cancel();
					return;
				}
				
				countdownBeats++;
				updateCountdownText();
				
				if (countdownBeats >= maxCountdownBeats) {
					// 倒计时结束，恢复游戏
					finishResume();
				} else if (isCountingDown) {
					// 继续下一次倒计时
					tmr.reset();
				}
			}, maxCountdownBeats);

			// 预抖动：在离结束约0.4拍时触发一次（用于害怕抖动并切换到21动画）
			try {
				if (preShakeTimer != null) {
					preShakeTimer.cancel(); preShakeTimer.destroy();
					preShakeTimer = null;
				}
				var preShakeDelaySec:Float = Math.max(0, ((maxCountdownBeats - 0.4) * beatTime) / 1000.0);
				preShakeTimer = new FlxTimer().start(preShakeDelaySec, function(pt:FlxTimer) {
					preShakeTimer = null;
					if (!isCountingDown) return;
					if (!isRunningAsAdmin && !qingyeFeatureTriggered && qingye != null && resumeWasActiveThisPause) {
						startFearShake();
						try { qingye.state.setAnimationByName(0, "21", true); } catch(e:Dynamic) {}
						preShakePlayed = true;
					}
				});
			} catch(e:Dynamic) {
				preShakeTimer = null;
			}
		}
	}

	// 更新倒计时文本
	function updateCountdownText():Void {
		if (countdownText != null) {
			if (countdownBeats >= maxCountdownBeats) {
				countdownText.text = "GO!";
				countdownText.color = FlxColor.GREEN;
			} else {
				var remaining = maxCountdownBeats - countdownBeats;
				countdownText.text = "RESUME IN " + remaining;
			}
		}
	}

	// 抖动效果（通用函数）
	function startShake(isAngry:Bool = false):Void {
		if (qingye == null) return;
		
		var originalX = qingye.x;
		var maxShakes = isAngry ? 12 : 14;
		var shakeIntensity = isAngry ? 15 : 4;
		var shakeSpeed = 0.02;
		var shakeCount = 0;
		
		var shakeTimer = new FlxTimer().start(shakeSpeed, function(tmr:FlxTimer) {
			if (shakeCount >= maxShakes) {
				FlxTween.tween(qingye, {x: originalX}, 0.3, {
					ease: FlxEase.quartOut
				});
				return;
			}
			
			var direction = (shakeCount % 2 == 0) ? 1 : -1;
			qingye.x = originalX + (shakeIntensity * direction);
			
			if (isAngry && shakeCount > 4) {
				shakeIntensity = Math.round(shakeIntensity * 0.8);
			}
			
			shakeCount++;
			tmr.reset(shakeSpeed);
		}, maxShakes);
	}

	// 快速左右抖动效果（生气）
	function startShakeAnimation():Void {
		startShake(true);
	}

	// 害怕时的小幅度颤抖效果
	function startFearShake():Void {
		startShake(false);
	}

	// 尝试触发清月的一次性特性（只对非管理员且只触发一次）
	function tryTriggerQingyeFeature():Void {
		if (qingyeFeatureTriggered) return;
		if (isRunningAsAdmin) return;
		// 要求本次暂停有触发 resume 的倒计时或发生了预抖动
		if (!preShakePlayed && !resumeWasActiveThisPause) return;
		// 仅在总打断次数达到阈值时触发（或当前打断达到阈值）
		if (totalInterruptions >= 15 || interruptionCount >= 15) {
			try {
				// 播放更剧烈的抖动作为特性表现
				startShakeAnimation();
				// 确保表现只发生一次
				qingyeFeatureTriggered = true;
				// 将记仇状态保持（若尚未）
				qingyeHoldingGrudge = true;
			} catch (e:Dynamic) {
				trace("Error triggering Qingye feature: " + e);
			}
		}
	}

	// 完成恢复流程
	function finishResume():Void {
		isCountingDown = false;

		if (countdownTimer != null) {
			try {
				countdownTimer.cancel();
				countdownTimer.destroy();
			} catch (e:Dynamic) {
				trace("Error destroying countdownTimer: " + e);
			}
			countdownTimer = null;
		}

		// 立即清理倒计时文本，防止叠加显示
		if (countdownText != null) {
			// 取消可能存在的任何倒计时文本tween
			try {
				cancelTween("countdown_interrupt");
				cancelTween("countdown_fadein");
			} catch (e:Dynamic) {
				trace("Error cancelling countdown text tweens: " + e);
			}

			// 直接移除文本
			remove(countdownText);
			countdownText.destroy();
			countdownText = null;
		}

		// 取消预抖动计时器（如果存在）
		if (preShakeTimer != null) {
			try { preShakeTimer.cancel(); preShakeTimer.destroy(); } catch(e:Dynamic) {}
			preShakeTimer = null;
		}

		// 标记本次 resume 流程结束
		resumeWasActiveThisPause = false;
		preShakePlayed = false;

		// 在恢复前尝试触发一次性特性（若此前已播放过预抖动并且达成阈值）
		tryTriggerQingyeFeature();

		cleanupAndClose();
	}
}

class PauseOptions2 extends OptionsMenu {
	override public function goBack() {
		if (pageName != "Categories") {
			loadPage(cast(page.members[0], PageOption).pageName);
			return;
		}

		FlxG.switchState(() -> new PlayState());
	}
}
