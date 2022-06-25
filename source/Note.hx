package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flash.display.BitmapData;
import editors.ChartingState;

using StringTools;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
}

class Note extends FlxSprite
{
	public var extraData:Map<String,Dynamic> = [];

	public var strumTime:Float = 0;

	public var mustPress:Bool = false;
	public var noteData:Int = 0;
	public var mania:Int = 0;
	public var tMania:Int = 0;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var ignoreNote:Bool = false;
	public var hitByOpponent:Bool = false;
	public var noteWasHit:Bool = false;
	public var prevNote:Note;
	public var nextNote:Note;

	public var spawned:Bool = false;

	public var tail:Array<Note> = []; // for sustains
	public var parent:Note;

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var noteType(default, set):String = null;

	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventVal1:String = '';
	public var eventVal2:String = '';

	public var colorSwap:ColorSwap;
	public var inEditor:Bool = false;
	public var gfNote:Bool = false;
	private var earlyHitMult:Float = 0.5;

	public static var swagWidth:Float = 160 * 0.7;
	public static var PURP_NOTE:Int = 0;
	public static var GREEN_NOTE:Int = 2;
	public static var BLUE_NOTE:Int = 1;
	public static var RED_NOTE:Int = 3;

	// Lua shit
	public var noteSplashDisabled:Bool = false;
	public var noteSplashTexture:String = null;
	public var noteSplashHue:Float = 0;
	public var noteSplashSat:Float = 0;
	public var noteSplashBrt:Float = 0;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var multAlpha:Float = 1;
	public var multSpeed(default, set):Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var hitHealth:Float = 0.023;
	public var missHealth:Float = 0.0475;
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; //9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	public var ratingDisabled:Bool = false;

	public var texture(default, set):String = null;

	public var noCombo:Bool = false;
	public var noStrumAnim:Bool = false;
	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var hitCausesMiss:Bool = false;
	public var distance:Float = 2000; //plan on doing scroll directions soon -bb

	public var hitsoundDisabled:Bool = false;

	private function set_multSpeed(value:Float):Float {
		resizeByRatio(value / multSpeed);
		multSpeed = value;
		trace('fuck cock');
		return value;
	}

	public function resizeByRatio(ratio:Float) //haha funny twitter shit
	{
		if(isSustainNote && !animation.curAnim.name.endsWith('end'))
		{
			scale.y *= ratio;
			updateHitbox();
		}
	}

	private function set_texture(value:String):String {
		if(texture != value) {
			reloadNote('', value);
		}
		texture = value;
		return value;
	}

	private function set_noteType(value:String):String {
		noteSplashTexture = PlayState.SONG.splashSkin;
		colorSwap.hue = ClientPrefs.arrowHSV[noteData % tMania][0] / 360;
		colorSwap.saturation = ClientPrefs.arrowHSV[noteData % tMania][1] / 100;
		colorSwap.brightness = ClientPrefs.arrowHSV[noteData % tMania][2] / 100;

		if(noteData > -1 && noteType != value) {
			switch(value) {
				case 'Hurt Note':
					ignoreNote = mustPress;
					reloadNote('HURT');
					noteSplashTexture = 'HURTnoteSplashes';
					colorSwap.hue = 0;
					colorSwap.saturation = 0;
					colorSwap.brightness = 0;
					if(isSustainNote) {
						missHealth = 0.1;
					} else {
						missHealth = 0.3;
					}
					hitCausesMiss = true;
				case 'No Animation':
					noAnimation = true;
					noMissAnimation = true;
				case 'GF Sing':
					gfNote = true;
			}
			noteType = value;
		}
		noteSplashHue = colorSwap.hue;
		noteSplashSat = colorSwap.saturation;
		noteSplashBrt = colorSwap.brightness;
		return value;
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?inEditor:Bool = false, mania:Int)
	{
		super();

		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;
		this.inEditor = inEditor;

		x += (ClientPrefs.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50;
		// MAKE SURE ITS DEFINITELY OFF SCREEN?
		y -= 2000;
		this.strumTime = strumTime;
		if(!inEditor) this.strumTime += ClientPrefs.noteOffset;

		this.noteData = noteData;
		this.mania = mania;
		this.tMania = mania+1;

		var arrowColors:Array<Array<String>> = [ // yeah that's more efficient I think

			[ "white" ],

			[ "purple", "red" ],

			[ "purple", "white", "red" ],

			[ "purple", "blue", "green", "red" ],

			[ "purple", "blue", "white", "green", "red" ],

			[ "purple", "green", "red", "yellow", "blue", "dark" ],

			[ "purple", "green", "red", "white", "yellow", "blue", "dark" ],

			[ "purple", "blue", "green", "red", "yellow", "violet", "black", "dark" ],

			[ "purple", "blue", "green", "red", "white", "yellow", "violet", "black", "dark" ]

		];

		if(noteData > -1) {
			texture = '';
			colorSwap = new ColorSwap();
			shader = colorSwap.shader;

			x += swagWidth * (noteData % tMania);
			if(!isSustainNote) { //Doing this 'if' check to fix the warnings on Senpai songs
				var animToPlay:String = '';
				animToPlay = arrowColors[mania][noteData % tMania];
				/*
				switch (mania)
				{
					case 1:
						animToPlay = 'white';
					
					case 2:
						switch (noteData % mania)
						{
							case 0:
								animToPlay = 'purple';
							case 1:
								animToPlay = 'red';
						}
					
					case 3:
						switch (noteData % mania)
						{
							case 0:
								animToPlay = 'purple';
							case 1:
								animToPlay = 'white';
							case 2:
								animToPlay = 'red';
						}
					
					case 4:
						switch (noteData % mania)
						{
							case 0:
								animToPlay = 'purple';
							case 1:
								animToPlay = 'blue';
							case 2:
								animToPlay = 'green';
							case 3:
								animToPlay = 'red';
						}
					
					case 5:
						switch (noteData % mania)
						{
							case 0:
								animToPlay = 'purple';
							case 1:
								animToPlay = 'blue';
							case 2:
								animToPlay = 'white';
							case 3:
								animToPlay = 'green';
							case 4:
								animToPlay = 'red';
						}
					
					case 6:
						switch (noteData % mania)
						{
							case 0:
								animToPlay = 'purple';
							case 1:
								animToPlay = 'green';
							case 2:
								animToPlay = 'red';
							case 3:
								animToPlay = 'yellow';
							case 4:
								animToPlay = 'blue';
							case 5:
								animToPlay = 'dark';
						}
					
					case 7:
						switch (noteData % mania)
						{
							case 0:
								animToPlay = 'purple';
							case 1:
								animToPlay = 'green';
							case 2:
								animToPlay = 'red';
							case 3:
								animToPlay = 'white';
							case 4:
								animToPlay = 'yellow';
							case 5:
								animToPlay = 'blue';
							case 6:
								animToPlay = 'dark';
						}
					
					case 8:
						switch (noteData % mania)
						{
							case 0:
								animToPlay = 'purple';
							case 1:
								animToPlay = 'blue';
							case 2:
								animToPlay = 'green';
							case 3:
								animToPlay = 'red';
							case 4:
								animToPlay = 'yellow';
							case 5:
								animToPlay = 'violet';
							case 6:
								animToPlay = 'black';
							case 7:
								animToPlay = 'dark';
						}
					
					case 9:
						switch (noteData % mania)
						{
							case 0:
								animToPlay = 'purple';
							case 1:
								animToPlay = 'blue';
							case 2:
								animToPlay = 'green';
							case 3:
								animToPlay = 'red';
							case 4:
								animToPlay = 'white';
							case 5:
								animToPlay = 'yellow';
							case 6:
								animToPlay = 'violet';
							case 7:
								animToPlay = 'black';
							case 8:
								animToPlay = 'dark';
						}
				}
				*/

				// animToPlay = '';

				animation.play(animToPlay + 'Scroll');
			}
		}

		// trace(prevNote);

		if(prevNote!=null)
			prevNote.nextNote = this;

		if (isSustainNote && prevNote != null)
		{
			alpha = 0.6;
			multAlpha = 0.6;
			hitsoundDisabled = true;
			if(ClientPrefs.downScroll) flipY = true;

			offsetX += width / 2;
			copyAngle = false;

			animation.play(Std.string(arrowColors[mania][noteData] + 'holdend')); // making sure it's a string
			/*
			switch (mania)
			{
				case 1:
					animation.play('whiteholdend');
				
				case 2:
					switch (noteData)
					{
						case 0:
							animation.play('purpleholdend');
						case 1:
							animation.play('redholdend');
					}
				
				case 3:
					switch (noteData)
					{
						case 0:
							animation.play('purpleholdend');
						case 1:
							animation.play('whiteholdend');
						case 2:
							animation.play('redholdend');
					}
				
				case 4:
					switch (noteData)
					{
						case 0:
							animation.play('purpleholdend');
						case 1:
							animation.play('blueholdend');
						case 2:
							animation.play('greenholdend');
						case 3:
							animation.play('redholdend');
					}
				
				case 5:
					switch (noteData)
					{
						case 0:
							animation.play('purpleholdend');
						case 1:
							animation.play('blueholdend');
						case 2:
							animation.play('whiteholdend');
						case 3:
							animation.play('greenholdend');
						case 4:
							animation.play('redholdend');
					}
				
				case 6:
					switch (noteData)
					{
						case 0:
							animation.play('purpleholdend');
						case 1:
							animation.play('greenholdend');
						case 2:
							animation.play('redholdend');
						case 3:
							animation.play('yellowholdend');
						case 4:
							animation.play('blueholdend');
						case 5:
							animation.play('darkholdend');
					}
				
				case 7:
					switch (noteData)
					{
						case 0:
							animation.play('purpleholdend');
						case 1:
							animation.play('greenholdend');
						case 2:
							animation.play('redholdend');
						case 3:
							animation.play('whiteholdend');
						case 4:
							animation.play('yellowholdend');
						case 5:
							animation.play('blueholdend');
						case 6:
							animation.play('darkholdend');
					}
				
				case 8:
					switch (noteData)
					{
						case 0:
							animation.play('purpleholdend');
						case 1:
							animation.play('blueholdend');
						case 2:
							animation.play('greenholdend');
						case 3:
							animation.play('redholdend');
						case 4:
							animation.play('yellowholdend');
						case 5:
							animation.play('violetholdend');
						case 6:
							animation.play('blackholdend');
						case 7:
							animation.play('darkholdend');
					}
				
				case 9:
					switch (noteData)
					{
						case 0:
							animation.play('purpleholdend');
						case 1:
							animation.play('blueholdend');
						case 2:
							animation.play('greenholdend');
						case 3:
							animation.play('redholdend');
						case 4:
							animation.play('whiteholdend');
						case 5:
							animation.play('yellowholdend');
						case 6:
							animation.play('violetholdend');
						case 7:
							animation.play('blackholdend');
						case 8:
							animation.play('darkholdend');
					}
			}
			*/

			// animation.play('holdend');

			updateHitbox();

			offsetX -= width / 2;

			if (PlayState.isPixelStage)
				offsetX += 30;

			if (prevNote.isSustainNote)
			{

				prevNote.animation.play(Std.string(arrowColors[mania][prevNote.noteData] + 'hold'));
				// I wrote animation instead of prevNote.animation so it was bugged and I was so confused lmaoooo
				/*
				switch (mania)
				{
					case 1:
						prevNote.animation.play('whitehold');
					
					case 2:
						switch (prevNote.noteData)
						{
							case 0:
								prevNote.animation.play('purplehold');
							case 1:
								prevNote.animation.play('redhold');
						}
					
					case 3:
						switch (prevNote.noteData)
						{
							case 0:
								prevNote.animation.play('purplehold');
							case 1:
								prevNote.animation.play('whitehold');
							case 2:
								prevNote.animation.play('redhold');
						}
					
					case 4:
						switch (prevNote.noteData)
						{
							case 0:
								prevNote.animation.play('purplehold');
							case 1:
								prevNote.animation.play('bluehold');
							case 2:
								prevNote.animation.play('greenhold');
							case 3:
								prevNote.animation.play('redhold');
						}
					
					case 5:
						switch (prevNote.noteData)
						{
							case 0:
								prevNote.animation.play('purplehold');
							case 1:
								prevNote.animation.play('bluehold');
							case 2:
								prevNote.animation.play('whitehold');
							case 3:
								prevNote.animation.play('greenhold');
							case 4:
								prevNote.animation.play('redhold');
						}
					// prevNote.animation.play('hold');
					case 6:
						switch (prevNote.noteData)
						{
							case 0:
								prevNote.animation.play('purplehold');
							case 1:
								prevNote.animation.play('greenhold');
							case 2:
								prevNote.animation.play('redhold');
							case 3:
								prevNote.animation.play('yellowhold');
							case 4:
								prevNote.animation.play('bluehold');
							case 5:
								prevNote.animation.play('darkhold');
						}
					
					case 7:
						switch (prevNote.noteData)
						{
							case 0:
								prevNote.animation.play('purplehold');
							case 1:
								prevNote.animation.play('greenhold');
							case 2:
								prevNote.animation.play('redhold');
							case 3:
								prevNote.animation.play('whitehold');
							case 4:
								prevNote.animation.play('yellowhold');
							case 5:
								prevNote.animation.play('bluehold');
							case 6:
								prevNote.animation.play('darkhold');
						}
					
					case 8:
						switch (prevNote.noteData)
						{
							case 0:
								prevNote.animation.play('purplehold');
							case 1:
								prevNote.animation.play('bluehold');
							case 2:
								prevNote.animation.play('greenhold');
							case 3:
								prevNote.animation.play('redhold');
							case 4:
								prevNote.animation.play('yellowhold');
							case 5:
								prevNote.animation.play('violethold');
							case 6:
								prevNote.animation.play('blackhold');
							case 7:
								prevNote.animation.play('darkhold');
						}
					
					case 9:
						switch (prevNote.noteData)
						{
							case 0:
								prevNote.animation.play('purplehold');
							case 1:
								prevNote.animation.play('bluehold');
							case 2:
								prevNote.animation.play('greenhold');
							case 3:
								prevNote.animation.play('redhold');
							case 4:
								prevNote.animation.play('whitehold');
							case 5:
								prevNote.animation.play('yellowhold');
							case 6:
								prevNote.animation.play('violethold');
							case 7:
								prevNote.animation.play('blackhold');
							case 8:
								prevNote.animation.play('darkhold');
						}
				}
				*/

				prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.05;
				if(PlayState.instance != null)
				{
					prevNote.scale.y *= PlayState.instance.songSpeed;
				}

				if(PlayState.isPixelStage) {
					prevNote.scale.y *= 1.19;
					prevNote.scale.y *= (6 / height); //Auto adjust note size
				}
				prevNote.updateHitbox();
				// prevNote.setGraphicSize();
			}

			if(PlayState.isPixelStage) {
				scale.y *= PlayState.daPixelZoom;
				updateHitbox();
			}
		} else if(!isSustainNote) {
			earlyHitMult = 1;
		}
		x += offsetX;
	}

	var lastNoteOffsetXForPixelAutoAdjusting:Float = 0;
	var lastNoteScaleToo:Float = 1;
	public var originalHeightForCalcs:Float = 6;
	function reloadNote(?prefix:String = '', ?texture:String = '', ?suffix:String = '') {
		if(prefix == null) prefix = '';
		if(texture == null) texture = '';
		if(suffix == null) suffix = '';

		var skin:String = texture;
		if(texture.length < 1) {
			skin = PlayState.SONG.arrowSkin;
			if(skin == null || skin.length < 1) {
				skin = 'NOTE_assets';
			}
		}

		var animName:String = null;
		if(animation.curAnim != null) {
			animName = animation.curAnim.name;
		}

		var arraySkin:Array<String> = skin.split('/');
		arraySkin[arraySkin.length-1] = prefix + arraySkin[arraySkin.length-1] + suffix;

		var lastScaleY:Float = scale.y;
		var blahblah:String = arraySkin.join('/');
		if(PlayState.isPixelStage) {
			if(isSustainNote) {
				loadGraphic(Paths.image('pixelUI/' + blahblah + 'ENDS'));
				width = width / 4;
				height = height / 2;
				originalHeightForCalcs = height;
				loadGraphic(Paths.image('pixelUI/' + blahblah + 'ENDS'), true, Math.floor(width), Math.floor(height));
			} else {
				loadGraphic(Paths.image('pixelUI/' + blahblah));
				width = width / 4;
				height = height / 5;
				loadGraphic(Paths.image('pixelUI/' + blahblah), true, Math.floor(width), Math.floor(height));
			}
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));
			loadPixelNoteAnims();
			antialiasing = false;

			if(isSustainNote) {
				offsetX += lastNoteOffsetXForPixelAutoAdjusting;
				lastNoteOffsetXForPixelAutoAdjusting = (width - 7) * (PlayState.daPixelZoom / 2);
				offsetX -= lastNoteOffsetXForPixelAutoAdjusting;

				/*if(animName != null && !animName.endsWith('end'))
				{
					lastScaleY /= lastNoteScaleToo;
					lastNoteScaleToo = (6 / height);
					lastScaleY *= lastNoteScaleToo;
				}*/
			}
		} else {
			frames = Paths.getSparrowAtlas(blahblah);
			loadNoteAnims();
			antialiasing = ClientPrefs.globalAntialiasing;
		}
		if(isSustainNote) {
			scale.y = lastScaleY;
		}
		updateHitbox();

		if(animName != null)
			animation.play(animName, true);

		if(inEditor) {
			setGraphicSize(ChartingState.GRID_SIZE, ChartingState.GRID_SIZE);
			updateHitbox();
		}
	}

	function loadNoteAnims() {
		animation.addByPrefix('greenScroll', 'green0');
		animation.addByPrefix('redScroll', 'red0');
		animation.addByPrefix('blueScroll', 'blue0');
		animation.addByPrefix('purpleScroll', 'purple0');

		animation.addByPrefix('whiteScroll', 'white0');

		animation.addByPrefix('yellowScroll', 'yellow0');
		animation.addByPrefix('violetScroll', 'violet0');
		animation.addByPrefix('blackScroll', 'black0');
		animation.addByPrefix('darkScroll', 'dark0');

		if (isSustainNote)
		{
			// Hold Ends

			animation.addByPrefix('purpleholdend', 'purple hold end');
			animation.addByPrefix('greenholdend', 'green hold end');
			animation.addByPrefix('redholdend', 'red hold end');
			animation.addByPrefix('blueholdend', 'blue hold end');

			animation.addByPrefix('whiteholdend', 'white hold end');

			animation.addByPrefix('yellowholdend', 'yellow hold end');
			animation.addByPrefix('violetholdend', 'violet hold end');
			animation.addByPrefix('blackholdend', 'black hold end');
			animation.addByPrefix('darkholdend', 'dark hold end');

			// Hold Pieces

			animation.addByPrefix('purplehold', 'purple hold piece');
			animation.addByPrefix('greenhold', 'green hold piece');
			animation.addByPrefix('redhold', 'red hold piece');
			animation.addByPrefix('bluehold', 'blue hold piece');

			animation.addByPrefix('whitehold', 'white hold piece');

			animation.addByPrefix('yellowhold', 'yellow hold piece');
			animation.addByPrefix('violethold', 'violet hold piece');
			animation.addByPrefix('blackhold', 'black hold piece');
			animation.addByPrefix('darkhold', 'dark hold piece');
		}

		setGraphicSize(Std.int(width * 0.7));
		updateHitbox();
	}

	function loadPixelNoteAnims() {
		if(isSustainNote) {
			animation.add('purpleholdend', [PURP_NOTE + 4]);
			animation.add('greenholdend', [GREEN_NOTE + 4]);
			animation.add('redholdend', [RED_NOTE + 4]);
			animation.add('blueholdend', [BLUE_NOTE + 4]);

			animation.add('purplehold', [PURP_NOTE]);
			animation.add('greenhold', [GREEN_NOTE]);
			animation.add('redhold', [RED_NOTE]);
			animation.add('bluehold', [BLUE_NOTE]);
		} else {
			animation.add('greenScroll', [GREEN_NOTE + 4]);
			animation.add('redScroll', [RED_NOTE + 4]);
			animation.add('blueScroll', [BLUE_NOTE + 4]);
			animation.add('purpleScroll', [PURP_NOTE + 4]);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (mustPress)
		{
			// ok river
			if (strumTime > Conductor.songPosition - Conductor.safeZoneOffset
				&& strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
				canBeHit = true;
			else
				canBeHit = false;

			if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit)
				tooLate = true;
		}
		else
		{
			canBeHit = false;

			if (strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
			{
				if((isSustainNote && prevNote.wasGoodHit) || strumTime <= Conductor.songPosition)
					wasGoodHit = true;
			}
		}

		if (tooLate && !inEditor)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}
}
