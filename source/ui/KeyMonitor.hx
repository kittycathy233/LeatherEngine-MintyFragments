package ui;

import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.input.keyboard.FlxKey;
import flixel.input.FlxInput.FlxInputState;
import states.PlayState;
import flixel.util.FlxSpriteUtil;

/**
 * 显示实时按键状态的UI组件
 */
class KeyMonitor extends FlxSpriteGroup
{
    private var keyTexts:Array<FlxText> = [];
    private var keyBackgrounds:Array<flixel.FlxSprite> = [];
    private var keyScales:Array<Float>; // 存储每个按键的目标缩放值
    private var binds:Array<String>;
    private var keyCount:Int;
    private var replayIndicator:FlxText;
    private var backgroundBox:flixel.FlxSprite; // 25%不透明度的黑色背景盒子
    
    // 添加圆角半径和颜色变量
    private var keyWidth:Float;
    private var keyHeight:Float;
    private var keySpacing:Float;
    private var fontSize:Float;
    private var roundRadius:Float = 8; // 圆角半径
    
    // 颜色定义
    private var defaultBgColor:FlxColor = FlxColor.BLACK;
    private var defaultBgAlpha:Float = 0.4;
    private var maxPressedBgColor:FlxColor = FlxColor.fromRGB(100, 200, 255); // 64C8FF 亮蓝色
    private var maxPressedBgAlpha:Float = 0.9;
    private var pressedTextColor:FlxColor = FlxColor.WHITE;
    
    // 缩放范围定义
    private var minScale:Float = 0.7;
    private var maxScale:Float = 1.3;
    
    public function new(keyCount:Int, binds:Array<String>)
    {
        super();
        
        this.keyCount = keyCount;
        this.binds = binds;
        this.keyScales = [for (i in 0...keyCount) 1.0]; // 初始化所有按键缩放为1.0
        
        createBackgroundBox();
        createKeyDisplay();
        createReplayIndicator();
        
        // 设置摄像机
        cameras = [PlayState.instance.camHUD];
        scrollFactor.set();
    }
    
    /**
     * 绘制圆角矩形背景
     */
    private function drawRoundedRect(sprite:flixel.FlxSprite, width:Int, height:Int, color:FlxColor, alpha:Float):Void
    {
        sprite.makeGraphic(width, height, FlxColor.TRANSPARENT);
        var drawStyle = { thickness: 2, color: FlxColor.WHITE, pixelHinting: true };
        FlxSpriteUtil.drawRoundRect(sprite, 0, 0, width, height, roundRadius, color, drawStyle);
        sprite.alpha = alpha;
    }
    
    /**
     * 根据缩放值计算插值颜色
     * @param scale 当前缩放值（1.0-1.5）
     * @return 插值后的颜色
     */
    private function getInterpolatedColor(scale:Float):FlxColor
    {
        // 限制缩放值在范围内
        scale = flixel.math.FlxMath.bound(scale, minScale, maxScale);
        
        // 计算插值比例 (0.0 到 1.0)
        var t:Float = (scale - minScale) / (maxScale - minScale);
        
        // 颜色插值：从黑色到亮蓝色
        var r:Float = defaultBgColor.red + (maxPressedBgColor.red - defaultBgColor.red) * t;
        var g:Float = defaultBgColor.green + (maxPressedBgColor.green - defaultBgColor.green) * t;
        var b:Float = defaultBgColor.blue + (maxPressedBgColor.blue - defaultBgColor.blue) * t;
        
        return FlxColor.fromRGB(Std.int(r), Std.int(g), Std.int(b));
    }
    
    /**
     * 创建25%不透明度的黑色背景盒子
     */
    private function createBackgroundBox():Void
    {
        backgroundBox = new flixel.FlxSprite();
        backgroundBox.makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), FlxColor.BLACK);
        backgroundBox.alpha = 0.25; // 25%不透明度
        backgroundBox.scrollFactor.set();
        add(backgroundBox);
    }
    
    /**
     * 更新背景盒子大小以适应按键区域
     */
    private function updateBackgroundBoxSize(startX:Float, startY:Float, totalWidth:Float, keyHeight:Float):Void
    {
        if (backgroundBox != null) {
            // 计算背景盒子的尺寸和位置，加上一些边距
            var padding:Float = 20; // 20像素的边距
            var bgX:Float = startX - padding;
            var bgY:Float = startY - padding;
            var bgWidth:Float = totalWidth + (padding * 2);
            var bgHeight:Float = keyHeight + (padding * 2);
            
            // 重新设置背景盒子的大小和位置
            backgroundBox.x = bgX;
            backgroundBox.y = bgY;
            backgroundBox.setGraphicSize(Std.int(bgWidth), Std.int(bgHeight));
            backgroundBox.updateHitbox();
        }
    }
    
    private function createKeyDisplay():Void
    {
        // HUD左侧居中位置向右偏移100px，垂直居中
        var startX:Float = 100; // 从HUD左侧向右偏移100px
        var startY:Float = FlxG.height / 2; // 垂直居中
        
        // 根据按键数量调整大小（整体放大一倍）
        keyWidth = (keyCount > 6 ? 30 : 35) * 2; // 放大一倍
        keyHeight = (keyCount > 6 ? 30 : 35) * 2; // 放大一倍
        keySpacing = (keyCount > 6 ? 6 : 8) * 2; // 间距也放大一倍
        fontSize = (keyCount > 6 ? 12 : 14) * 2; // 字体放大一倍
        
        // 调整圆角半径以适应放大后的按键
        roundRadius = (keyCount > 6 ? 6 : 8);
        
        // 根据按键数量调整起始位置以居中显示
        var totalWidth:Float = (keyCount * keyWidth) + ((keyCount - 1) * keySpacing);
        
        // 先创建背景盒子，然后创建按键
        updateBackgroundBoxSize(startX, startY, totalWidth, keyHeight);
        
        for (i in 0...keyCount)
        {
            // 创建按键背景（圆角矩形）
            var bg:flixel.FlxSprite = new flixel.FlxSprite();
            drawRoundedRect(bg, Std.int(keyWidth), Std.int(keyHeight), defaultBgColor, defaultBgAlpha);
            bg.x = startX + (i * (keyWidth + keySpacing));
            bg.y = startY;
            
            // 创建按键文本
            var keyText:FlxText = new FlxText(0, 0, Math.round(keyWidth), binds[i].toUpperCase(), Math.round(fontSize));
            keyText.setFormat(Paths.font("vcr.ttf"), Math.round(fontSize), FlxColor.WHITE, CENTER);
            keyText.alignment = CENTER;
            keyText.x = bg.x;
            keyText.y = bg.y + (keyHeight - keyText.height) / 2;
            keyText.borderStyle = FlxTextBorderStyle.OUTLINE_FAST;
            keyText.borderColor = FlxColor.BLACK;
            keyText.borderSize = 1;
            
            // 处理长按键名称（如SPACE、SEMICOLON等）
            if (binds[i].length > 6) {
                keyText.text = binds[i].substr(0, 3).toUpperCase();
            }
            
            keyBackgrounds.push(bg);
            keyTexts.push(keyText);
            
            add(bg);
            add(keyText);
        }
        
        // 在按键创建完成后更新REPLAY指示器位置
        updateReplayIndicatorPosition();
    }
    
    private function createReplayIndicator():Void
    {
        replayIndicator = new FlxText(0, 0, 0, "REPLAY", 24); // 字体大小也放大一倍
        replayIndicator.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, CENTER); // 字体大小放大一倍
        replayIndicator.borderStyle = FlxTextBorderStyle.OUTLINE_FAST;
        replayIndicator.borderColor = FlxColor.BLACK;
        replayIndicator.borderSize = 2; // 边框也放大一倍
        replayIndicator.alpha = 0;
        replayIndicator.visible = false;
        updateReplayIndicatorPosition();
        add(replayIndicator);
    }
    
    private function updateReplayIndicatorPosition():Void
    {
        if (replayIndicator != null && keyBackgrounds.length > 0) {
            // 计算按键布局的总宽度和中心位置（使用放大后的尺寸）
            var totalWidth:Float = (keyCount * keyWidth) + ((keyCount - 1) * keySpacing);
            
            // 获取第一个按键的X位置（起始位置）
            var startX:Float = keyBackgrounds[0].x;
            
            // 计算中心位置，REPLAY文本也相应调整
            var centerX:Float = startX + (totalWidth / 2) - (replayIndicator.width / 2);
            var centerY:Float = keyBackgrounds[0].y - 50; // 按键上方50像素（也放大一倍）
            
            replayIndicator.x = centerX;
            replayIndicator.y = centerY;
        }
    }
    
    var previousPressedStates:Array<Bool> = [];
    
    override function update(elapsed:Float):Void
    {
        super.update(elapsed);
        
        // 初始化之前的状态数组
        if (previousPressedStates.length != keyCount) {
            previousPressedStates = [for (i in 0...keyCount) false];
        }
        
        // 更新replay indicator的显示状态
        if (replayIndicator != null && PlayState.instance != null) {
            var shouldShowReplay:Bool = PlayState.playingReplay;
            if (replayIndicator.visible != shouldShowReplay) {
                replayIndicator.visible = shouldShowReplay;
                if (shouldShowReplay) {
                    // 淡入动画
                    replayIndicator.alpha = 0;
                    FlxTween.tween(replayIndicator, {alpha: 1}, 0.5, {ease: FlxEase.circInOut});
                } else {
                    // 淡出动画
                    FlxTween.tween(replayIndicator, {alpha: 0}, 0.3, {ease: FlxEase.circIn, onComplete: function(twn) {
                        replayIndicator.visible = false;
                    }});
                }
            }
        }
        
        for (i in 0...keyCount)
        {
            var isPressed:Bool = false;
            
            // 检查是否在播放replay
            if (PlayState.instance != null && PlayState.playingReplay) {
                // 从PlayState的heldArray获取按键状态
                if (PlayState.instance.heldArray != null && i < PlayState.instance.heldArray.length) {
                    isPressed = PlayState.instance.heldArray[i];
                }
            } else {
                // 正常游戏时的按键检测
                var keyName:String = binds[i];
                try {
                    isPressed = FlxG.keys.checkStatus(FlxKey.fromString(keyName), PRESSED);
                } catch (e:Dynamic) {
                    // 如果按键名称无效，使用备用检测
                    isPressed = false;
                }
            }
            
            var wasPressed:Bool = previousPressedStates[i];
            
            // 设置目标缩放值
            if (isPressed && !wasPressed) {
                // 按键刚被按下 - 设置最大小缩放
                keyScales[i] = minScale;
                keyBackgrounds[i].scale.set(minScale, minScale);
            } else if (!isPressed && wasPressed) {
                // 按键刚被释放 - 恢复默认缩放
                keyScales[i] = 1;
            } else if (isPressed) {
                // 按住时设置中等缩放
                keyScales[i] = 0.88;
            }
            
            // 平滑过渡到目标缩放值
            var lerpSpeed:Float = 0.1; // lerp速度，值越小越慢
            keyBackgrounds[i].scale.x = flixel.math.FlxMath.lerp(keyBackgrounds[i].scale.x, keyScales[i], lerpSpeed);
            keyBackgrounds[i].scale.y = flixel.math.FlxMath.lerp(keyBackgrounds[i].scale.y, keyScales[i], lerpSpeed);
            
            // 基于当前实际缩放值计算颜色和透明度
            var currentScale:Float = (keyBackgrounds[i].scale.x + keyBackgrounds[i].scale.y) / 2; // 取平均值
            var interpolatedColor:FlxColor = getInterpolatedColor(currentScale);
            var interpolatedAlpha:Float = defaultBgAlpha + (maxPressedBgAlpha - defaultBgAlpha) * ((currentScale - minScale) / (maxScale - minScale));
            
            // 应用颜色和样式
            if (isPressed) {
                // 按下时：使用插值颜色，白色文字，无边框
                drawRoundedRect(keyBackgrounds[i], Std.int(keyWidth), Std.int(keyHeight), interpolatedColor, interpolatedAlpha);
                keyTexts[i].color = pressedTextColor;
                keyTexts[i].borderStyle = FlxTextBorderStyle.NONE;
            } else {
                // 未按下时：使用默认颜色，白色文字，黑色边框
                drawRoundedRect(keyBackgrounds[i], Std.int(keyWidth), Std.int(keyHeight), defaultBgColor, defaultBgAlpha);
                keyTexts[i].color = FlxColor.WHITE;
                keyTexts[i].borderStyle = FlxTextBorderStyle.OUTLINE_FAST;
                keyTexts[i].borderColor = FlxColor.BLACK;
            }
            
            // 更新之前的状态
            previousPressedStates[i] = isPressed;
        }
    }
    
    public function updateBinds(newBinds:Array<String>):Void
    {
        binds = newBinds;
        for (i in 0...keyTexts.length)
        {
            if (i < binds.length)
            {
                var displayText = binds[i].toUpperCase();
                if (binds[i].length > 6) {
                    displayText = binds[i].substr(0, 3).toUpperCase();
                }
                keyTexts[i].text = displayText;
            }
        }
    }
    
    public function updatePosition(x:Float, y:Float):Void
    {
        // 更新背景盒子大小
        var totalWidth:Float = (keyCount * keyWidth) + ((keyCount - 1) * keySpacing);
        updateBackgroundBoxSize(x, y, totalWidth, keyHeight);
        
        for (i in 0...keyCount)
        {
            keyBackgrounds[i].x = x + (i * (keyWidth + keySpacing));
            keyBackgrounds[i].y = y;
            keyTexts[i].x = keyBackgrounds[i].x;
            keyTexts[i].y = y + (keyHeight - keyTexts[i].height) / 2;
        }
        
        // 更新replay indicator位置（居中于按键总长度上方）
        updateReplayIndicatorPosition();
    }
    
    // 可选：添加自定义颜色的方法
    public function setColors(defaultBg:FlxColor, defaultAlpha:Float, maxPressedBg:FlxColor, maxPressedAlpha:Float, pressedText:FlxColor):Void
    {
        defaultBgColor = defaultBg;
        defaultBgAlpha = defaultAlpha;
        maxPressedBgColor = maxPressedBg;
        maxPressedBgAlpha = maxPressedAlpha;
        pressedTextColor = pressedText;
        
        // 重新绘制所有按键
        for (i in 0...keyCount)
        {
            if (!previousPressedStates[i]) {
                drawRoundedRect(keyBackgrounds[i], Std.int(keyWidth), Std.int(keyHeight), defaultBgColor, defaultBgAlpha);
            }
        }
    }
    
    override public function destroy():Void
    {
        // 清理所有tween
        FlxTween.cancelTweensOf(this);
        if (replayIndicator != null) {
            FlxTween.cancelTweensOf(replayIndicator);
        }
        
        // 清理数组
        keyTexts = null;
        keyBackgrounds = null;
        keyScales = null;
        binds = null;
        previousPressedStates = null;
        replayIndicator = null;
        backgroundBox = null;
        
        super.destroy();
    }
}