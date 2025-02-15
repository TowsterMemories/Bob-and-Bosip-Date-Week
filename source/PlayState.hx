package;

import haxe.Timer;
import flixel.text.FlxText;
import flixel.FlxBasic;
import flixel.tweens.FlxEase;
import towsterFlxUtil.TowUtils;
import flixel.ui.FlxBar;
import flixel.tweens.FlxTween;
import flixel.input.keyboard.FlxKey;
import flixel.system.FlxSound;
import JsonTypes;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxCamera;
import towsterFlxUtil.TowPaths;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import towsterFlxUtil.TowSprite;

typedef Rank =
{
	time:Int,
	difference:Int
}

class PlayState extends FlxState
{
	var cameraHUD:FlxCamera;

	var isGameover:Bool = false;

	var conductor:Conductor;
	var firstUpdate:Bool = true;
	var countConductor:Conductor;
	var countState:Int = 0;
	var countSprite:SongCountDownSprite;

	var inputKeys:Array<FlxKey> = ['SPACE'];

	var songInst:FlxSound;

	var throwSound:FlxSound;

	var bob:TowSprite;
	var bosip:TowSprite;
	var BG:Background;

	var gameoverBlack:FlxSprite;

	var birdList:FlxTypedSpriteGroup<Bird>;

	var songJson:SongJson;
	var songPath = 'LoveBirds';

	var offset:Int = 0;
	// Sick, Good, Ok, Bad, Shit
	var ratingSprite:FlxTypedSpriteGroup<RatingSprite>;
	//* I coppied this into SongFinishedSubState so be careful
	var rankings = [15, 25, 40, 100];
	var rankList:Array<Rank> = [];
	var rankNames = ["sick", "good", "Bad", "Shit"];

	var healthBar:FlxBar;
	var healthBG:FlxSprite;
	var healthP1:HealthIcon;
	var healthP2:HealthIcon;

	/*
		TODO: Add end-screen
		TODO: Credits
		TODO: Freeplay
		TODO: Clean up

	 */
	override public function create()
	{
		super.create();

		songPath = StaticVar.nextSong;
		songJson = TowPaths.getFile('songs/' + songPath + '/chart', JSON, false);

		songInst = FlxG.sound.load(TowPaths.getFilePath('songs/' + songPath + '/Inst', OGG, false));
		songInst.onComplete = () ->
		{
			if (!isGameover)
				win();
		};
		throwSound = FlxG.sound.load('assets/sounds/toss.wav');

		offset = 1000;

		BG = new Background('day');
		add(BG);

		ratingSprite = new FlxTypedSpriteGroup(100, 100, 99);
		add(ratingSprite);

		healthBG = new FlxSprite(0, 46).loadGraphic(TowPaths.getFilePath('healthBar', PNG));
		healthBG.screenCenter(X);
		add(healthBG);

		healthBar = new FlxBar(0, 50, LEFT_TO_RIGHT, 590, 11);
		healthBar.createFilledBar(0xFF859ac1, 0xFFfdd173);
		healthBar.screenCenter(X);
		healthBar.percent = 50;
		add(healthBar);

		healthP1 = new HealthIcon(550, 5, 'bosip', true);
		healthP2 = new HealthIcon(600, 5, 'bob-sleep', false);
		add(healthP2);
		add(healthP1);

		// please tell me if there is a better way of doing this...
		gameoverBlack = new FlxSprite(0, 0).loadGraphic(TowPaths.getFilePath('blackScreen_holed', PNG));
		gameoverBlack.alpha = 0;
		add(gameoverBlack);

		// everything after this point will not be covered with black in gameover
		bob = new TowSprite(675, 190, 'characters/bob_assets');
		bob.loadAnimations('characters/bob');
		bob.scale.set(0.5, 0.5);
		bob.playAnim('idle');
		bob.updateHitbox();
		bosip = new TowSprite(500, 150, 'characters/bosip_assets');
		bosip.loadAnimations('characters/bosip');
		bosip.scale.set(0.5, 0.5);
		bosip.playAnim('idle');
		bosip.updateHitbox();
		bosip.health = 50;
		add(bob);
		add(bosip);

		birdList = new FlxTypedSpriteGroup(0, 0, 999);
		add(birdList);

		countSprite = new SongCountDownSprite();
		add(countSprite);
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (countState == 0)
		{
			countConductor = new Conductor(songJson.bpmList, -1000);
			countState = 1;
		}
		else if (countState >= 1 && countState <= 4)
		{
			if (countConductor.pastBeat())
			{
				FlxG.sound.play('assets/sounds/123Go/bosip/' + countState + '.ogg');
				countSprite.next();
				countState++;
			}
		}
		else if (countState == 5)
		{
			conductor = new Conductor(songJson.bpmList, 0);
			songInst.play();
			songInst.time = conductor.getMil();
			countState = 6;
		}
		else
		{
			organizeNotes();

			// songInst.time = songInst.length - 10;

			birdList.forEachAlive(function(bird)
			{
				if (conductor.getMil() > bird.time + bird.actionTime(0))
				{
					// bruh lmao
					bird.comeIn(Math.floor(Math.abs(bird.actionTime(0))));
				}
				if (conductor.getMil() > bird.time + bird.actionTime(1))
				{
					bird.peck();
				}
				if (conductor.getMil() > bird.time + bird.actionTime(2))
				{
					if (bird.shouldRank)
					{
						bird.shouldRank = false;
						bird.playAnim('squawk');
						bosip.playAnim('throw MISS');
						bob.playAnim('grumpy');
						trace(conductor.getMil() - (bird.time + bird.actionTime(2)));
						changeHealth(-20);
					}
				}
				if (conductor.getMil() > bird.time + bird.actionTime(3))
				{
					bird.goOut(bird.actionTime(3));
				}
			});

			if (conductor.pastBeat() && !isGameover)
			{
				bob.playAnim('idle');
				if (bosip.animation.finished || bosip.animation.curAnim.name == 'idle')
				{
					bosip.playAnim('idle');
				}

				if (healthP1.angle != 5)
				{
					FlxTween.tween(healthP1, {angle: 5}, 0.3, {ease: FlxEase.expoOut});
					FlxTween.tween(healthP2, {angle: -5}, 0.3, {ease: FlxEase.expoOut});
				}
				else
				{
					FlxTween.tween(healthP1, {angle: -5}, 0.3, {ease: FlxEase.expoOut});
					FlxTween.tween(healthP2, {angle: 5}, 0.3, {ease: FlxEase.expoOut});
				}
			}

			if (FlxG.keys.anyJustPressed(inputKeys) && !isGameover)
			{
				bosip.playAnim('throw');
				throwSound.play(true);

				var closestTimedBird:Bird = null;
				birdList.forEachAlive(function(bird)
				{
					if (getRank(bird.time) == rankings.length)
						return;
					if (closestTimedBird == null)
						closestTimedBird = bird;
					if (Math.abs(conductor.getMil() - bird.time) < Math.abs(conductor.getMil() - closestTimedBird.time))
						closestTimedBird = bird;
				});

				if (closestTimedBird != null)
				{
					var tempRank = getRank(closestTimedBird.time);
					trace(tempRank);
					ratingSprite.add(new RatingSprite(tempRank));
					rankList.push({time: closestTimedBird.time, difference: conductor.getMil() - closestTimedBird.time});
					closestTimedBird.shouldRank = false;
					trace(conductor.getMil() - closestTimedBird.time);
					switch (tempRank)
					{
						case 0:
							changeHealth(15);
						case 1:
							changeHealth(5);
						case 2:
							changeHealth(-5);
						case 3:
							changeHealth(-10);
					}
				}
			}

			if (isGameover && FlxG.keys.anyJustPressed([ENTER, SPACE]))
			{
				retry();
			}
		}

		// ! THIS IS DEBUG CODE
		if (FlxG.keys.justPressed.F2)
		{
			songInst.onComplete();
		}
		if (FlxG.keys.justPressed.F1)
		{
			FlxG.switchState(new PlayState());
		}
	}

	var preBeats = 4;

	function organizeNotes()
	{
		var noteList = songJson.chart;

		var usedTimeList = [];

		birdList.forEachAlive(function(bird)
		{
			usedTimeList.push(bird.time);
		});

		for (note in noteList)
		{
			if (!usedTimeList.contains(note.time) && conductor.getMil() < note.time)
			{
				birdList.add(new Bird(note.id, note.time, conductor.getBPM().bpm));
			}
		}
	}

	function getRank(time:Int)
	{
		var difference = Math.abs(conductor.getMil() - time);

		for (index => rank in rankings)
		{
			if (difference < rank)
				return index;
		}
		return rankings.length;
	}

	function gameover()
	{
		isGameover = true;
		bob.playAnim('gameover');
		bosip.playAnim('gameover');
		conductor.pause();

		FlxTween.tween(songInst, {volume: 0}, 2);
		FlxTween.tween(gameoverBlack, {alpha: 0.9}, 2);
	}

	function retry()
	{
		bob.playAnim('retry');
		bosip.playAnim('idle');
		FlxTween.tween(gameoverBlack, {alpha: 0}, 2, {
			onComplete: (tween) ->
			{
				FlxG.switchState(new PlayState());
			}
		});
	}

	function win()
	{
		bob.playAnim('happy');
		bosip.playAnim('happy');
		var startFade = new Timer(1000);
		startFade.run = () ->
		{
			openSubState(new SongFinishedSubState(rankList));
			startFade.stop();
		}
	}

	function changeHealth(health:Int)
	{
		bosip.health += health;
		if (bosip.health < 0)
		{
			bosip.health = 0;
		}
		else if (bosip.health > 100)
		{
			bosip.health = 100;
		}

		healthBar.percent = bosip.health;

		FlxTween.tween(healthP1, {x: healthBar.percent / 100 * 590 + 255}, 0.5, {ease: FlxEase.expoOut});
		FlxTween.tween(healthP2, {x: healthBar.percent / 100 * 590 + 305}, 0.5, {ease: FlxEase.expoOut});

		if (healthBar.percent <= 0)
		{
			gameover();
		}
	}

	override function onFocusLost()
	{
		if (conductor != null)
			conductor.pause();
		else
			countConductor.pause();
		super.onFocusLost();
	}

	override function onFocus()
	{
		if (!isGameover)
		{
			if (conductor != null)
			{
				conductor.unPause();
				songInst.time = conductor.getMil();
			}
			else
				countConductor.unPause();
		}

		super.onFocus();
	}
}
