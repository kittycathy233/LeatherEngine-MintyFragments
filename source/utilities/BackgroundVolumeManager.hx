package utilities;

import flixel.FlxG;
import utilities.Options;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

/**
 * 后台音量管理器
 * 当 autoPause 禁用时，游戏处于后台时将音量降低至 1/4，前台时恢复
 * 同时支持 SoundTray 显示效果和音量平滑过渡
 *
 * 使用定期检测机制确保在事件监听失效时仍能正常工作
 */
class BackgroundVolumeManager
{
	/**
	 * 后台音量倍数（1/4）
	 */
	private static inline final BACKGROUND_VOLUME_MULTIPLIER:Float = 0.25;

	/**
	 * 后台音量过渡动画持续时间（秒）
	 */
	private static inline final VOLUME_TWEEN_DURATION:Float = 0.3;

	/**
	 * 定期检测间隔（帧数）
	 * 默认每 60 帧检测一次（约 1 秒，假设 60 FPS）
	 * 可以根据需要调整，值越大性能开销越小
	 */
	private static inline final CHECK_INTERVAL:Int = 60;

	/**
	 * 原始音量（切换到前台时恢复使用）
	 */
	private static var originalVolume:Float = 1.0;

	/**
	 * 是否当前处于后台状态
	 */
	private static var isInBackground:Bool = false;

	/**
	 * SoundTray 显示持续时间（秒）
	 */
	private static var soundTrayDuration:Float = 1.0;

	/**
	 * 音量过渡动画对象（用于取消正在进行的动画）
	 */
	private static var volumeTween:FlxTween = null;

	/**
	 * 是否已初始化
	 */
	private static var isInitialized:Bool = false;

	/**
	 * 上次保存的音量（用于游戏重启时恢复）
	 */
	private static var lastSavedVolume:Float = 1.0;

	/**
	 * 上次是否在后台（用于游戏重启时判断）
	 */
	private static var wasInBackground:Bool = false;

	/**
	 * 检测帧计数器
	 */
	private static var checkFrameCounter:Int = 0;

	/**
	 * 上次检测的后台状态
	 */
	private static var lastCheckedBackgroundState:Bool = false;

	/**
	 * 手动跟踪的焦点状态（用于定期检测）
	 */
	private static var trackedFocusState:Bool = true;

	/**
	 * 初始化后台音量管理器
	 */
	public static function init():Void
	{
		if (isInitialized)
			return;

		isInitialized = true;

		// 初始化焦点状态为 true（前台）
		trackedFocusState = true;
		lastCheckedBackgroundState = false;
		isInBackground = false;

		// 监听窗口焦点变化事件
		#if sys
		if (FlxG.stage != null && FlxG.stage.window != null)
		{
			FlxG.stage.window.onFocusIn.add(onFocusGained);
			FlxG.stage.window.onFocusOut.add(onFocusLost);
		}
		#end
	}

	/**
	 * 更新检测（每帧调用，但实际检测间隔为 CHECK_INTERVAL 帧数）
	 * 在游戏主循环中调用此方法
	 */
	public static function update():Void
	{
		// 只在 autoPause 禁用时才检测
		if (Options.getData("autoPause") == true)
			return;

		// 增加帧计数器
		checkFrameCounter++;

		// 检查是否到达检测间隔
		if (checkFrameCounter >= CHECK_INTERVAL)
		{
			checkFrameCounter = 0;
			checkFocusState();
		}
	}

	/**
	 * 检查焦点状态并处理变化
	 */
	private static function checkFocusState():Void
	{
		// 使用跟踪的焦点状态
		var currentState:Bool = !trackedFocusState;

		// 只在状态变化时处理
		if (currentState != lastCheckedBackgroundState)
		{
			lastCheckedBackgroundState = currentState;

			if (currentState)
			{
				// 进入后台
				onFocusLost();
			}
			else
			{
				// 回到前台
				onFocusGained();
			}
		}
	}

	/**
	 * 当游戏失去焦点时调用
	 */
	private static function onFocusLost():Void
	{
		// 更新跟踪状态
		trackedFocusState = false;

		// 只在 autoPause 禁用时才处理
		if (Options.getData("autoPause") == true)
			return;

		// 记录当前是否已经在后台
		if (isInBackground)
			return;

		isInBackground = true;

		// 记录原始音量（使用实际的 FlxG.sound.volume）
		originalVolume = FlxG.sound.volume;

		// 计算目标音量（原始音量的 1/4）
		var targetVolume:Float = originalVolume * BACKGROUND_VOLUME_MULTIPLIER;

		// 取消之前的音量动画
		if (volumeTween != null)
		{
			volumeTween.cancel();
			volumeTween = null;
		}

		// 使用平滑过渡调整音量
		volumeTween = FlxTween.num(
			FlxG.sound.volume,
			targetVolume,
			VOLUME_TWEEN_DURATION,
			{
				ease: FlxEase.sineOut,
				onComplete: function(_) {
					volumeTween = null;
				}
			},
			function(value) {
				FlxG.sound.volume = value;
			}
		);

		// 显示 SoundTray 提示（使用灰色音量条）
		showSoundTray("BACKGROUND", targetVolume, true);
	}

	/**
	 * 当游戏获得焦点时调用
	 */
	private static function onFocusGained():Void
	{
		// 更新跟踪状态
		trackedFocusState = true;

		// 只在 autoPause 禁用时才处理
		if (Options.getData("autoPause") == true)
			return;

		// 如果不在后台状态，直接返回
		if (!isInBackground)
			return;

		isInBackground = false;

		// 取消之前的音量动画
		if (volumeTween != null)
		{
			volumeTween.cancel();
			volumeTween = null;
		}

		// 使用平滑过渡恢复音量
		volumeTween = FlxTween.num(
			FlxG.sound.volume,
			originalVolume,
			VOLUME_TWEEN_DURATION,
			{
				ease: FlxEase.sineOut,
				onComplete: function(_) {
					volumeTween = null;
				}
			},
			function(value) {
				FlxG.sound.volume = value;
			}
		);

		// 显示 SoundTray 提示（使用彩色音量条）
		showSoundTray("RESTORED", originalVolume, false);
	}

	/**
	 * 显示 SoundTray 提示
	 * @param label 显示的标签文本
	 * @param volume 当前音量（用于显示百分比）
	 * @param useGrayscale 是否使用灰色音量条（后台时为 true）
	 */
	private static function showSoundTray(label:String, volume:Float, useGrayscale:Bool = false):Void
	{
		#if FLX_SOUND_TRAY
		if (FlxG.game != null && FlxG.game.soundTray != null)
		{
			// 使用 SoundTray 的 showAnim 方法显示提示
			// 后台时使用灰色音量条，前台时使用彩色
			FlxG.game.soundTray.showAnim(volume, null, soundTrayDuration, label, useGrayscale);
		}
		#end
	}

	/**
	 * 重置后台音量管理器状态
	 * 在游戏重启或状态切换时调用
	 */
	public static function reset():Void
	{
		// 取消正在进行的音量动画
		if (volumeTween != null)
		{
			volumeTween.cancel();
			volumeTween = null;
		}

		isInBackground = false;
		originalVolume = 1.0;
	}

	/**
	 * 在游戏重启前保存当前状态
	 * 用于在游戏重启后恢复正确的音量
	 */
	public static function saveState():Void
	{
		lastSavedVolume = FlxG.sound.volume;
		wasInBackground = isInBackground;
	}

	/**
	 * 在游戏重启后恢复状态
	 * 用于在游戏重启后恢复正确的音量
	 */
	public static function restoreState():Void
	{
		// 如果上次在后台，恢复原始音量
		if (wasInBackground && originalVolume > 0)
		{
			FlxG.sound.volume = originalVolume;
		}
		else if (lastSavedVolume > 0)
		{
			// 否则恢复上次保存的音量
			FlxG.sound.volume = lastSavedVolume;
		}

		// 重置状态
		isInBackground = false;
		wasInBackground = false;
	}
}


