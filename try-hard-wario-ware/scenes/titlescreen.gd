extends Node2D

@onready var start_button: Button = $VBoxContainer/Button
@onready var settings_button: Button = $VBoxContainer/Button2
@onready var quit_button: Button = $VBoxContainer/Button3

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://level_1.tscn") # change to your game scene's path

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://settings.tscn") # or show a settings panel instead

func _on_quit_pressed() -> void:
	get_tree().quit()
	
