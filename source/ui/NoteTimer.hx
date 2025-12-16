package ui;

import flixel.system.FlxAssets.FlxShader;
import flixel.math.FlxMath;
import game.Conductor;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import states.PlayState;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.ui.FlxBar;
import utilities.Options;

using flixel.util.FlxSpriteUtil;

class CircleShader extends FlxShader
{
    @:glFragmentSource('
        #pragma header

        float PI = 3.14159265358;
        uniform float percent;

        vec2 rotate(vec2 v, float a) {
            float s = sin(a);
            float c = cos(a);
            mat2 m = mat2(c, -s, s, c);
            return m * v;
        }

        void main()
        {
            vec2 uv = openfl_TextureCoordv;
            vec4 spritecolor = flixel_texture2D(bitmap, openfl_TextureCoordv);

            //rotate uv so circle matches properly
            uv -= vec2(0.5, 0.5);
            uv = rotate(uv, PI*0.5);
            uv += vec2(0.5, 0.5);

            float percentAngle = (percent*360.0) / (180.0/PI);

            vec2 center = vec2(0.5, 0.5);
            float radius = 0.5;
            float angle = atan(uv.y - center.y, uv.x - center.x);
            float distance = length(uv - center);

            if ((angle + (PI)) > percentAngle)
            {
                spritecolor = vec4(0.0,0.0,0.0,0.0);
            }
        
            gl_FragColor = spritecolor;
        }
    ')

    public function new()
    {
       super();
    }
}

class NoteTimer extends FlxTypedSpriteGroup<FlxSprite>
{
    private var instance:PlayState;
    private var timerText:FlxText;
    private var timerCircle:FlxSprite;
    private var timerBar:FlxBar;
    private var timerBarBg:FlxSprite;
    private var circleShader:CircleShader;
    private var currentStyle:String = "circle";
    
    public function new(instance:PlayState)
    {
        super();
        this.instance = instance;
        
        currentStyle = Options.getData("breakTimerStyle");
        
        // Create text
        timerText = new FlxText(0,0,0,"");
        timerText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(timerText);
        
        // Create visual elements based on style
        switch(currentStyle) {
            case "circle":
                createCircleStyle();
            case "bar":
                createBarStyle();
            default:
                createCircleStyle(); // fallback
        }
        
        updatePosition();
    }
    
    private function createCircleStyle():Void
    {
        circleShader = new CircleShader();
        timerCircle = new FlxSprite().loadGraphic(Paths.image("circleThing"));
        timerCircle.antialiasing = true;
        timerCircle.shader = circleShader;
        timerCircle.scale *= 0.75;
        timerCircle.updateHitbox();
        add(timerCircle);
        
        if (timerBar != null) {
            remove(timerBar);
            timerBar.destroy();
            timerBar = null;
        }
        if (timerBarBg != null) {
            remove(timerBarBg);
            timerBarBg.destroy();
            timerBarBg = null;
        }
    }
    
    private function createBarStyle():Void
    {
        // Create progress bar with clean style
        timerBar = new FlxBar(0, 0, HORIZONTAL_INSIDE_OUT, 200, 15, null, "", 0, 100);
        timerBar.createFilledBar(0x40000000, 0xFF64C8FF);
        timerBar.antialiasing = true;
        timerBar.screenCenter();
        add(timerBar);
        
        // Only set numDivisions if the property exists
        #if (flixel >= "5.0.0")
        try {
            timerBar.numDivisions = 1000;
        } catch(e:Dynamic) {
            // Fallback if numDivisions not supported
            trace('numDivisions not supported in this version');
        }
        #end
        timerBar.value = 0;
        
        if (timerCircle != null) {
            remove(timerCircle);
            timerCircle.destroy();
            timerCircle = null;
            circleShader = null;
        }
        if (timerBarBg != null) {
            remove(timerBarBg);
            timerBarBg.destroy();
            timerBarBg = null;
        }
    }
    
    private var lastStartTime:Float = FlxMath.MAX_VALUE_FLOAT;
    
    override public function update(elapsed:Float)
    {
        super.update(elapsed);
        
        // Check if style changed
        var newStyle = Options.getData("breakTimerStyle");
        if (newStyle != currentStyle) {
            currentStyle = newStyle;
            switch(currentStyle) {
                case "circle":
                    createCircleStyle();
                case "bar":
                    createBarStyle();
                default:
                    createCircleStyle();
            }
            updatePosition();
        }
        
        var timeTillNextNote:Float = FlxMath.MAX_VALUE_FLOAT;

        if (instance != null)
        {
            var show:Bool = false;
            if (Conductor.songPosition > 0)
            {
                for (daNote in instance.notes)
                    if (daNote.mustPress == (PlayState.characterPlayingAs == 0)) //check notes for closest
                    {
                        var timeDiff = daNote.strumTime-Conductor.songPosition;
                        if (timeDiff < timeTillNextNote)
                            timeTillNextNote = timeDiff;
                    }

                if (timeTillNextNote == FlxMath.MAX_VALUE_FLOAT) //now check unspawnNotes if not found anything
                {
                    for (daNote in instance.unspawnNotes)
                        if (daNote.mustPress == (PlayState.characterPlayingAs == 0))
                        {
                            var timeDiff = daNote.strumTime-Conductor.songPosition;
                            if (timeDiff < timeTillNextNote)
                            {
                                timeTillNextNote = timeDiff;
                                break;
                            }
                                
                        }
                }
                show = timeTillNextNote != FlxMath.MAX_VALUE_FLOAT; //if found a note and time is larger than 2 secs
            }

            var targetAlpha:Float = 0.0;
            if (show)
            {
                if (lastStartTime == FlxMath.MAX_VALUE_FLOAT && timeTillNextNote > 3000)
                    lastStartTime = timeTillNextNote;

                if (lastStartTime != FlxMath.MAX_VALUE_FLOAT)
                {
                    var secsLeft:Float = Math.ceil(timeTillNextNote*0.001);
                    var percent:Float = timeTillNextNote/lastStartTime;
                    
                    if (percent <= 0.0)
                    {
                        lastStartTime = FlxMath.MAX_VALUE_FLOAT; //reset
                        timerText.text = "";
                        
                        // Reset visual elements based on style
                        switch(currentStyle) {
                            case "circle":
                                if (circleShader != null) circleShader.percent.value = [0.0];
                            case "bar":
                                if (timerBar != null) timerBar.value = 0;
                        }
                    }
                    else
                    {
                        // Update visual elements based on style
                        switch(currentStyle) {
                            case "circle":
                                if (circleShader != null) circleShader.percent.value = [percent];
                            case "bar":
                                if (timerBar != null) timerBar.value = percent * 100;
                        }
                        
                        // Format text based on style
                        switch(currentStyle) {
                            case "circle":
                                timerText.text = ""+secsLeft;
                                timerText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
                            case "bar":
                                timerText.text = "NEXT NOTE: " + secsLeft + "s";
                                timerText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
                        }
                    }
                    updatePosition();
                    
                }
                if (timeTillNextNote > 1000)
                {
                    targetAlpha = 1.0;
                }
            }

            timerText.alpha = FlxMath.lerp(timerText.alpha, targetAlpha, elapsed*5);
            
            // Update visual elements alpha based on style
            switch(currentStyle) {
                case "circle":
                    if (timerCircle != null) timerCircle.alpha = timerText.alpha;
                case "bar":
                    if (timerBar != null) timerBar.alpha = timerText.alpha;
            }
        }
    }

    function updatePosition()
    {
        timerText.screenCenter();
        
        switch(currentStyle) {
            case "circle":
                if (timerCircle != null) {
                    timerCircle.screenCenter();
                    if (Options.getData("downscroll")) {
                        timerCircle.y += 260;
                        timerText.y += 260;
                    } else {
                        timerCircle.y -= 260;
                        timerText.y -= 260;
                    }
                }
            case "bar":
                if (timerBar != null) {
                    timerBar.screenCenter();
                    timerText.screenCenter(X);
                    
                    if (Options.getData("downscroll")) {
                        timerBar.y += 200;
                        timerText.y = timerBar.y + 30;
                    } else {
                        timerBar.y -= 200;
                        timerText.y = timerBar.y - 35;
                    }
                }
        }
    }
}