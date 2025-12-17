extends Node
signal score_changed(new_score: int)

# Game state
var score: int = 0
var is_game_over: bool = false
var is_game_won: bool = false

# UI control 
var hud: Node = null

func _ready():
	pass
	
# Thêm điểm
func add_score(amount: int) -> void:
	if is_game_over or is_game_won:
		return
	score += amount
	# emit cho gate / HUD
	emit_signal("score_changed", score)
	if hud and hud.has_method("update_score_label"):
		hud.update_score_label(score)
	print("[GameManager] Score now: ", score)

# Gọi khi player chết
func game_over() -> void:
	print("[GameManager] game_over() called. HUD = ", hud)
	if is_game_over:
		return
	is_game_over = true
	print("[GameManager] GAME OVER")
	if hud and hud.has_method("show_game_over_panel"):
		hud.show_game_over_panel()

@export var main_scene_path: String = "res://scences/level.tscn" 

# win()
func win() -> void:
	if is_game_over or is_game_won:
		return
	is_game_won = true
	print("[GameManager] YOU WIN!")
	if hud and hud.has_method("show_win_panel"):
		hud.show_win_panel()

func reset_game() -> void:
	# reset variables
	is_game_over = false
	is_game_won = false
	score = 0
	if hud and hud.has_method("update_score_label"):
		hud.update_score_label(score)
	if main_scene_path != "":
		var err = get_tree().change_scene_to_file(main_scene_path)
		if err != OK:
			print("[GameManager] change_scene_to_file failed: ", err)
			if "reload_current_scene" in get_tree():
				get_tree().reload_current_scene()
	else:
		if "reload_current_scene" in get_tree():
			get_tree().reload_current_scene()
		else:
			print("[GameManager] WARNING: main_scene_path empty and reload_current_scene unavailable. Please set main_scene_path in GameManager autoload.")
