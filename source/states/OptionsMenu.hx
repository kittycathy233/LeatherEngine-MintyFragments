package states;

import haxe.Json;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import utilities.MusicUtilities;
import ui.Option;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import openfl.utils.Assets;
import states.OptionsPageFactory;

using utilities.BackgroundUtil;

class OptionsMenu extends MusicBeatState {
	public var curSelected:Int = 0;

	public var inMenu = false;

	public var pages:Map<String, Array<Option>> = [
		"Categories" => [
			new PageOption("Gameplay", "Gameplay", "Customize gameplay mechanics and settings.\nAdjust downscroll, ghost tapping, and more."),
			new PageOption("Graphics", "Graphics", "Configure visual settings and display options.\nChange FPS limits, effects, and appearance."),
			new PageOption("Miscellaneous", "Misc", "Miscellaneous settings that don't fit into\nother categories, including audio and UI."),
			#if MODDING_ALLOWED
			new PageOption("Mod Options", "Mod Options", "Configure options for installed mods\nand customize mod-specific settings."),
			#end
			new PageOption("Developer Options", "Developer Options", "Advanced settings for developers.\nTools and options for mod development.")
		],
		"Gameplay" => [
			new PageOption("Back", "Categories", "Go back to the main menu."),
			new GameSubStateOption("Binds", substates.ControlMenuSubstate, "Change key bindings."),
			new BoolOption("Key Bind Reminders", "extraKeyReminders", "Should key binding reminders show up\nwhen playing a non-4-key song."),
			new GameSubStateOption("Song Offset", substates.SongOffsetMenu, "Change the offset of the song."),
			new PageOption("Judgements", "Judgements", "Change settings related to judgments.\n(sick, good, bad, etc.)"),
			new PageOption("Input Options", "Input Options", "Change options related to note inputs."),
			new BoolOption("Downscroll", "downscroll", "Toggle downscroll."),
			new BoolOption("Middlescroll", "middlescroll", "Toggle middlescroll."),
			new BoolOption("Bot", "botplay", "Toggle botplay for songs.\nUseful for showcasing hard charts."),
			new BoolOption("Real Botplay Delay", "realBotplayMs", "When toggled, displays actual timing offset\nfor botplay instead of '0ms (BOT)'."),
			new BoolOption("Quick Restart", "quickRestart", "When toggled, the game over animation will not play."),
			new BoolOption("No Death", "noDeath", "When toggled, the player is unable to die."),
			new BoolOption("Use Custom Scrollspeed", "useCustomScrollSpeed", "When toggled, a custom scroll speed will be used."),
			new GameSubStateOption("Custom Scroll Speed", substates.ScrollSpeedMenu, "Change the value of the custom scroll speed."),
			new StringSaveOption("Hitsound", CoolUtil.coolTextFile(Paths.txt("hitsoundList")), "hitsound", "Change the hitsound used when hitting a note.")
		]
		// 其他页面将通过懒加载机制按需初始化
	];

	public var page:FlxTypedGroup<Option> = new FlxTypedGroup<Option>();
	public var pageName:String = "Categories";

	public static var instance:OptionsMenu;

	public var menuBG:FlxSprite;

	public static var playing:Bool = false;

	private var defaultPage:String;
	private var backgroundColor:FlxColor;

	public var descriptionText:FlxText;
	public var descriptionBackground:FlxSprite;

	override public function new(defaultPage:String = "Categories", backgroundColor:FlxColor = 0xFFea71fd) {
		this.defaultPage = defaultPage;
		this.backgroundColor = backgroundColor;
		super();
	}

	// Mod选项已移至OptionsPageFactory中进行懒加载

	public override function create():Void {
		MusicBeatState.windowNameSuffix = "";
		instance = this;

		menuBG = new FlxSprite().makeBackground(backgroundColor);
		menuBG.scale.set(1.1, 1.1);
		menuBG.updateHitbox();
		menuBG.screenCenter();
		add(menuBG);

		super.create();

		add(page);

		loadPage(defaultPage);

		descriptionBackground = new FlxSprite();
		descriptionBackground.makeGraphic(FlxG.width, 300, FlxColor.BLACK);
		descriptionBackground.alpha = 0.5;
		add(descriptionBackground);

		descriptionText = new FlxText();
		descriptionText.alignment = CENTER;
		descriptionText.borderStyle = OUTLINE;
		descriptionText.borderColor = FlxColor.BLACK;
		descriptionText.screenCenter(X);
		descriptionText.y = FlxG.height - 80;
		descriptionText.size = 32;
		descriptionText.font = Paths.font("vcr.ttf");
		descriptionText.borderSize = 2;
		add(descriptionText);

		FlxG.sound.playMusic(MusicUtilities.getOptionsMusic(), 0.7, true);
		OptionsMenu.playing = true;
	}

	public function loadPage(loadedPageName:String):Void {
		pageName = loadedPageName;

		// 懒加载页面 - 如果页面不存在，则初始化它
		if (!pages.exists(loadedPageName)) {
			// 显示加载提示（对于大型页面如Mod Options）
			descriptionText.text = "正在加载页面...";
			descriptionText.screenCenter(X);
			descriptionText.y = FlxG.height - descriptionText.height - 50;
			
			// 确保UI更新
			descriptionBackground.setPosition(descriptionText.x - 10, descriptionText.y - 10);
			descriptionBackground.setGraphicSize(descriptionText.width + 20, descriptionText.height + 25);
			descriptionBackground.updateHitbox();
			
			// 初始化页面
			OptionsPageFactory.initializePage(loadedPageName, pages);
		}

		inMenu = true;
		instance.curSelected = 0;

		var curPage:FlxTypedGroup<Option> = instance.page;
		curPage.clear();

		var pageOptions = instance.pages.get(loadedPageName);
		if (pageOptions != null) {
			for (x in pageOptions.copy()) {
				if (x != null) {
					curPage.add(x);
				}
			}
		}

		inMenu = false;
		var bruh:Int = 0;

		for (x in instance.page.members) {
			if (x.alphabetText != null) {
				x.alphabetText.targetY = bruh - instance.curSelected;
			}
			bruh++;
		}
	}

	public function goBack() {
		if (pageName != defaultPage) {
			loadPage((cast(page.members[0], PageOption).pageName) ?? "Categories");
			return;
		}

		FlxG.switchState(() -> new MainMenuState());
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);

		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		if (!inMenu) {
			if (-1 * Math.floor(FlxG.mouse.wheel) != 0) {
				curSelected -= 1 * Math.floor(FlxG.mouse.wheel);
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			}

			if (controls.UP_P) {
				curSelected--;
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			}

			if (controls.DOWN_P) {
				curSelected++;
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			}

			if (controls.BACK)
				goBack();
		} else {
			if (controls.BACK)
				inMenu = false;
		}

		if (curSelected < 0)
			curSelected = page.length - 1;

		if (curSelected >= page.length)
			curSelected = 0;

		var bruh = 0;

		for (x in page.members) {
			x.alphabetText.targetY = bruh - curSelected;
			bruh++;
		}

		descriptionText.text = page.members[curSelected].optionDescription;
		descriptionText.screenCenter(X);
		descriptionText.y = FlxG.height - descriptionText.height - 50;

		descriptionBackground.setPosition(descriptionText.x - 10, descriptionText.y - 10);
		descriptionBackground.setGraphicSize(descriptionText.width + 20, descriptionText.height + 25);
		descriptionBackground.updateHitbox();
		for (x in page.members) {
			if (x.alphabetText.targetY != 0) {
				x.alpha = 0.6;
			} else {
				x.alpha = 1;
			}
			if ((x is DeveloperOption || x is StepperSaveDeveloperOption) && !Options.getData("developer")) {
				x.alpha *= 0.5;
			}
		}
	}
}
