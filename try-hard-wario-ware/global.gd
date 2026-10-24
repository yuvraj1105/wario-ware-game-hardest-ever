extends Node
## global.gd - autoload singleton for a WarioWare-style analog horror platformer.
##
## Setup: Project > Project Settings > Globals (Autoload) > add this file, name it "Global".
## (Don't give it a class_name - that clashes with the autoload name.)
##
## Typical flow from your game-loop script:
##   Global.new_run()                       # when the player hits Play
##   Global.apply_speed()                   # right before a microgame starts
##   var won: bool = await microgame.finished
##   Global.reset_time()                    # right after it ends
##   if Global.register_result(won, boss):  # true = out of lives
##       get_tree().change_scene_to_file("res://gameover.tscn")

signal lives_changed(value: int)
signal score_changed(value: int)
signal speed_changed(value: float)
signal corruption_changed(value: float)
signal game_over

const START_LIVES := 4
const MAX_SPEED := 2.0
const SPEED_STEP := 0.15
const SPEED_UP_EVERY := 5   # microgames between speed-ups
const BOSS_EVERY := 10      # every Nth microgame is a boss
const SAVE_PATH := "user://save.cfg"
const GLITCH_CHARS := "#%&@$?/|<>0123456789"

## Broadcast lines get creepier as corruption rises (one pool per tier).
const BROADCASTS := [
	["PLEASE STAND BY", "TAPE 07 - SIDE A", "ENJOY THE PROGRAM", "NOW PLAYING"],
	["TRACKING UNSTABLE", "THIS PROGRAM IS NOT SCHEDULED", "WHO RECORDED THIS TAPE?", "DO NOT ADJUST YOUR SET"],
	["THIS IS NOT A TEST", "YOU HAVE BEEN WATCHING FOR A LONG TIME", "WHY ARE YOU STILL PLAYING?", "IT KNOWS WHICH CHANNEL YOU ARE ON"],
	["WE CAN SEE YOU", "DO NOT LOOK AWAY", "THERE IS NO SIDE B", "IT IS STANDING BEHIND YOU", "KEEP PLAYING"],
]

var lives := START_LIVES:
	set(value):
		lives = clampi(value, 0, START_LIVES)
		lives_changed.emit(lives)

var score := 0:
	set(value):
		score = value
		score_changed.emit(score)

## 1.0 = normal. Rises every few microgames (the WarioWare "speed up").
var speed := 1.0:
	set(value):
		speed = clampf(value, 1.0, MAX_SPEED)
		speed_changed.emit(speed)

## 0.0 = clean broadcast ... 1.0 = it knows you're watching.
## Drive your VHS shader, wallpaper colour, creepy text and scares from this.
var corruption := 0.0:
	set(value):
		corruption = clampf(value, 0.0, 1.0)
		corruption_changed.emit(corruption)

var high_score := 0
var games_played := 0

## Accessibility: bind to a settings toggle, and check it before any
## flashing, strobing or sudden face-flash effects.
var reduced_effects := false


func _ready() -> void:
	randomize()
	_load_save()


# --- run flow -----------------------------------------------------------------

func new_run() -> void:
	games_played = 0
	score = 0
	lives = START_LIVES
	speed = 1.0
	corruption = 0.0
	reset_time()


func is_boss_round() -> bool:
	return (games_played + 1) % BOSS_EVERY == 0


## Call once per finished microgame. Returns true when the run is over.
func register_result(won: bool, was_boss := false) -> bool:
	games_played += 1
	if won:
		score += 300 if was_boss else 100
		corruption += 0.035
		if was_boss:
			lives += 1  # boss tapes give a life back
	else:
		lives -= 1
		corruption += 0.08
	if games_played % SPEED_UP_EVERY == 0:
		speed += SPEED_STEP
	if lives <= 0:
		_end_run()
		return true
	return false


# --- WarioWare speed trick ----------------------------------------------------

## Scales physics, timers, tweens and audio pitch by the current speed.
func apply_speed() -> void:
	Engine.time_scale = speed
	AudioServer.playback_speed_scale = speed


func reset_time() -> void:
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0


# --- analog horror helpers ----------------------------------------------------

## 0..3 - use it to swap music, sprites, wallpaper, enemy variants...
func corruption_tier() -> int:
	return mini(int(corruption * BROADCASTS.size()), BROADCASTS.size() - 1)


func broadcast_message() -> String:
	var pool: Array = BROADCASTS[corruption_tier()]
	return str(pool.pick_random())


## Randomly swaps letters for junk. Default strength scales with corruption.
func glitch_text(text: String, amount := -1.0) -> String:
	if amount < 0.0:
		amount = corruption * 0.25
	var out := ""
	for ch in text:
		if ch != " " and randf() < amount:
			out += GLITCH_CHARS[randi() % GLITCH_CHARS.length()]
		else:
			out += ch
	return out


## True with probability `chance`, but only once corruption >= min_corruption.
## e.g. if Global.horror_roll(0.5, 0.3) and not Global.reduced_effects: flash_face()
func horror_roll(min_corruption: float, chance: float) -> bool:
	return corruption >= min_corruption and randf() < chance


## Mirrored controls kick in late in the run.
func roll_flipped_controls() -> bool:
	return horror_roll(0.5, 0.3)


# --- saving -------------------------------------------------------------------

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("settings", "reduced_effects", reduced_effects)
	cfg.save(SAVE_PATH)


func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	high_score = cfg.get_value("progress", "high_score", 0)
	reduced_effects = cfg.get_value("settings", "reduced_effects", false)


func _end_run() -> void:
	high_score = maxi(high_score, score)
	save()
	game_over.emit()
