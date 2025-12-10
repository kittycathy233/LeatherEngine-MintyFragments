package ui;

import openfl.utils.ByteArray;
import openfl.geom.Rectangle;
import states.PlayState;
import flixel.text.FlxText;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.util.FlxTimer;
import game.Replay;
import flixel.group.FlxGroup;
import utilities.Options;

class NoteGraph extends FlxGroup {
	private static inline var GRAPH_WIDTH = 500;
	private static inline var GRAPH_HEIGHT = 332;
	private static inline var MAX_MS = 166;
	private static inline var DOT_RADIUS = 3;
	
	// 缓存静态数据
	private static var judgementTimings:Array<Int>;
	private static var ratingColors:Array<FlxColor>;
	
	private var precomputedTexts:Array<FlxText>;
	private var dotsBitmap:FlxSprite;
	
	public function new(replay:Replay, startX:Float = 0.0, startY:Float = 0.0) {
		super();

		// 只在第一次创建时初始化静态数据
		if (judgementTimings == null) {
			initializeStaticData();
		}

		var bg = new FlxSprite(startX, startY).makeGraphic(GRAPH_WIDTH, GRAPH_HEIGHT, FlxColor.BLACK);
		bg.alpha = 0.3;
		bg.pixelPerfectPosition = true;
		add(bg);

		// 批量创建静态元素
		createStaticElements(startX, startY);

		// 分帧绘制音符点，避免阻塞
		dotsBitmap = new FlxSprite(startX, startY);
		dotsBitmap.pixelPerfectPosition = true;
		add(dotsBitmap);
		
		// 使用延迟绘制，避免阻塞主线程
		new FlxTimer().start(0.05, function(tmr:FlxTimer) {
			drawNoteHitsOptimized(replay, startX, startY);
		});
	}
	
	/**
	 * 初始化静态数据，避免重复创建
	 */
	private static function initializeStaticData():Void {
		judgementTimings = Options.getData("judgementTimings");
		
		// 定义固定颜色：不同rating使用不同颜色
		ratingColors = [
			FlxColor.fromRGB(255, 182, 193), // 浅粉色 - Marvelous
			FlxColor.fromRGB(135, 206, 235), // 天蓝色 - Sick  
			FlxColor.fromRGB(144, 238, 144), // 绿色 - Good
			FlxColor.fromRGB(255, 165, 0),   // 橙黄色 - Bad
			FlxColor.fromRGB(255, 100, 100)  // 红色 - Shit
		];
	}
	
	/**
	 * 创建静态元素（判定线等）
	 */
	private function createStaticElements(startX:Float, startY:Float):Void {
		var ratingNames:Array<String> = ["Marvelous", "Sick", "Good", "Bad", "Shit"];
		var centerY = startY + (GRAPH_HEIGHT / 2);
		
		// 创建中心线和标签
		var centerLine = new FlxSprite(startX, centerY - 2).makeGraphic(GRAPH_WIDTH, 4, FlxColor.fromRGB(255, 255, 255, 180));
		centerLine.pixelPerfectPosition = true;
		add(centerLine);
		
		var perfectLabel = new FlxText(startX, centerY - 8, 0, "Perfect", 12);
		perfectLabel.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		perfectLabel.pixelPerfectPosition = true;
		add(perfectLabel);

		// 批量创建判定线和标签
		for (i in 0...judgementTimings.length) {
			var timing = judgementTimings[i];
			var y = centerY - ((timing / MAX_MS) * (GRAPH_HEIGHT / 2));
			
			// 创建判定线
			var lineTop = createOptimizedLine(startX, y, ratingColors[i]);
			var lineBottom = createOptimizedLine(startX, centerY + (centerY - y), ratingColors[i]);
			add(lineTop);
			add(lineBottom);
			
			// 创建标签
			var labelTop = createOptimizedText(startX + 505, y - 6, '${ratingNames[i]} (+${timing}ms)', 10, ratingColors[i]);
			var labelBottom = createOptimizedText(startX + 505, centerY + (centerY - y) - 6, '${ratingNames[i]} (-${timing}ms)', 10, ratingColors[i]);
			add(labelTop);
			add(labelBottom);
		}

		// 创建最大延迟标签
		var maxLabelTop = createOptimizedText(startX, startY - 16, '+${MAX_MS}ms', 12, FlxColor.WHITE);
		var maxLabelBottom = createOptimizedText(startX, startY + GRAPH_HEIGHT, '-${MAX_MS}ms', 12, FlxColor.WHITE);
		add(maxLabelTop);
		add(maxLabelBottom);
	}
	
	/**
	 * 创建优化的线条
	 */
	private function createOptimizedLine(x:Float, y:Float, color:FlxColor):FlxSprite {
		var line = new FlxSprite(x, y).makeGraphic(GRAPH_WIDTH, 2, color);
		line.alpha = 0.8;
		line.pixelPerfectPosition = true;
		return line;
	}
	
	/**
	 * 创建优化的文本
	 */
	private function createOptimizedText(x:Float, y:Float, text:String, size:Int, color:FlxColor):FlxText {
		var textObj = new FlxText(x, y, 0, text, size);
		textObj.setFormat(Paths.font("vcr.ttf"), size, color, LEFT, OUTLINE, FlxColor.BLACK);
		textObj.pixelPerfectPosition = true;
		return textObj;
	}

	/**
	 * 优化的音符点绘制
	 */
	private function drawNoteHitsOptimized(replay:Replay, startX:Float, startY:Float):Void {
		if (replay.inputs.length == 0) return;
		
		var songLength = FlxG.sound.music.length;
		var centerY = GRAPH_HEIGHT / 2;
		
		dotsBitmap.makeGraphic(GRAPH_WIDTH, GRAPH_HEIGHT, FlxColor.TRANSPARENT);
		dotsBitmap.graphic.bitmap.lock();
		dotsBitmap.graphic.bitmap.floodFill(0, 0, 0x00000000);

		// 预分配颜色查找表，避免重复计算
		var colorLookup:Map<Int, FlxColor> = new Map<Int, FlxColor>();
		
		var validInputs = 0;
		for (i in 0...replay.inputs.length) {
			var input = replay.inputs[i];
			
			// 只处理音符击中数据（类型2），因为它包含延迟信息
			if (input.length >= 4 && input[2] == 2) {
				var noteDifference = input[3]; // 延迟值
				var strumTime = input[1]; // 音符时间
				
				// 使用缓存的颜色查找
				var colorKey = Math.round(Math.abs(noteDifference));
				if (!colorLookup.exists(colorKey)) {
					colorLookup.set(colorKey, getNoteHitColorOptimized(noteDifference));
				}
				var color = colorLookup.get(colorKey);
				
				// 优化：预计算位置并缓存
				var x = Math.round(GRAPH_WIDTH * (strumTime / songLength));
				var y = Math.round(centerY - ((noteDifference / MAX_MS) * centerY));
				
				// 边界检查
				if (x >= 0 && x < GRAPH_WIDTH && y >= 0 && y < GRAPH_HEIGHT) {
					// 使用优化的圆形绘制
					drawCircleOptimized(dotsBitmap.graphic.bitmap, x, y, DOT_RADIUS, color);
				}
				
				validInputs++;
			}
			
			// 分帧处理大量数据，避免卡顿
			if (i % 100 == 0 && i > 0) {
				dotsBitmap.graphic.bitmap.unlock();
				new FlxTimer().start(0.001, function(tmr:FlxTimer) {
					dotsBitmap.graphic.bitmap.lock();
					// 继续处理剩余数据
					processRemainingInputs(replay, i, startX, startY, colorLookup, songLength, centerY);
				});
				return;
			}
		}

		dotsBitmap.graphic.bitmap.unlock();
	}
	
	/**
	 * 处理剩余输入数据的辅助函数
	 */
	private function processRemainingInputs(replay:Replay, startIndex:Int, startX:Float, startY:Float, 
		colorLookup:Map<Int, FlxColor>, songLength:Float, centerY:Float):Void {
		
		for (i in startIndex...replay.inputs.length) {
			var input = replay.inputs[i];
			
			if (input.length >= 4 && input[2] == 2) {
				var noteDifference = input[3];
				var strumTime = input[1];
				
				var colorKey = Math.round(Math.abs(noteDifference));
				if (!colorLookup.exists(colorKey)) {
					colorLookup.set(colorKey, getNoteHitColorOptimized(noteDifference));
				}
				var color = colorLookup.get(colorKey);
				
				var x = Math.round(GRAPH_WIDTH * (strumTime / songLength));
				var y = Math.round(centerY - ((noteDifference / MAX_MS) * centerY));
				
				if (x >= 0 && x < GRAPH_WIDTH && y >= 0 && y < GRAPH_HEIGHT) {
					drawCircleOptimized(dotsBitmap.graphic.bitmap, x, y, DOT_RADIUS, color);
				}
			}
			
			// 继续分帧处理
			if (i % 100 == 99 && i < replay.inputs.length - 1) {
				new FlxTimer().start(0.001, function(tmr:FlxTimer) {
					processRemainingInputs(replay, i + 1, startX, startY, colorLookup, songLength, centerY);
				});
				return;
			}
		}
		
		dotsBitmap.graphic.bitmap.unlock();
	}

	/**
	 * 优化的颜色获取函数
	 */
	private function getNoteHitColorOptimized(noteDifference:Float):FlxColor {
		var absDifference = Math.abs(noteDifference);
		
		// 使用二分查找优化
		for (i in 0...judgementTimings.length) {
			if (absDifference <= judgementTimings[i]) {
				return ratingColors[i];
			}
		}
		
		// 超出所有判定范围
		return ratingColors[ratingColors.length - 1];
	}

	/**
	 * 优化的圆形绘制函数
	 */
	private static function drawCircleOptimized(bitmap:openfl.display.BitmapData, centerX:Int, centerY:Int, radius:Int, color:FlxColor):Void {
		// 使用预计算的矩形绘制，减少函数调用
		var diameter = radius * 2;
		
		// 中心垂直线
		bitmap.fillRect(new Rectangle(centerX, centerY - radius, 1, diameter), color);
		
		// 中心水平线
		bitmap.fillRect(new Rectangle(centerX - radius, centerY, diameter, 1), color);
		
		// 使用更高效的算法绘制圆的四个象限
		for (dy in 1...radius) {
			var dx = Math.round(Math.sqrt(radius * radius - dy * dy));
			
			// 四个点
			bitmap.setPixel(centerX + dx, centerY - dy, color);
			bitmap.setPixel(centerX - dx, centerY - dy, color);
			bitmap.setPixel(centerX + dx, centerY + dy, color);
			bitmap.setPixel(centerX - dx, centerY + dy, color);
			
			// 连接线条
			if (dx > 1) {
				bitmap.fillRect(new Rectangle(centerX - dx + 1, centerY - dy, dx * 2 - 1, 1), color);
				bitmap.fillRect(new Rectangle(centerX - dx + 1, centerY + dy, dx * 2 - 1, 1), color);
			}
		}
	}
}
