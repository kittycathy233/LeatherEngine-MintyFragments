package ui.logs;

import flixel.system.debug.log.LogStyle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import lime.app.Application;
import openfl.events.Event;
import flixel.util.FlxColor;
import flixel.FlxG;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.display.BitmapData;

class LogPrint {
	public var text:String = "[LOG]";
	public var color:FlxColor = FlxColor.WHITE;

	public function new(text:String, color:FlxColor){
		this.text = text;
		this.color = color;
	}
}

class LogTextFormat extends TextFormat{
	override public function new(_color:FlxColor = FlxColor.WHITE, _size:Int = 16){
		super("assets/fonts/unifont-16.0.02.otf", _size, _color);
		//this.leading = -2;
	}
}

class LogText extends TextField{
	override public function new(x:Float, y:Float, sizeData:Dynamic, text:String, size:Int, textAlign:TextFormatAlign = CENTER, ?color:FlxColor = FlxColor.WHITE){
		super();
		width = sizeData.width;
		height = sizeData.height;
		multiline = true;
		wordWrap = true;
		selectable = false;

		var dtf:TextFormat = new TextFormat("assets/fonts/unifont-16.0.02.otf", size, color);
		dtf.align = textAlign;
		//dtf.leading = -2;
		defaultTextFormat = dtf;
		this.text = text;

		this.x = x;
		this.y = y;
	}
}

class Logs extends Sprite {
	public var logs:Array<String> = [];
	public var bg:Bitmap;
	public var logText:LogText;

	public static var instance:Logs = null;

	public static var errors(default, null) = 0;

	public var texts:Map<PrintType, LogPrint> = [
		PrintType.LOG => new LogPrint("LOG", FlxColor.CYAN),
		PrintType.WARNING => new LogPrint("WARNING", FlxColor.YELLOW),
		PrintType.ERROR => new LogPrint("ERROR", FlxColor.RED),
		PrintType.DEBUG => new LogPrint("DEBUG", FlxColor.LIME),
	];

	public function new() {
		super();

		instance = this;

		bg = new Bitmap(new BitmapData(FlxG.width, FlxG.height, true, FlxColor.BLACK));
		bg.alpha = 0.5;
		addChild(bg);

		logText = new LogText(0, 100, {width: FlxG.width - 20, height: FlxG.height - 100}, "", 16, LEFT);
		addChild(logText);

		addEventListener(Event.ENTER_FRAME, onFrameUpdate);
		FlxG.stage.window.onResize.add(onStageResized);
	}

	public function onFrameUpdate(_):Void {
		if (!Options.getData("developer"))
			return;

		if (FlxG.keys.justPressed.F3)
			visible = !visible;
		else if (FlxG.keys.justPressed.F4) {
			logs = [];
			logText.text = '';
			errors = 0;
		}

		if (_pendingLogUpdate) {
			updateLogDisplay();
			_pendingLogUpdate = false;
		}
	}

	private function onStageResized(w:Int, h:Int):Void {
		bg.width = Application.current.window.width;
		bg.height = Application.current.window.height;
		logText.width = Application.current.window.width - 20;
		logText.height = Application.current.window.height - 100;
	}

	public static inline function log(message:Dynamic) {
		if (Logs.instance != null)
			Logs.instance.addLog(message, PrintType.LOG);
	}

	public static inline function debug(message:Dynamic) {
		if (Logs.instance != null)
			Logs.instance.addLog(message, PrintType.DEBUG);
	}

	public static inline function warn(message:Dynamic) {
		if (Logs.instance != null)
			Logs.instance.addLog(message, PrintType.WARNING);
	}

	public static inline function error(message:Dynamic) {
		if (Logs.instance != null)
			Logs.instance.addLog(message, PrintType.ERROR);
		errors ++;
		if (LogStyle.ERROR.throwException) {
			throw message;
		}
	}

	public function addLog(message:String, ?logType:PrintType) {
		if (logText == null || message == null)
			return;

		var textt:String = "";
		var dataThing:String = message;

		if (logs.length <= 0)
			logText.text = "";

		var info:LogPrint = texts.get(logType);

		textt = (info != null ? info.text + " " : "") + dataThing;
		logs.push(textt);

		if (logs.length > 45)
			logs.shift();

		_pendingLogUpdate = true;
	}

	private var _pendingLogUpdate:Bool = false;

	private function updateLogDisplay():Void {
		if (logText == null)
			return;

		var colorThese:Array<Dynamic> = []; // [start,end,color];
		var newText:String = "";
		for (i in 0...logs.length) {
			var kys:Array<String> = [];

			for (keys in texts)
				kys.push(keys.text);

			for (val in kys) {
				if (logs[i].startsWith(val)) {
					var formatData:LogPrint = texts.get(val);
					if (formatData != null) {
						var colorFormat:Int = formatData.color;
						var stringIndex:Array<Int> = [newText.length, newText.length + logs[i].length];

						colorThese.push([stringIndex[0], stringIndex[1], colorFormat]);
					}
				}
			}

			newText += logs[i] + '\n';
		}

		logText.text = newText;

		for (i in colorThese)
			logText.setTextFormat(new LogTextFormat(i[2], 16), i[0], i[1]);

		logText.defaultTextFormat.align = LEFT;
		if (logText != null)
			logText.scrollV = Std.int(logText.maxScrollV);
	}
}
