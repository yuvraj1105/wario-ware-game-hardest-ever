extends Node2D
## Title screen. The buttons just call into the Global autoload (global.gd), so
## scene paths live in one place. The glitch effects get nastier the further your
## last run got (Global.corruption stays up until a new run starts) and switch
## off completely when Global.reduced_effects is on.

@onready var title: RichTextLabel = $title
@onready var start_button: Button = $VBoxContainer/Button
@onready var settings_button: Button = $VBoxContainer/Button2
@onready var quit_button: Button = $VBoxContainer/Button3

var _original := {}  # Control -> the text you set in the editor
var _busy := {}      # Control -> present while its glitch is playing
var _next_glitch := 2.0


func _ready() -> void:
	start_button.pressed.connect(Global.start_game)
	settings_button.pressed.connect(Global.open_settings)
	quit_button.pressed.connect(Global.quit_game)

	for node: Control in [title, start_button, settings_button, quit_button]:
		_original[node] = str(node.get("text"))
	for button: Button in [start_button, settings_button, quit_button]:
		button.mouse_entered.connect(_glitch.bind(button, 0.35))
		button.focus_entered.connect(_glitch.bind(button, 0.35))

	_add_footer()
	start_button.grab_focus()  # Enter / Space / gamepad work straight away


func _process(delta: float) -> void:
	if Global.reduced_effects:
		return
	_next_glitch -= delta
	if _next_glitch <= 0.0:
		_next_glitch = randf_range(1.5, 4.5) * (1.0 - Global.corruption * 0.6)
		_glitch(title, 0.15 + Global.corruption * 0.35)


## Briefly scrambles a label's or button's text, then puts it back.
func _glitch(node: Control, amount: float) -> void:
	if Global.reduced_effects or _busy.has(node):
		return
	_busy[node] = true
	node.set("text", Global.glitch_text(_original[node], amount))
	await get_tree().create_timer(0.12).timeout
	node.set("text", _original[node])
	_busy.erase(node)


## A "please stand by" line along the bottom (creepier after a long run),
## plus your best score once you have one.
func _add_footer() -> void:
	var text := Global.broadcast_message()
	if Global.high_score > 0:
		text += "    BEST %d" % Global.high_score

	var footer := Label.new()
	footer.text = text
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 22)
	footer.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	footer.add_theme_color_override("font_outline_color", Color.BLACK)
	footer.add_theme_constant_override("outline_size", 6)

	# A CanvasLayer parent lets the anchors use the real screen size
	# (anchors don't work for Controls sitting directly under a Node2D).
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 16)
