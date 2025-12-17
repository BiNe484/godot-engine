extends Node2D

@onready var btn_play: Button = $btnPlay
@onready var btn_quit: Button = $btnQuit

func _ready():
	btn_play.pressed.connect(_on_play_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	# Chuyển sang scene Level
	get_tree().change_scene_to_file("res://scences/level.tscn")


func _on_quit_pressed() -> void:
	# Thoát game
	get_tree().quit()
