package game;

import modding.scripts.languages.LuaScript;
import utilities.NoteVariables;
import game.TimeBar;
import flixel.tweens.FlxTween;
import flixel.FlxCamera;
import states.PlayState;
import flixel.FlxG;
import game.Conductor;
import game.StageGroup;
import game.Character;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

class EventHandler {
	public static function processEvent(game:PlayState, event:Array<Dynamic>) {
		switch (event[0].toLowerCase()) {
			#if !linc_luajit
			case "hey!":
				var charString:String = event[2].toLowerCase();

				var char:Int = 0;

				if (charString == "bf" || charString == "boyfriend" || charString == "player" || charString == "player1")
					char = 1;

				if (charString == "gf" || charString == "girlfriend" || charString == "player3")
					char = 2;

				switch (char) {
					case 0:
						PlayState.boyfriend.playAnim("hey", true);
						PlayState.gf.playAnim("cheer", true);
					case 1:
						PlayState.boyfriend.playAnim("hey", true);
					case 2:
						PlayState.gf.playAnim("cheer", true);
				}
			case "set gf speed":
				if (Std.parseInt(event[2]) != null)
					game.gfSpeed = Std.parseInt(event[2]);
			case "character will idle":
				var char = PlayState.getCharFromEvent(event[2]);

				var funny = Std.string(event[3]).toLowerCase() == "true";

				char.shouldDance = funny;
			case "set camera zoom":
				var defaultCamZoomThing:Float = Std.parseFloat(event[2]);
				var hudCamZoomThing:Float = Std.parseFloat(event[3]);

				if (Math.isNaN(defaultCamZoomThing))
					defaultCamZoomThing = game.defaultCamZoom;

				if (Math.isNaN(hudCamZoomThing))
					hudCamZoomThing = 1;

				game.defaultCamZoom = defaultCamZoomThing;
				game.defaultHudCamZoom = hudCamZoomThing;
			case "change character alpha":
				var char = PlayState.getCharFromEvent(event[2]);

				var alphaVal:Float = Std.parseFloat(event[3]);

				if (Math.isNaN(alphaVal))
					alphaVal = 0.5;

				char.alpha = alphaVal;
			case "play character animation":
				var character:Character = PlayState.getCharFromEvent(event[2]);

				var anim:String = "idle";

				if (event[3] != "")
					anim = event[3];

				character.playAnim(anim, true);
			case "camera flash":
				var time = Std.parseFloat(event[3]);

				if (Math.isNaN(time))
					time = 1;

				if (Options.getData("flashingLights"))
					game.camGame.flash(FlxColor.fromString(event[2].toLowerCase()), time, () -> {}, true);
			case "camera fade":
				var time = Std.parseFloat(event[3]);

				if (Math.isNaN(time))
					time = 1;

				if (Options.getData("flashingLights"))
					game.camGame.fade(FlxColor.fromString(event[2].toLowerCase()), time, false, () -> {}, true);
			#end
			case "add camera zoom":
				if (game.cameraZooms && ((FlxG.camera.zoom < 1.35 && game.camZooming) || !game.camZooming)) {
					var addGame:Float = Std.parseFloat(event[2]);
					var addHUD:Float = Std.parseFloat(event[3]);

					if (Math.isNaN(addGame))
						addGame = 0.015;

					if (Math.isNaN(addHUD))
						addHUD = 0.03;

					FlxG.camera.zoom += addGame * game.cameraZoomStrength;
					game.camHUD.zoom += addHUD * game.cameraZoomStrength;
				}
			case "screen shake":
				if (Options.getData("screenShakes")) {
					var valuesArray:Array<String> = [event[2], event[3]];
					var targetsArray:Array<FlxCamera> = [game.camGame, game.camHUD];

					for (i in 0...targetsArray.length) {
						var split:Array<String> = valuesArray[i].split(',');
						var duration:Float = 0;
						var intensity:Float = 0;

						if (split[0] != null)
							duration = Std.parseFloat(split[0].trim());
						if (split[1] != null)
							intensity = Std.parseFloat(split[1].trim());
						if (Math.isNaN(duration))
							duration = 0;
						if (Math.isNaN(intensity))
							intensity = 0;

						if (duration > 0 && intensity != 0)
							targetsArray[i].shake(intensity, duration);
					}
				}
			case "change scroll speed":
				var duration:Float = Std.parseFloat(event[3]);

				if (duration == Math.NaN)
					duration = 0;

				var funnySpeed = Std.parseFloat(event[2]);

				if (!Math.isNaN(funnySpeed)) {
					if (duration > 0)
						FlxTween.tween(game, {speed: funnySpeed}, duration);
					else
						game.speed = funnySpeed;
				}
			case "change camera speed":
				var speed:Float = Std.parseFloat(event[2]);
				if (Math.isNaN(speed))
					speed = 1;
				game.cameraSpeed = speed;
			case "change camera zoom speed":
				var speed:Float = Std.parseFloat(event[2]);
				if (Math.isNaN(speed))
					speed = 1;
				game.cameraZoomSpeed = speed;
			case "change camera zoom strength":
				var strength:Float = Std.parseFloat(event[2]);
				if (Math.isNaN(strength))
					strength = 1;
				game.cameraZoomStrength = strength;
				var rate:Float = Std.parseFloat(event[3]);
				if (Math.isNaN(rate))
					rate = 1;
				game.cameraZoomRate = rate;
			case "character will idle?":
				var char = PlayState.getCharFromEvent(event[2]);

				var funny = Std.string(event[3]).toLowerCase() == "true";

				char.shouldDance = funny;
			case "change character":
				if (Options.getData("charsAndBGs"))
					game.cacheEventCharacter(event);
			case "change stage":
				if (Options.getData("charsAndBGs")) {
					game.removeBgStuff();

					if (!Options.getData("preloadChangeBGs")) {
						game.stage.kill();
						game.stage.foregroundSprites.kill();
						game.stage.infrontOfGFSprites.kill();

						game.stage.foregroundSprites.destroy();
						game.stage.infrontOfGFSprites.destroy();
						game.stage.destroy();
					} else {
						game.stage.active = false;

						game.stage.visible = false;
						game.stage.foregroundSprites.visible = false;
						game.stage.infrontOfGFSprites.visible = false;
					}

					if (game.scripts.exists(game.stage.stage)) {
						game.scripts.get(game.stage.stage).call("onDestroy", []);
						game.scripts.remove(game.stage.stage);
					}

					if (!Options.getData("preloadChangeBGs"))
						game.stage = new StageGroup(event[2]);
					else
						game.stage = game.stageMap.get(event[2]);

					if (game.stage.stageScript != null) {
						game.stage.stageScript.executeOn = STAGE;
						game.scripts.set(game.stage.stage, game.stage.stageScript);
					}

					game.stage.visible = true;
					game.stage.foregroundSprites.visible = true;
					game.stage.infrontOfGFSprites.visible = true;
					game.stage.active = true;

					game.defaultCamZoom = game.stage.camZoom;

					game.camGame.bgColor = FlxColor.fromString(game.stage.stageData.backgroundColor ?? "#000000");

					game.call("create", [game.stage.stage], STAGE);
					game.call("createStage", [game.stage.stage]);

					#if LUA_ALLOWED
					if (game.stage.stageScript != null) {
						if (game.stage.stageScript is LuaScript)
							game.stage.stageScript.setup();
					}
					#end

					game.call("start", [game.stage.stage], STAGE);

					game.addBgStuff();
				}
			case "change keycount":
				var newPlayerKeyCount:Int = Std.parseInt(event[2]);
				var newKeyCount:Int = Std.parseInt(event[3]);
				if (newPlayerKeyCount < 1 || Math.isNaN(newPlayerKeyCount))
					newPlayerKeyCount = 1;

				if (newKeyCount < 1 || Math.isNaN(newKeyCount))
					newKeyCount = 1;

				// 延迟处理，避免在主线程中一次性执行过多操作
				FlxTimer.wait(0.001, function() {
					PlayState.SONG.keyCount = newKeyCount;
					PlayState.SONG.playerKeyCount = newPlayerKeyCount;
					
					// 使用批处理方式清除对象
					clearAllStrumsAndSplashes();

					game.binds = Options.getData("binds", "binds")[PlayState.SONG.playerKeyCount - 1];
					
					// 分批生成箭头，避免一次性创建过多对象
					generateArrowsInBatches(game);
					
					#if MODCHARTING_TOOLS
					if (game.playfieldRenderer != null) {
						game.playfieldRenderer = new modcharting.PlayfieldRenderer(PlayState.strumLineNotes, game.notes, game);
					}
					modcharting.NoteMovement.getDefaultStrumPos(game);
					#end
					
					// 延迟设置Lua变量，避免音频干扰
					FlxTimer.wait(0.002, function() {
						#if LUA_ALLOWED
						setLuaVariablesInBatches(game, newPlayerKeyCount, newKeyCount);
						#end
					});
				});
			case "change ui skin":
				var noteskin:String = Std.string(event[2]);
				PlayState.SONG.ui_Skin = noteskin;
				game.setupUISkinConfigs(noteskin);
				game.timeBar = new TimeBar(PlayState.SONG, PlayState.storyDifficultyStr);

				// 延迟处理，避免在主线程中一次性执行过多操作
				FlxTimer.wait(0.001, function() {
					clearAllStrumsAndSplashes();
					
					if (Options.getData("middlescroll")) {
						game.generateStaticArrows(50, false, false);
						FlxTimer.wait(0.001, function() {
							game.generateStaticArrows(0.5, true, false);
						});
					} else {
						if (PlayState.characterPlayingAs == 0) {
							game.generateStaticArrows(0, false, false);
							FlxTimer.wait(0.001, function() {
								game.generateStaticArrows(1, true, false);
							});
						} else {
							game.generateStaticArrows(1, false, false);
							FlxTimer.wait(0.001, function() {
								game.generateStaticArrows(0, true, false);
							});
						}
					}
					
					// 分批更新音符，避免音频卡顿
					updateNotesInBatches(game);
				});
			// FNFC stuff
			case 'focuscamera':
				switch (Std.string(event[2])) {
					case '0':
						game.turnChange('bf');
						if (Options.getData("timeBarStyle")
							.toLowerCase() == "leather engine") FlxTween.color(game.timeBar.bar, Conductor.crochet * 0.002, game.timeBar.bar.color,
								PlayState.boyfriend.barColor);
					case '1':
						game.turnChange('dad');
						if (Options.getData("timeBarStyle")
							.toLowerCase() == "leather engine") FlxTween.color(game.timeBar.bar, Conductor.crochet * 0.002, game.timeBar.bar.color,
								PlayState.dad.barColor);
				}
			case 'zoomcamera':
				game.defaultCamZoom = Std.parseFloat(event[2]);
			case 'playanimation':
				var character:Character = PlayState.getCharFromEvent(event[2]);

				var anim:String = "idle";

				var splitShit:Array<String> = event[3].split(',');

				if (splitShit[0] != "")
					anim = splitShit[0];

				character.playAnim(anim, splitShit[1] == "true");
			case 'scrollspeed':
				var splitValue1:Array<String> = event[2].split(',');
				var splitValue2:Array<String> = event[3].split(',');
				var duration:Float = Std.parseFloat(splitValue1[0]);

				if (duration == Math.NaN)
					duration = 0;

				var speed:Float = Std.parseFloat(splitValue1[1]);
				var absolute:Bool = splitValue2[2] == "true";

				for (notes in [game.notes.members, game.unspawnNotes]) {
					for (note in notes) {
						if (!absolute) {
							FlxTween.tween(note, {speed: note.originalSpeed * speed}, duration, {ease: CoolUtil.easeFromString(splitValue2[1])});
						} else {
							FlxTween.tween(note, {speed: speed}, duration, {ease: CoolUtil.easeFromString(splitValue2[1])});
						}
					}
				}
		}
	}
	
	/**
	 * 批量清除所有strum和splash对象，避免音频卡顿
	 */
	private static function clearAllStrumsAndSplashes():Void {
		PlayState.playerStrums.clear();
		PlayState.enemyStrums.clear();
		PlayState.strumLineNotes.clear();
		PlayState.instance.splash_group.clear();
	}
	
	/**
	 * 分批生成箭头对象，避免一次性创建过多对象导致卡顿
	 */
	private static function generateArrowsInBatches(game:PlayState):Void {
		if (Options.getData("middlescroll")) {
			game.generateStaticArrows(50, false);
			FlxTimer.wait(0.001, function() {
				game.generateStaticArrows(0.5, true);
			});
		} else {
			if (PlayState.characterPlayingAs == 0) {
				game.generateStaticArrows(0, false);
				FlxTimer.wait(0.001, function() {
					game.generateStaticArrows(1, true);
				});
			} else {
				game.generateStaticArrows(1, false);
				FlxTimer.wait(0.001, function() {
					game.generateStaticArrows(0, true);
				});
			}
		}
	}
	
	/**
	 * 分批更新音符UI皮肤，避免一次性更新过多对象导致音频卡顿
	 */
	private static function updateNotesInBatches(game:PlayState):Void {
		// 分批处理已生成音符
		var batchSize = 8; // 每批处理8个音符
		var totalNoteCount = game.notes.members.length;
		
		for (batchStart in 0...totalNoteCount) {
			var batchEnd = Std.int(Math.min(batchStart + batchSize, totalNoteCount));
			
			FlxTimer.wait(0.001 * batchStart, function() {
				for (i in batchStart...batchEnd) {
					var note = game.notes.members[i];
					if (note != null) {
						updateSingleNote(note, game);
					}
				}
			});
		}
		
		// 分批处理未生成音符
		var totalUnspawnCount = game.unspawnNotes.length;
		
		for (batchStart in 0...totalUnspawnCount) {
			var batchEnd = Std.int(Math.min(batchStart + batchSize, totalUnspawnCount));
			
			FlxTimer.wait(0.001 * (batchStart + totalNoteCount), function() {
				for (i in batchStart...batchEnd) {
					var note = game.unspawnNotes[i];
					if (note != null) {
						updateSingleNote(note, game);
					}
				}
				
				// 最后设置游戏速度
				if (batchEnd == totalUnspawnCount) {
					game.set_speed(game.speed);
				}
			});
		}
	}
	
	/**
	 * 更新单个音符的UI设置
	 */
	private static function updateSingleNote(note:Note, game:PlayState):Void {
		var oldAnim:String = note.animation.curAnim.name;
		note.frames = Note.getFrames(note);

		var lmaoStuff:Float = Std.parseFloat(game.ui_settings[0]) * (Std.parseFloat(game.ui_settings[2])
			- (Std.parseFloat(game.mania_size[(note.mustPress ? PlayState.SONG.playerKeyCount : PlayState.SONG.keyCount) - 1])));

		if (note.isSustainNote)
			note.scale.set(lmaoStuff,
				Std.parseFloat(game.ui_settings[0]) * (Std.parseFloat(game.ui_settings[2]) - (Std.parseFloat(game.mania_size[3]))));
		else
			note.scale.set(lmaoStuff, lmaoStuff);

		note.updateHitbox();

		note.antialiasing = game.ui_settings[3] == "true" && Options.getData("antialiasing");

		var localKeyCount:Int = note.mustPress ? note.song.playerKeyCount : note.song.keyCount;

		note.animation.addByPrefix("default", NoteVariables.animationDirections[localKeyCount - 1][note.noteData] + "0", 24);
		note.animation.addByPrefix("hold", NoteVariables.animationDirections[localKeyCount - 1][note.noteData] + " hold0", 24);
		note.animation.addByPrefix("holdend", NoteVariables.animationDirections[localKeyCount - 1][note.noteData] + " hold end0", 24);

		note.shader = note.affectedbycolor ? note.colorSwap.shader : null;

		note.animation.play(oldAnim);
	}
	
	/**
	 * 分批设置Lua变量，避免密集的Lua操作导致音频卡顿
	 */
	private static function setLuaVariablesInBatches(game:PlayState, newPlayerKeyCount:Int, newKeyCount:Int):Void {
		#if LUA_ALLOWED
		game.set("playerKeyCount", newPlayerKeyCount);
		game.set("keyCount", newKeyCount);
		
		// 分批设置strum变量，避免一次性设置过多
		var batchSize = 4; // 每批处理4个strum
		var totalStrumCount = PlayState.strumLineNotes.length;
		
		for (batchStart in 0...totalStrumCount) {
			var batchEnd = Std.int(Math.min(batchStart + batchSize, totalStrumCount));
			
			FlxTimer.wait(0.001 * batchStart, function() {
				for (i in batchStart...batchEnd) {
					var member = PlayState.strumLineNotes.members[i];
					if (member != null) {
						game.set("defaultStrum" + i + "X", member.x);
						game.set("defaultStrum" + i + "Y", member.y);
						game.set("defaultStrum" + i + "Angle", member.angle);

						game.set("defaultStrum" + i, {
							x: member.x,
							y: member.y,
							angle: member.angle,
						});

						if (PlayState.enemyStrums.members.contains(member)) {
							game.set("enemyStrum" + i % PlayState.SONG.keyCount, {
								x: member.x,
								y: member.y,
								angle: member.angle,
							});
						} else {
							game.set("playerStrum" + i % PlayState.SONG.playerKeyCount, {
								x: member.x,
								y: member.y,
								angle: member.angle,
							});
						}
					}
				}
			});
		}
		#end
	}
}
