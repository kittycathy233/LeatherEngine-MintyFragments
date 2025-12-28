package flixel.system.ui;

#if FLX_SOUND_SYSTEM
import flixel.FlxG;
import flixel.system.FlxAssets;
import flixel.util.FlxColor;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.display.GradientType;
import openfl.geom.Matrix;
#if flash
import openfl.text.AntiAliasType;
import openfl.text.GridFitType;
#end

/**
 * The flixel sound tray, the little volume meter that pops down sometimes.
 * Accessed via `FlxG.game.soundTray` or `FlxG.sound.soundTray`.
 */
@:allow(flixel.system.frontEnds.SoundFrontEnd)
class FlxSoundTray extends Sprite
{
	/**
	 * Because reading any data from DisplayObject is insanely expensive in hxcpp, keep track of whether we need to update it or not.
	 */
	public var active:Bool;

	/**
	 * The volume label
	 */
	var _label:TextField;
	
	/**
	 * The percentage display label
	 */
	var _percentLabel:TextField;
	
	var _bg:Sprite;
	
	/**
	 * The volume progress bar background
	 */
	var _progressBg:Sprite;
	
	/**
	 * The volume progress bar fill
	 */
	var _progressFill:Sprite;
	
	/**
	 * Helps us auto-hide the sound tray after a volume change.
	 */
	var _timer:Float;

	/**
	 * The minimum width of the sound tray
	 */
	var _minWidth:Int = 200;
	
	/**
	 * Height of the progress bar
	 */
	var _progressBarHeight:Int = 10;

	var _defaultScale:Float = 2.0;
	
	/**
	 * Current target alpha for smooth transitions
	 */
	var _targetAlpha:Float = 0;
	
	/**
	 * Current alpha for smooth transitions
	 */
	var _currentAlpha:Float = 0;
	
	/**
	 * Current target progress width for smooth animation
	 */
	var _targetProgressWidth:Float = 0;
	
	/**
	 * Current progress width for smooth animation
	 */
	var _currentProgressWidth:Float = 0;
	
	/**
	 * Current color for smooth transitions
	 */
	var _currentColor:FlxColor;
	
	/**
	 * Target color for smooth transitions
	 */
	var _targetColor:FlxColor;
	
	/**
	 * Track whether the tray was just muted to handle animations properly
	 */
	var _wasJustMuted:Bool = false;
	
	/**
	 * Frame counter for update rate limiting
	 */
	var _frameCounter:Int = 0;
	
	/**
	 * Update frequency - update visuals every N frames
	 * Set to 2 means update every 2 frames (60 FPS -> 30 FPS updates)
	 * Higher values = better performance but less smooth animation
	 */
	var _updateFrequency:Int = 3;



	/**The sound used when increasing the volume.**/

	public var volumeUpSound:FlxSoundAsset = "assets/sounds/Funkin/Volup";

	/**The sound used when decreasing the volume.**/
	public var volumeDownSound:FlxSoundAsset = 'assets/sounds/Funkin/Voldown';

	/**The sound used when reaching maximum volume.**/
	public var volumeMaxSound:FlxSoundAsset = 'assets/sounds/Funkin/VolMAX';

	/**Whether or not changing the volume should make noise.**/
	public var silent:Bool = false;

	/**
	 * Sets up the "sound tray", the little volume meter that pops down sometimes.
	 */
	@:keep
	public function new()
	{
		super();

		visible = false;
		scaleX = _defaultScale;
		scaleY = _defaultScale;
		
		// Create background
		_bg = new Sprite();
		_bg.graphics.beginFill(0xDD000000);
		_bg.graphics.drawRoundRect(0, 0, _minWidth, 45, 12, 12);
		_bg.graphics.endFill();
		addChild(_bg);

		// Create volume label
		_label = new TextField();
		_label.width = 120;
		_label.height = 20;
		_label.multiline = false;
		_label.selectable = false;

		#if flash
		_label.embedFonts = true;
		_label.antiAliasType = AntiAliasType.NORMAL;
		_label.gridFitType = GridFitType.PIXEL;
		#else
		#end
		
		var dtf:TextFormat = new TextFormat("assets/fonts/Furore-2.otf", 14, 0xFFFFFF, false);
		dtf.align = TextFormatAlign.LEFT;
		_label.defaultTextFormat = dtf;
		addChild(_label);
		_label.text = "VOLUME";
		_label.x = 17;
		_label.y = 5;

		// Create percentage label
		_percentLabel = new TextField();
		_percentLabel.width = 100;
		_percentLabel.height = 20;
		_percentLabel.multiline = false;
		_percentLabel.selectable = false;

		#if flash
		_percentLabel.embedFonts = true;
		_percentLabel.antiAliasType = AntiAliasType.NORMAL;
		_percentLabel.gridFitType = GridFitType.PIXEL;
		#else
		#end
		
		var percentFormat = new TextFormat("assets/fonts/Furore-2.otf", 14, 0xFFFFFF, true);
		percentFormat.align = TextFormatAlign.RIGHT;
		_percentLabel.defaultTextFormat = percentFormat;
		addChild(_percentLabel);
		_percentLabel.x = _minWidth - _percentLabel.width - 18;
		_percentLabel.y = 5;

		// Create progress bar background with gradient
		_progressBg = new Sprite();
		var bgMatrix = new Matrix();
		bgMatrix.createGradientBox(_minWidth - 30, _progressBarHeight, Math.PI / 2, 0, 0);
		_progressBg.graphics.beginGradientFill(
			GradientType.LINEAR,
			[0x606060, 0x303030],
			[1.0, 1.0],
			[0, 255],
			bgMatrix
		);
		_progressBg.graphics.drawRoundRect(15, 28, _minWidth - 30, _progressBarHeight, 6, 6);
		_progressBg.graphics.endFill();
		
		// Add inner shadow for depth
		_progressBg.graphics.lineStyle(1, 0x202020, 0.5);
		_progressBg.graphics.drawRoundRect(15, 28, _minWidth - 30, _progressBarHeight, 6, 6);
		addChild(_progressBg);

		// Create progress bar fill
		_progressFill = new Sprite();
		addChild(_progressFill);
		
		y = -height;
		visible = false;
		_currentAlpha = 0;
		_targetAlpha = 0;
		_currentProgressWidth = (_minWidth - 30) * FlxG.sound.volume;
		_targetProgressWidth = _currentProgressWidth;
		
		// Initialize colors for smooth transitions
		var initialVolume = FlxG.sound.volume;
		_currentColor = getVolumeColor(initialVolume);
		_targetColor = _currentColor;
	}
	
	

	/**
	 * This function updates the soundtray object.
	 */
	public function update(MS:Float):Void
	{
		// Increment frame counter
		_frameCounter++;
		
		// Only update visuals every N frames to save performance
		var shouldUpdateVisuals = (_frameCounter % _updateFrequency == 0);
		
		// Animate sound tray thing
		if (_timer > 0)
		{
			_timer -= (MS / 1000);
			_targetAlpha = 1.0;
		}
		else
		{
			_targetAlpha = 0.0;
		}
		
		// Smooth alpha transition - update every frame for smoothness
		var alphaSpeed = 0.02;
		if (Math.abs(_currentAlpha - _targetAlpha) > 0.005)
		{
			_currentAlpha += (_targetAlpha - _currentAlpha) * alphaSpeed;
			alpha = _currentAlpha;
		}
		else
		{
			_currentAlpha = _targetAlpha;
			alpha = _currentAlpha;
		}
		
		// Smooth progress bar width animation
		var progressSpeed = 0.03;
		if (Math.abs(_currentProgressWidth - _targetProgressWidth) > 0.5)
		{
			_currentProgressWidth += (_targetProgressWidth - _currentProgressWidth) * progressSpeed;
			if (shouldUpdateVisuals)
				updateProgressBarVisual();
		}
		else
		{
			_currentProgressWidth = _targetProgressWidth;
			if (shouldUpdateVisuals)
				updateProgressBarVisual();
		}
		
		// Update target color based on current volume
		var currentVolume = _currentProgressWidth / (_minWidth - 30);
		_targetColor = getVolumeColor(currentVolume);
		
		// Smooth color transition - less frequent updates
		var colorSpeed = 0.04;
		if (!areColorsEqual(_currentColor, _targetColor))
		{
			_currentColor = interpolateColor(_currentColor, _targetColor, colorSpeed);
			if (shouldUpdateVisuals)
				updateProgressBarVisual();
		}
		else
		{
			_currentColor = _targetColor;
			if (shouldUpdateVisuals)
				updateProgressBarVisual();
		}
		
		// Handle sliding animation
		if (_targetAlpha > 0)
		{
			// Slide down (when show is called)
			var targetY = 50;
			y += (targetY - y) * 0.08;
		}
		else if (_targetAlpha == 0)
		{
			// Slide up (when hiding)
			y -= (MS / 1000) * height * 0.2;

			if (y <= -height * 2)
			{
				visible = false;
				active = false;

				#if FLX_SAVE
				// Save sound preferences
				if (FlxG.save.isBound)
				{
					FlxG.save.data.mute = FlxG.sound.muted;
					FlxG.save.data.volume = FlxG.sound.volume;
					FlxG.save.flush();
				}
				#end
			}
		}
	}
	
	/**
	 * Shows the volume animation for the desired settings
	 * @param   volume    The volume, 1.0 is full volume
	 * @param   sound     The sound to play, if any
	 * @param   duration  How long the tray will show
	 * @param   label     The test label to display
	 */
	public function showAnim(volume:Float, ?sound:FlxSoundAsset, duration = 1.0, label = "VOLUME")
	{
		// Check if volume is at maximum (>= 1.0)
		var isMaxVolume = volume >= 1.0;
		
		if (sound != null)
		{
			// Play different sound based on volume level
			if (isMaxVolume && volumeMaxSound != null)
				FlxG.sound.play(FlxG.assets.getSoundAddExt(volumeMaxSound));
			else
				FlxG.sound.play(FlxG.assets.getSoundAddExt(sound));
		}
		
		_timer = duration;
		visible = true;
		active = true;
		_targetAlpha = 1.0;
		
		// Reset position if hiding animation was in progress
		if (y < 0)
		{
			y = 0;
		}
		
		// Set target progress width for smooth animation
		_targetProgressWidth = Math.round((_minWidth - 30) * volume);
		
		// Track mute state changes for proper animation handling
		_wasJustMuted = (volume <= 0);
		
		// Update percentage display
		var percentage = Math.round(volume * 100);
		
		// Special display for mute and max volume
		if (volume <= 0)
		{
			_percentLabel.text = "MUTED";
		}
		else if (isMaxVolume)
		{
			_percentLabel.text = "MAX";
		}
		else
		{
			_percentLabel.text = percentage + "%";
			_label.text = label;
		}
	}
	
	/**
	 * Makes the little volume tray slide out.
	 *
	 * @param   up  Whether the volume is increasing.
	 */
	@:deprecated("show is deprecated, use showAnim")
	public function show(up:Bool = false):Void
	{
		if (up)
			showIncrement();
		else
			showDecrement();
	}
	
	function showIncrement():Void
	{
		final volume = FlxG.sound.muted ? 0 : FlxG.sound.volume;
		showAnim(volume, silent ? null : volumeUpSound);
	}
	
	function showDecrement():Void
	{
		final volume = FlxG.sound.muted ? 0 : FlxG.sound.volume;
		showAnim(volume, silent ? null : volumeDownSound);
	}

	public function screenCenter():Void
	{
		scaleX = _defaultScale;
		scaleY = _defaultScale;

		x = (0.5 * (Lib.current.stage.stageWidth - _minWidth * _defaultScale) - FlxG.game.x);
	}
	
	/**
	 * Updates the visual appearance of the progress bar with smooth effects
	 */
	function updateProgressBarVisual():Void
	{
		_progressFill.graphics.clear();
		
		// Use the current interpolated color instead of calculating directly
		var barColor = _currentColor;
		
		// Create gradient fill for silky smooth look
		var fillMatrix = new Matrix();
		fillMatrix.createGradientBox(_currentProgressWidth, _progressBarHeight, Math.PI / 2, 0, 0);
		
		// Add subtle gradient from lighter to darker color
		var lightColor = FlxColor.fromRGBFloat(
			Math.min(1.0, barColor.redFloat + 0.2),
			Math.min(1.0, barColor.greenFloat + 0.2),
			Math.min(1.0, barColor.blueFloat + 0.2)
		);
		
		_progressFill.graphics.beginGradientFill(
			GradientType.LINEAR,
			[lightColor, barColor],
			[1.0, 1.0],
			[0, 255],
			fillMatrix
		);
		
		// Draw rounded progress bar
		_progressFill.graphics.drawRoundRect(15, 28, _currentProgressWidth, _progressBarHeight, 6, 6);
		_progressFill.graphics.endFill();
		
		// Add subtle top highlight for silky appearance
		var highlightMatrix = new Matrix();
		highlightMatrix.createGradientBox(_currentProgressWidth, _progressBarHeight / 2, Math.PI / 2, 0, 0);
		_progressFill.graphics.beginGradientFill(
			GradientType.LINEAR,
			[FlxColor.WHITE, FlxColor.TRANSPARENT],
			[0.3, 0.0],
			[0, 255],
			highlightMatrix
		);
		_progressFill.graphics.drawRoundRect(15, 28, _currentProgressWidth, _progressBarHeight / 2, 6, 6);
		_progressFill.graphics.endFill();
	}
	
	/**
	 * Gets the target color based on volume level
	 */
	function getVolumeColor(volume:Float):FlxColor
	{
		if (volume <= 0.25)
			return FlxColor.fromString("#CD5C5C");
		else if (volume <= 0.8)
			return FlxColor.fromString("#CCCCFF");
		else
			return FlxColor.fromString("#87CEFA");
	}
	
	/**
	 * Checks if two colors are approximately equal
	 */
	function areColorsEqual(color1:FlxColor, color2:FlxColor):Bool
	{
		return Math.abs(color1.redFloat - color2.redFloat) < 0.01 &&
			   Math.abs(color1.greenFloat - color2.greenFloat) < 0.01 &&
			   Math.abs(color1.blueFloat - color2.blueFloat) < 0.01;
	}
	
	/**
	 * Interpolates between two colors with a given factor (0-1)
	 */
	function interpolateColor(fromColor:FlxColor, toColor:FlxColor, factor:Float):FlxColor
	{
		var red = fromColor.redFloat + (toColor.redFloat - fromColor.redFloat) * factor;
		var green = fromColor.greenFloat + (toColor.greenFloat - fromColor.greenFloat) * factor;
		var blue = fromColor.blueFloat + (toColor.blueFloat - fromColor.blueFloat) * factor;
		
		return FlxColor.fromRGBFloat(red, green, blue);
	}
}
#end
