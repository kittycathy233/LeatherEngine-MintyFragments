package states;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;

class Star extends FlxSprite {
	public function new() {
		super();
		makeGraphic(2, 2, FlxColor.WHITE);
		antialiasing = true;
		exists = false;
	}

	public function init():Star {
		exists = true;
		x = FlxG.random.float() * FlxG.width;
		y = FlxG.random.float() * FlxG.height;
		
		// 随机大小和速度
		var size = FlxG.random.float(0.5, 2);
		scale.set(size, size);
		
		// 随机亮度
		alpha = FlxG.random.float(0.3, 1.0);
		
		// 随机速度
		velocity.y = FlxG.random.float(20, 100);
		velocity.x = FlxG.random.float(-10, 10);
		
		return this;
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		
		// 屏幕环绕
		if (y > FlxG.height) {
			y = -10;
			x = FlxG.random.float() * FlxG.width;
		}
		if (x < -10) {
			x = FlxG.width + 10;
		}
		if (x > FlxG.width + 10) {
			x = -10;
		}
	}
}

class DevNoticeState extends MusicBeatState {
	public var text:FlxText;
	public var canInput:Bool = true;

	private var whiteFlash:flixel.FlxSprite;
	private var warningText:FlxText;
	private var infoText:FlxText;
	private var normalText:FlxText;
	
	private var stars:FlxTypedGroup<Star>;

	override public function create() {
		super.create();

		// 创建星空背景
		stars = new FlxTypedGroup<Star>();
		add(stars);
		
		// 创建50颗星星
		for (i in 0...50) {
			var star = stars.recycle(Star.new);
			star.init();
		}

		whiteFlash = new flixel.FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
		whiteFlash.alpha = 0;
		add(whiteFlash);

		// 警告标题（红色）
		warningText = new FlxText(0, FlxG.height * 0.2, FlxG.width * 0.8, ' NOTICE ', 36);
		warningText.setFormat(Paths.font('vcr.ttf'), 36, 0xFFE74C3C, CENTER);
		warningText.screenCenter(X);
		add(warningText);

		// 信息文本（橙色）
		infoText = new FlxText(0, FlxG.height * 0.35, FlxG.width * 0.8, 
			'This project is still in development and may have the following issues:\n\n' +
			'• Game crashes and stability issues\n' +
			'• Incomplete features or existing bugs\n' +
			'• Performance optimization not yet complete', 24);
		infoText.setFormat(Paths.font('WinkySans-SemiBold.ttf'), 24, 0xFFF39C12, CENTER);
		infoText.screenCenter(X);
		add(infoText);

		// 普通文本（白色）
		normalText = new FlxText(0, FlxG.height * 0.7, FlxG.width * 0.8, 
			'If you encounter any issues, please report them to \"KittyCathy233\".\n\n' +
			'Press [ENTER] to continue into the game...', 20);
		normalText.setFormat(Paths.font('WinkySans-SemiBold.ttf'), 20, FlxColor.WHITE, CENTER);
		normalText.screenCenter(X);
		add(normalText);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (!canInput) {
			return;
		}

		if (FlxG.keys.justPressed.ENTER) {
			// 隐藏所有现有文本
			warningText.visible = false;
			infoText.visible = false;
			normalText.visible = false;

			// 创建新的加载文本
			text = new FlxText(0, 0, FlxG.width * 0.8, 'THANKS FOR READING!\nNow loading Leather Engine...', 32);
			text.setFormat(Paths.font('WinkySans-SemiBold.ttf'), 32, FlxColor.WHITE, CENTER);
			text.screenCenter();
			add(text);

			// 闪屏效果
			whiteFlash.alpha = 1;
			FlxTween.tween(whiteFlash, {alpha: 0}, 1, {
				ease: FlxEase.quadOut
			});

			FlxG.sound.play(Paths.sound('confirmMenu'));

			FlxTween.tween(text, {alpha: 0}, 2.0, {
				ease: FlxEase.cubeInOut,
				onComplete: (_) -> FlxG.switchState(() -> new TitleState())
			});

			canInput = false;
		}
	}
}