package ui;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import utilities.Options;

/**
 * 实时延迟显示组件
 * 类似其他音游的判定条，显示当前曲目的判定延迟情况
 * 采用HORIZONTAL_INSIDE_OUT样式（从内向外颜色渐变）
 */
class RealtimeDelayGraph extends FlxSpriteGroup {
	/**
	 * 图表宽度
	 */
	static inline final GRAPH_WIDTH:Int = 300;
	
	/**
	 * 图表高度
	 */
	static inline final GRAPH_HEIGHT:Int = 6;
	
	/**
	 * 中心线位置
	 */
	static inline final CENTER_X:Int = Std.int(GRAPH_WIDTH / 2);
	
	/**
	 * 判定条宽度
	 */
	public static inline final BAR_WIDTH:Int = 4;
	
	/**
	 * 判定条显示时间（秒）
	 */
	static inline final BAR_LIFETIME:Float = 2.0;
	
	/**
	 * 判定时间设置
	 */
	var timings:Map<String, Float>;
	
	/**
	 * 活跃的判定条数组
	 */
	var activeBars:Array<JudgementBar> = [];
	
	/**
	 * 背景层
	 */
	var bgSprite:FlxSprite;
	
	/**
	 * 判定区域层
	 */
	var judgementZones:FlxSpriteGroup;
	
	/**
	 * 判定条层
	 */
	var barsLayer:FlxSpriteGroup;
	
	/**
	 * 构造函数
	 * @param x X坐标
	 * @param y Y坐标
	 */
	public function new(x:Float, y:Float) {
		super(x, y);
		
		// 设置整体不透明度为0.7
		this.alpha = 0.7;
		
		// 加载判定设置
		updateJudgementTimings();
		
		// 创建背景
		bgSprite = new FlxSprite(0, 0);
		bgSprite.makeGraphic(GRAPH_WIDTH, GRAPH_HEIGHT, FlxColor.fromRGB(40, 40, 40));
		add(bgSprite);
		
		// 创建判定区域层
		judgementZones = new FlxSpriteGroup();
		createJudgementZones();
		add(judgementZones);
		
		// 创建判定条层
		barsLayer = new FlxSpriteGroup();
		add(barsLayer);
		
		// 设置相机
		scrollFactor.set();
	}
	
	/**
	 * 创建判定区域（HORIZONTAL_INSIDE_OUT样式）
	 * 创建多个独立的颜色条，实现真正的多彩效果
	 */
	private function createJudgementZones():Void {
		// 获取判定时间数组，与NoteGraph保持一致
		var judgementTimings:Array<Int> = Options.getData("judgementTimings");
		var maxTime = 166.0; // 与NoteGraph的MAX_MS保持一致
		
		// 计算每毫秒对应的像素数
		var pixelsPerMs = CENTER_X / maxTime;
		
		// 创建多层独立的颜色条，从外到内叠加
		// 这样可以创建更丰富的颜色层次
		
		// 最外层 - Shit区域（红色）
		var shitWidth = Std.int(maxTime * pixelsPerMs);
		createZoneLayer(0, shitWidth * 2, FlxColor.fromRGB(255, 100, 100), 0.4);
		
		// Bad区域（橙黄色）
		var badWidth = Std.int(judgementTimings[3] * pixelsPerMs);
		createZoneLayer(CENTER_X - badWidth, badWidth * 2, FlxColor.fromRGB(255, 165, 0), 0.5);
		
		// Good区域（绿色）
		var goodWidth = Std.int(judgementTimings[2] * pixelsPerMs);
		createZoneLayer(CENTER_X - goodWidth, goodWidth * 2, FlxColor.fromRGB(144, 238, 144), 0.6);
		
		// Sick区域（天蓝色）
		var sickWidth = Std.int(judgementTimings[1] * pixelsPerMs);
		createZoneLayer(CENTER_X - sickWidth, sickWidth * 2, FlxColor.fromRGB(135, 206, 235), 0.7);
		
		// Marvelous区域（粉色）
		var marvelousWidth = Std.int(judgementTimings[0] * pixelsPerMs);
		createZoneLayer(CENTER_X - marvelousWidth, marvelousWidth * 2, FlxColor.fromRGB(255, 182, 193), 0.8);
		
		// 添加中心线（Perfect判定线）
		var centerLine = new FlxSprite(CENTER_X - 1, 0);
		centerLine.makeGraphic(2, GRAPH_HEIGHT, FlxColor.WHITE);
		centerLine.alpha = 0.9;
		judgementZones.add(centerLine);
	}
	
	/**
	 * 创建单个判定区域层
	 * @param x X坐标
	 * @param width 宽度
	 * @param color 颜色
	 * @param alpha 透明度
	 */
	private function createZoneLayer(x:Float, width:Int, color:FlxColor, alpha:Float):Void {
		var zoneSprite = new FlxSprite(x, 0);
		zoneSprite.makeGraphic(width, GRAPH_HEIGHT, color);
		zoneSprite.alpha = alpha;
		judgementZones.add(zoneSprite);
	}
	
	/**
	 * 添加延迟条显示
	 * @param delay 延迟值（毫秒，正数表示晚，负数表示早）
	 * @param strumTime 音符时间
	 * @param songLength 歌曲长度
	 */
	public function addDelayBar(delay:Float, strumTime:Float, songLength:Float):Void {
		// 计算像素偏移（基于判定时间范围）
		var pixelOffset = calculatePixelOffset(delay);
		
		// 如果超出范围则跳过
		if (Math.abs(pixelOffset) > CENTER_X) {
			return;
		}
		
		// 创建新的判定条
		var bar:JudgementBar = new JudgementBar(CENTER_X + pixelOffset - Std.int(BAR_WIDTH/2), 0, GRAPH_HEIGHT);
		activeBars.push(bar);
		barsLayer.add(bar);
		
		// 设置渐隐动画
		FlxTween.tween(bar, {alpha: 0}, BAR_LIFETIME, {
			ease: FlxEase.quadOut,
			onComplete: function(tween:FlxTween) {
				removeBar(bar);
			}
		});
	}
	
	/**
	 * 计算像素偏移
	 * @param delay 延迟时间（毫秒）
	 * @return 像素偏移值
	 */
	private function calculatePixelOffset(delay:Float):Int {
		var maxTime = 166.0; // 与NoteGraph的MAX_MS保持一致
		var pixelsPerMs = CENTER_X / maxTime;
		return Math.round(delay * pixelsPerMs);
	}
	
	/**
	 * 移除判定条
	 * @param bar 要移除的判定条
	 */
	private function removeBar(bar:JudgementBar):Void {
		activeBars.remove(bar);
		barsLayer.remove(bar);
		bar.destroy();
	}
	
	/**
	 * 更新判定时间设置
	 */
	private function updateJudgementTimings():Void {
		timings = [
			"marvelous" => Options.getData("judgementTimings").marvelous,
			"sick" => Options.getData("judgementTimings").sick,
			"good" => Options.getData("judgementTimings").good,
			"bad" => Options.getData("judgementTimings").bad,
			"shit" => Options.getData("judgementTimings").shit
		];
	}
	
	/**
	 * 清理所有判定条
	 */
	public function clearAllBars():Void {
		for (bar in activeBars) {
			FlxTween.cancelTweensOf(bar);
			removeBar(bar);
		}
		activeBars = [];
	}
	
	override function update(elapsed:Float):Void {
		super.update(elapsed);
		
		// 检查判定设置是否改变
		// 这里可以添加设置变化的检测逻辑
	}
	
	override function destroy():Void {
		clearAllBars();
		super.destroy();
	}
}

/**
 * 判定条类
 * 表示单次命中的延迟显示
 */
class JudgementBar extends FlxSprite {
	/**
	 * 构造函数
	 * @param x X坐标
	 * @param y Y坐标
	 * @param height 高度
	 */
	public function new(x:Float, y:Float, height:Int) {
		super(x, y);
		
		// 创建更宽更高的白色条
		makeGraphic(RealtimeDelayGraph.BAR_WIDTH, height + 8, FlxColor.WHITE); // 高度增加8像素
		
		// 设置alpha为1.25来抵消父级的0.8透明度，使白色条看起来完全不透明
		alpha = 1.25;
		scrollFactor.set();
		
		// 调整位置让判定条看起来像是在框外显示
		// 向上偏移4像素，让它看起来超出图表边界
		y -= 4;
		this.y = y;
	}
}