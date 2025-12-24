package states;

import game.Conductor;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.display.FlxBackdrop;
import flixel.input.keyboard.FlxKey;
import utilities.Options;
import utilities.CoolUtil;
import flixel.math.FlxMath;

/**
 * SongOffsetState - 歌曲偏移调整状态 (New WIP Version)
 * 提供完整的歌曲偏移调整功能，包括实时预览、精确调整等
 * 这是新版本的开发中功能，提供更高级的视觉反馈和调整体验
 */
class SongOffsetState extends MusicBeatState
{
	// UI元素
	private var bg:FlxSprite;
	private var titleText:FlxText;
	private var offsetText:FlxText;
	private var descriptionText:FlxText;
	private var instructionsText:FlxText;
	private var previewBar:FlxSprite;
	private var indicator:FlxSprite;
	
	// 偏移值相关
	private var currentOffset:Float = 0.0;
	private var displayOffset:Float = 0.0;
	private var targetOffset:Float = 0.0;
	
	// 调整精度
	private var adjustmentStep:Float = 0.1;
	private var fineAdjustmentStep:Float = 0.01;
	private var coarseAdjustmentStep:Float = 1.0;
	

	
	// BPM节拍同步和缩放控制
	private var bpm:Float = 112.0;
	private var lastBeat:Int = -1;
	private var backgroundZoom:Float = 1.0;
	private var targetBackgroundZoom:Float = 1.0;
	
	// 参考PlayState的缩放变量
	private var camZooming:Bool = true;
	private var cameraZoomStrength:Float = 1.0;
	private var cameraZoomRate:Float = 1.0;
	private var defaultZoom:Float = 1.0;
	private var zoomLerp:Float = 0.0;
	
	// 基于延迟设置的时间偏移缩放系统
	private var offsetBasedZoomStrength:Float = 1.0;
	private var offsetBasedZoomRate:Float = 1.0;
	private var delayedZoomTimer:Float = 0.0;
	private var scheduledZoomTime:Float = 0.0;
	private var zoomScheduled:Bool = false;
	
	// 控制变量
	private var canChangeOffset:Bool = true;
	private var lastChangeTime:Float = 0;
	private var changeDelay:Float = 0.05;
	
	override public function create():Void
	{
		super.create();
		
		// 初始化偏移值
		currentOffset = Options.getData("songOffset");
		displayOffset = currentOffset;
		targetOffset = currentOffset;
		
		// 初始化节拍跟踪
		lastBeat = -1;
		
		// 设置Conductor的BPM用于MusicBeatState系统
		Conductor.changeBPM(bpm);
		
		// 初始化缩放参数
		defaultZoom = 1.0;
		backgroundZoom = defaultZoom;
		
		// 创建UI
		setupBackground();
		setupUI();
		setupPreviewElements();
		
		// 设置初始位置
		updateUI();
		
		// 播放背景音乐（如果需要）
		playBgMusic();
	}
	
	private function setupBackground():Void
	{
		// 创建自定义背景
		//bg = new FlxBackdrop(Paths.image('BG_CityTown'));
        bg = new FlxSprite(0, 0).loadGraphic(Paths.gpuBitmap('BG_CityTown'));
		bg.antialiasing = Options.getData("antialiasing");
		bg.velocity.set(-20, -10); // 缓慢滚动背景
		bg.alpha = 0.8;
		bg.scrollFactor.set();
		add(bg);
		
		// 添加深色遮罩
		var darkBg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		darkBg.alpha = 0.3; // 减少透明度以显示背景
		darkBg.scrollFactor.set();
		add(darkBg);
	}
	
	private function setupUI():Void
	{
		// 标题文本 - 添加到类变量以便动画控制
		titleText = new FlxText(0, 50, 0, "SONG OFFSET (WIP)", 64);
		titleText.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.screenCenter(X);
		titleText.borderSize = 3;
		titleText.scrollFactor.set();
		add(titleText);
		
		// 主要偏移显示
		offsetText = new FlxText(0, 200, 0, "OFFSET: 0ms", 80);
		offsetText.setFormat(Paths.font("vcr.ttf"), 80, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		offsetText.screenCenter(X);
		offsetText.borderSize = 4;
		offsetText.scrollFactor.set();
		add(offsetText);
		
		// 描述文本
		descriptionText = new FlxText(50, 320, FlxG.width - 100, 
			"Advanced song offset adjustment with visual preview.\n\n" +
			"Positive values: Notes appear later\n" +
			"Negative values: Notes appear earlier\n\n" +
			"This NEW version provides enhanced visual feedback.", 24);
		descriptionText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		descriptionText.scrollFactor.set();
		descriptionText.borderSize = 2;
		add(descriptionText);
		
		// 操作说明
		instructionsText = new FlxText(50, FlxG.height - 180, FlxG.width - 100,
			"LEFT/RIGHT: Adjust by 0.1ms  |  SHIFT + LEFT/RIGHT: Adjust by 0.01ms\n" +
			"CTRL + LEFT/RIGHT: Adjust by 1ms  |  ENTER: Round to nearest ms\n" +
			"R: Refresh timing & delay  |  SPACE: Reset to 0  |  ESC/BACK: Save and exit", 20);
		instructionsText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.GRAY, CENTER, OUTLINE, FlxColor.BLACK);
		instructionsText.scrollFactor.set();
		instructionsText.borderSize = 1;
		add(instructionsText);
	}
	
	private function setupPreviewElements():Void
	{
		// 创建预览条
		previewBar = new FlxSprite(100, FlxG.height - 80).makeGraphic(FlxG.width - 200, 20, FlxColor.GRAY);
		previewBar.screenCenter(X);
		previewBar.scrollFactor.set();
		add(previewBar);
		
		// 创建指示器
		indicator = new FlxSprite(0, FlxG.height - 85).makeGraphic(10, 30, FlxColor.CYAN);
		indicator.scrollFactor.set();
		add(indicator);
		
		// 添加中心线
		var centerLine:FlxSprite = new FlxSprite(FlxG.width / 2 - 1, FlxG.height - 82).makeGraphic(2, 16, FlxColor.WHITE);
		centerLine.scrollFactor.set();
		add(centerLine);
	}
	
	private function playBgMusic():Void
	{
		// 播放自定义背景音乐
		FlxG.sound.playMusic(Paths.music('Barrier'), 0.7, true);
	}
	
	override public function update(elapsed:Float):Void
	{
        if (FlxG.sound.music.time >= FlxG.sound.music.length)
			Conductor.songPosition = FlxG.sound.music.length;
		else
			Conductor.songPosition = FlxG.sound.music.time;

		super.update(elapsed);
		
		// 更新动画
		updateAnimations(elapsed);
		
		// 处理输入
		handleInput();
		
		// 更新UI
		updateUI();
		
		// 更新指示器位置
		updateIndicator();
		
		// 控制变化频率
		if (!canChangeOffset && FlxG.game.ticks - lastChangeTime > changeDelay * 1000) {
			canChangeOffset = true;
		}
	}
	
	private function updateAnimations(elapsed:Float):Void
	{
		// 直接设置偏移值，移除动画效果
		displayOffset = targetOffset;
		
		// 参考PlayState的缩放逻辑
		zoomLerp = (elapsed * 3) * cameraZoomRate;
		
		// 处理延迟缩放计时器（整合零延迟和正延迟）
		if (zoomScheduled && displayOffset >= 0) {
			delayedZoomTimer += elapsed * 1000;
			if (delayedZoomTimer >= displayOffset) {
				executeDelayedZoom();
			}
		}
		
		// 平滑插值背景缩放至默认值
		if (camZooming) {
			backgroundZoom += (defaultZoom - backgroundZoom) * zoomLerp;
		} else {
			backgroundZoom = defaultZoom;
		}
		
		// 应用缩放
		bg.scale.x = backgroundZoom;
		bg.scale.y = backgroundZoom;
		bg.updateHitbox();
		bg.screenCenter();
	}
	
	private function handleInput():Void
	{
		// 返回/保存
		if (controls.BACK) {
			saveAndExit();
			return;
		}
		
		// R键刷新延迟和曲目进度
		if (FlxG.keys.justPressed.R) {
			refreshOffsetAndTiming();
			return;
		}
		
		// 重置
		if (FlxG.keys.justPressed.SPACE) {
			resetOffset();
			return;
		}
		
		// 取整
		if (FlxG.keys.justPressed.ENTER) {
			roundOffset();
			return;
		}
		
		if (!canChangeOffset) return;
		
		var step = adjustmentStep;
		var changed = false;
		
		// 根据修饰键确定调整步长
		if (FlxG.keys.pressed.SHIFT) {
			step = fineAdjustmentStep; // 0.01
		} else if (FlxG.keys.pressed.CONTROL) {
			step = coarseAdjustmentStep; // 1.0
		}
		
		// 左键减少
		if (FlxG.keys.pressed.LEFT) {
			targetOffset -= step;
			changed = true;
		}
		
		// 右键增加
		if (FlxG.keys.pressed.RIGHT) {
			targetOffset += step;
			changed = true;
		}
		
		if (changed) {
			// 限制范围（-500ms 到 500ms）
			targetOffset = Math.max(-500, Math.min(500, targetOffset));
			
			// 应用四舍五入到小数点后2位
			targetOffset = Math.round(targetOffset * 100) / 100;
			
			// 实时应用偏移
			currentOffset = targetOffset;
			Options.setData(currentOffset, "songOffset");
			Conductor.offset = currentOffset;
			
			// 播放调整音效
			playAdjustmentSound();
			
			// 设置冷却
			canChangeOffset = false;
			lastChangeTime = FlxG.game.ticks;
		}
	}
	
	private function updateUI():Void
	{
		// 更新偏移文本
		var offsetString = "OFFSET: ";
		var color = FlxColor.WHITE;
		
		if (displayOffset > 0) {
			offsetString += "+";
			color = FlxColor.CYAN;
		} else if (displayOffset < 0) {
			color = FlxColor.ORANGE;
		}
		
		offsetString += FlxMath.roundDecimal(displayOffset, 2) + "ms";
		
		offsetText.text = offsetString;
        offsetText.screenCenter(X);
		offsetText.color = color;
		

		
		// 移除节拍脉冲效果 - 标题和描述文本保持静态
		titleText.scale.x = 1.0;
		titleText.scale.y = 1.0;
		descriptionText.scale.x = 1.0;
		descriptionText.scale.y = 1.0;
		
		// 更新描述文本
		updateDescriptionText();
	}
	
	private function updateDescriptionText():Void
	{
		var absOffset = Math.abs(displayOffset);
		var description = "NEW WIP version - Enhanced visual feedback\n\n";
		description += "Current offset affects ";
		
		if (absOffset < 1) {
			description += "almost no difference in timing.\n";
			description += "This setting is very precise!";
		} else if (absOffset < 10) {
			description += "a small timing adjustment.\n";
			description += "Good for fine-tuning synchronization.";
		} else if (absOffset < 50) {
			description += "a moderate timing adjustment.\n";
			description += "Noticeable difference in note timing.";
		} else {
			description += "a large timing adjustment.\n";
			description += "Significant timing change - use with caution!";
		}
		
		description += "\n\n";
		description += "Visual preview: ";
		
		if (displayOffset > 0) {
			description += "Notes appear LATER than audio";
		} else if (displayOffset < 0) {
			description += "Notes appear EARLIER than audio";
		} else {
			description += "Perfect synchronization (theoretically)";
		}
		
		descriptionText.text = description;
	}
	
	private function updateIndicator():Void
	{
		// 更新指示器位置
		var barWidth = previewBar.width;
		var center = FlxG.width / 2;
		var maxOffset = 100; // 最大显示范围（±100ms）
		
		var indicatorX = center + (displayOffset / maxOffset) * (barWidth / 2);
		indicatorX = Math.max(100, Math.min(FlxG.width - 100 - indicator.width, indicatorX));
		
		indicator.x = indicatorX;
		
		// 更新指示器颜色
		if (Math.abs(displayOffset) < 5) {
			indicator.color = FlxColor.GREEN;
		} else if (Math.abs(displayOffset) < 20) {
			indicator.color = FlxColor.YELLOW;
		} else {
			indicator.color = FlxColor.RED;
		}
	}
	
	/**
	 * 根据当前延迟设置动态调整缩放参数
	 * 延迟越大，缩放效果越明显，帮助用户感知延迟的影响
	 */
	private function updateOffsetBasedZoomParameters():Void
	{
		var absOffset = Math.abs(displayOffset);
		
		// 基础缩放强度
		var baseStrength = 1.0;
		var baseRate = 1.0;
		
		if (absOffset <= 0.5) {
			// 接近完美同步：轻微效果
			offsetBasedZoomStrength = baseStrength * 0.3;
			offsetBasedZoomRate = baseRate * 0.5;
		} else if (absOffset <= 2.0) {
			// 轻微延迟：适中效果
			var factor = 0.3 + (absOffset - 0.5) / 1.5 * 0.4; // 0.3 -> 0.7
			offsetBasedZoomStrength = baseStrength * factor;
			offsetBasedZoomRate = baseRate * (0.5 + factor * 0.5);
		} else if (absOffset <= 10.0) {
			// 中等延迟：明显效果
			var factor = 0.7 + (absOffset - 2.0) / 8.0 * 0.3; // 0.7 -> 1.0
			offsetBasedZoomStrength = baseStrength * factor;
			offsetBasedZoomRate = baseRate * (1.0 + factor * 0.2);
		} else if (absOffset <= 25.0) {
			// 较大延迟：强烈效果
			var factor = 1.0 + (absOffset - 10.0) / 15.0 * 0.5; // 1.0 -> 1.5
			offsetBasedZoomStrength = baseStrength * factor;
			offsetBasedZoomRate = baseRate * (1.2 + (factor - 1.0) * 0.8);
		} else if (absOffset <= 50.0) {
			// 大延迟：非常强烈效果
			var factor = 1.5 + (absOffset - 25.0) / 25.0 * 0.5; // 1.5 -> 2.0
			offsetBasedZoomStrength = baseStrength * factor;
			offsetBasedZoomRate = baseRate * (1.6 + (factor - 1.5) * 0.8);
		} else {
			// 极大延迟：夸张效果
			var factor = 2.0 + Math.min(absOffset - 50.0, 100.0) / 100.0 * 1.0; // 2.0 -> 3.0
			offsetBasedZoomStrength = baseStrength * factor;
			offsetBasedZoomRate = baseRate * (2.0 + (factor - 2.0) * 0.5);
		}
		
		// 应用全局缩放强度设置（如果有的话）
		cameraZoomStrength = offsetBasedZoomStrength;
		cameraZoomRate = offsetBasedZoomRate;
	}
	

	
	/**
	 * 显示缩放的视觉反馈（整合零延迟和正延迟）
	 */
	private function showZoomFeedback():Void
	{
		var feedbackText:FlxText = new FlxText(0, 0, 0, "", 16);
		feedbackText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
		feedbackText.borderSize = 2;
		feedbackText.scrollFactor.set();
		feedbackText.screenCenter(X);
		feedbackText.y = offsetText.y + offsetText.height + 20;
		add(feedbackText);
		
		// 显示反馈信息
		var delayMs:Float = Math.abs(displayOffset);
		if (displayOffset > 0) {
			feedbackText.text = 'Delayed by +${FlxMath.roundDecimal(delayMs, 2)}ms';
		} else if (displayOffset < 0) {
			feedbackText.color = FlxColor.ORANGE;
			feedbackText.text = 'Early! (${FlxMath.roundDecimal(delayMs, 2)}ms)';
		} else {
			feedbackText.color = FlxColor.GREEN;
			feedbackText.text = 'Perfect timing!';
		}
		
		// 淡出动画
		FlxTween.tween(feedbackText, {
			alpha: 0,
			y: feedbackText.y - 20
		}, 0.8, {
			ease: FlxEase.circOut,
			onComplete: function(tween) {
				remove(feedbackText);
				feedbackText.destroy();
			}
		});
	}
	

	
	/**
	 * 执行延迟的缩放效果 - 仅影响背景，其他元素无视觉效果
	 */
	private function executeDelayedZoom():Void
	{
		// 修复：允许执行缩放即使zoomScheduled为false（负延迟情况）
		
		// 使用固定的缩放增量，与PlayState保持一致，不受延迟值影响
		var zoomIncrement = 0.015 * cameraZoomStrength; // 固定强度
		
		// 仅背景缩放
		backgroundZoom += zoomIncrement;
		
		// 重置所有延迟相关状态，防止叠加
		var wasScheduled = zoomScheduled;
		zoomScheduled = false;
		scheduledZoomTime = 0.0;
		delayedZoomTimer = 0.0;
		
		// 如果是计划的缩放，显示反馈
		if (wasScheduled) {
			showZoomFeedback();
		}
	}
	
	private function playAdjustmentSound():Void
	{
		// 移除音效播放，因为scrollMenu音效不存在
		// FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
	}
	
	private function resetOffset():Void
	{
		targetOffset = 0;
		currentOffset = 0;
		Options.setData(0, "songOffset");
		Conductor.offset = 0;
		
		FlxG.sound.play(Paths.sound('cancelMenu'), 0.5);
	}
	
	private function roundOffset():Void
	{
		targetOffset = Math.round(targetOffset);
		currentOffset = targetOffset;
		Options.setData(currentOffset, "songOffset");
		Conductor.offset = currentOffset;
		
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.5);
	}
	
	/**
	 * R键功能：刷新当前生效的延迟和曲目进度
	 */
	private function refreshOffsetAndTiming():Void
	{
		// 重置延迟系统状态
		zoomScheduled = false;
		scheduledZoomTime = 0.0;
		delayedZoomTimer = 0.0;
		
		// 重新同步Conductor
		if (FlxG.sound.music != null && FlxG.sound.music.playing) {
			Conductor.songPosition = FlxG.sound.music.time;
		}
		
		// 重新应用当前偏移设置
		Options.setData(currentOffset, "songOffset");
		Conductor.offset = currentOffset;
		
		// 重置背景缩放到默认值
		backgroundZoom = defaultZoom;
		
		// 播放确认音效
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.4);
		
		// 显示刷新反馈
		var refreshText:FlxText = new FlxText(0, 0, 0, "Timing Refreshed!", 24);
		refreshText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.GREEN, CENTER, OUTLINE, FlxColor.BLACK);
		refreshText.borderSize = 2;
		refreshText.scrollFactor.set();
		refreshText.screenCenter(X);
		refreshText.y = FlxG.height / 2 - 50;
		add(refreshText);
		
		// 淡出动画
		FlxTween.tween(refreshText, {
			alpha: 0,
			y: refreshText.y - 30
		}, 1.5, {
			ease: FlxEase.circOut,
			onComplete: function(tween) {
				remove(refreshText);
				refreshText.destroy();
			}
		});
	}
	
	private function saveAndExit():Void
	{
		// 确保数据已保存
		Options.setData(currentOffset, "songOffset");
		Conductor.offset = currentOffset;
		
		FlxG.sound.play(Paths.sound('cancelMenu'), 0.5);
		
		// 返回选项菜单
		FlxG.switchState(() -> new OptionsMenu());
	}
	
	// 重写beatHit函数来实现基于延迟的时间偏移缩放系统
	override public function beatHit():Void {
		super.beatHit();
		
		// 每拍都安排缩放，不受延迟值影响缩放强度
		if (camZooming 
			&& backgroundZoom < (1.35 * defaultZoom)
			&& curBeat % Math.max(1, Math.floor((Conductor.timeScale[0]) / cameraZoomRate)) == 0) {
			
			// 计算当前节拍的精确时间点（基于BPM）
			var currentBeatTime:Float = Conductor.songPosition;
			var delayOffsetMs:Float = displayOffset; // 使用当前设置的延迟值
			
			// 处理不同方向的延迟 - 整合零延迟和正延迟
			if (delayOffsetMs >= 0) {
				// 零延迟或正延迟：安排缩放（零延迟立即执行）
				if (delayOffsetMs == 0) {
					// 零延迟：立即执行
					executeDelayedZoom();
					showZoomFeedback();
				} else {
					// 正延迟：安排在未来执行
					scheduledZoomTime = currentBeatTime + delayOffsetMs;
					zoomScheduled = true;
					delayedZoomTimer = 0.0;
				}
			} else {
				// 负延迟：立即执行缩放
				executeDelayedZoom();
				
				// 只在每4拍或第一次时显示反馈
				if (curBeat % 4 == 0 || lastBeat == -1) {
					showZoomFeedback();
				}
			}
			
			// 更新最后触发的节拍
			lastBeat = curBeat;
		}
	}
}