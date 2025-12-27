package states;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.text.FlxText;

class FlashingLightsMenu extends MusicBeatState {
	public var text:FlxText;
	public var canInput:Bool = true;

	private var whiteFlash:flixel.FlxSprite;

	override public function create() {
		super.create();

		whiteFlash = new flixel.FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
		whiteFlash.alpha = 0;
		add(whiteFlash);

		text = new FlxText(0, 0, 0,
			'This game has flashing lights!\nPress Y to enable them, or N to disable them.\n(Either key closes takes you to the title screen.)', 32);
		text.font = Paths.font('vcr.ttf');
		text.screenCenter();
		text.alignment = CENTER;
		add(text);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (!canInput) {
			return;
		}

		var yes:Bool = FlxG.keys.justPressed.Y;
		var no:Bool = FlxG.keys.justPressed.N;

		if (yes) {
			Options.setData(true, 'flashingLights');
			text.text = 'Flashing lights ENABLED!\nNow loading title screen...';
			text.screenCenter();
			whiteFlash.alpha = 1;
			FlxTween.tween(whiteFlash, {alpha: 0}, 1, {
				ease: FlxEase.quadOut
			});
		} else if (no) {
			Options.setData(false, 'flashingLights');
			text.text = 'Flashing lights DISABLED.\nNow loading title screen...';
			text.screenCenter();
		}

		if (yes || no) {
			FlxG.sound.play(Paths.sound('confirmMenu'));

			FlxTween.tween(text, {alpha: 0}, 3.0, {
				ease: FlxEase.cubeInOut,
				onComplete: (_) -> FlxG.switchState(() -> new TitleState())
			});

			canInput = false;
		}
	}
}
