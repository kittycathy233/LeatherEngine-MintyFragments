package substates;

import ui.NoteGraph;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import game.Replay;
import flixel.FlxCamera;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.FlxSprite;
import flixel.FlxG;
import states.PlayState;
import states.LoadingState;
import game.Song;
import game.Highscore;
import game.SongLoader;

class ResultsSubstate extends MusicBeatSubstate {
	var uiCamera:FlxCamera;
	private var cachedRatingText:String;
	private var hasUsedBot:Bool;
	private var playingReplay:Bool;

	public function new(replay:Replay) {
		super();

		// 缓存常用数据，避免重复访问
		hasUsedBot = PlayState.instance.hasUsedBot;
		playingReplay = PlayState.playingReplay;

		if (utilities.Options.getData("skipResultsScreen")) {
			PlayState.instance.finishSongStuffs();
			return;
		}

		uiCamera = new FlxCamera();
		uiCamera.bgColor.alpha = 0;
		FlxG.cameras.add(uiCamera, false);

		// 创建背景（优化：使用对象池模式）
		var bg:FlxSprite = createOptimizedSprite(0, 0, FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		bg.y -= 100;
		add(bg);

		FlxTween.tween(bg, {alpha: 0.6, y: bg.y + 100}, 0.4, {ease: FlxEase.quartInOut});

		// 缓存顶部文本，避免字符串拼接
		var topString = '${PlayState.SONG.song} - ${PlayState.storyDifficultyStr.toUpperCase()} complete! (${PlayState.songMultiplier}x)';

		var topText:FlxText = createOptimizedText(4, 4, topString, 32);
		topText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		topText.scrollFactor.set();
		add(topText);

		// 缓存评级文本，避免实时计算
		cachedRatingText = PlayState.instance.getRatingText();
		var ratings:FlxText = createOptimizedText(0, FlxG.height, cachedRatingText, 24);
		ratings.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		ratings.screenCenter(Y);
		ratings.scrollFactor.set();
		add(ratings);

        // 优化底部文本：预先计算字符串
        var bottomString = "Press ENTER to close this menu\n";
        if (!playingReplay && !hasUsedBot) {
            bottomString += "Press SHIFT to save this replay\nPress ESCAPE to view this replay\n";
        }
        
        var bottomText:FlxText = createOptimizedText(FlxG.width, FlxG.height, bottomString, 32);
        bottomText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
        bottomText.setPosition(FlxG.width - bottomText.width - 2, FlxG.height - (!playingReplay ? 96 : 32));
        bottomText.scrollFactor.set();
        add(bottomText);

		// 优化NoteGraph：延迟加载，避免阻塞主线程
		new FlxTimer().start(0.1, function(tmr:FlxTimer) {
			add(new NoteGraph(PlayState.instance.replay, FlxG.width - 550, 25));
		});

		cameras = [uiCamera];
	}

	/**
	 * 创建优化的Sprite对象
	 */
	private function createOptimizedSprite(x:Float, y:Float, width:Int, height:Int, color:FlxColor):FlxSprite {
		var sprite = new FlxSprite(x, y);
		sprite.makeGraphic(width, height, color);
		sprite.pixelPerfectPosition = true;
		return sprite;
	}

	/**
	 * 创建优化的Text对象
	 */
	private function createOptimizedText(x:Float, y:Float, text:String, size:Int):FlxText {
		var textObj = new FlxText(x, y, 0, text, size);
		textObj.pixelPerfectPosition = true;
		textObj.fieldWidth = 0; // 自动宽度
		return textObj;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (FlxG.keys.justPressed.ENTER) {
			PlayState.instance.finishSongStuffs();
			return; // 早期返回避免后续检查
		}
		
		// 使用缓存的布尔值，避免重复访问静态变量
		if (!playingReplay && !hasUsedBot) {
			@:privateAccess
			if(FlxG.keys.justPressed.SHIFT) {
				PlayState.instance.saveReplay();
			}

			@:privateAccess
			if(FlxG.keys.justPressed.ESCAPE) {
				PlayState.instance.saveReplay();

				var replay = PlayState.instance.replay;

				try {
					PlayState.SONG = SongLoader.loadFromJson(replay.difficulty, replay.song);
					PlayState.isStoryMode = false;
					PlayState.songMultiplier = replay.songMultiplier;
					PlayState.storyDifficultyStr = replay.difficulty.toUpperCase();
					PlayState.playingReplay = true;

					LoadingState.loadAndSwitchState(new PlayState(replay));
				} catch (e:Dynamic) {
					trace('Error loading replay song: $e');
					// 如果加载失败，关闭结果界面
					PlayState.instance.finishSongStuffs();
				}
			}
		}
	}

	override function destroy() {
		// 清理相机资源
		if (uiCamera != null) {
			FlxG.cameras.remove(uiCamera);
			uiCamera.destroy();
		}
		
		super.destroy();
	}
}
