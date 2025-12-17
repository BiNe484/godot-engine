extends Control

# --- UI references ---
@onready var health_bar = $MarginContainer/HBoxContainer/BarsContainer/HealthBar/ProgressBar
@onready var energy_bar = $MarginContainer/HBoxContainer/BarsContainer/EnergyBar/ProgressBar
@onready var health_label = $MarginContainer/HBoxContainer/BarsContainer/HealthBar/Label
@onready var energy_label = $MarginContainer/HBoxContainer/BarsContainer/EnergyBar/Label

# Score UI 
@onready var score_label = $ScoreLabel

# Game Over panel
@onready var gameover_panel = $GameOverPanel
@onready var gameover_label = $GameOverPanel/VBoxContainer/GameOverLabel
@onready var play_again_button = $GameOverPanel/VBoxContainer/PlayAgainButton

# Win UI
@onready var win_panel = $WinPanel
@onready var win_label = $WinPanel/VBoxContainer/WinLabel
@onready var win_play_again_button = $WinPanel/VBoxContainer/PlayAgainButton
@onready var win_main_menu_button = $WinPanel/VBoxContainer/MainMenuButton

# Pause UI
@onready var pause_panel = $PausePanel
@onready var pause_resume_button = $PausePanel/VBoxContainer/ResumeButton
@onready var pause_main_menu_button = $PausePanel/VBoxContainer/MainMenuButton

# Dim overlay to darken background
@onready var dim_overlay = $DimOverlay
# --- Player reference ---
var player: Node = null

# Debug: Biến để theo dõi thay đổi
var last_health = -1.0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	GameManager.hud = self
	print("[HUD] HUD assigned to GameManager")

		

	# Nút Play Again
	if play_again_button and not play_again_button.pressed.is_connected(_on_play_again_pressed):
		play_again_button.pressed.connect(_on_play_again_pressed)
	# Win buttons
	if win_play_again_button and not win_play_again_button.pressed.is_connected(_on_play_again_pressed):
		win_play_again_button.pressed.connect(_on_play_again_pressed)
	if win_main_menu_button and not win_main_menu_button.pressed.is_connected(_on_main_menu_pressed):
			win_main_menu_button.pressed.connect(_on_main_menu_pressed)
	# Pause buttons
	if pause_resume_button and not pause_resume_button.pressed.is_connected(_on_resume_pressed):
		pause_resume_button.pressed.connect(_on_resume_pressed)
	if pause_main_menu_button and not pause_main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		pause_main_menu_button.pressed.connect(_on_main_menu_pressed)

	gameover_panel.visible = false
	win_panel.visible = false
	pause_panel.visible = false
	dim_overlay.visible = false
	gameover_panel.visible = false

	update_bars()
	update_score_label(GameManager.score)

func _process(_delta: float) -> void:
	# Tự động tìm player
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player:
			print("[HUD] Player found in _process")
	
	# Cập nhật UI mỗi frame
	if player and is_instance_valid(player):
		# Debug: In ra khi máu thay đổi
		if player.current_health != last_health:
			print("[HUD] Health changed: ", last_health, " -> ", player.current_health)
			last_health = player.current_health
		
		update_bars()

func update_bars() -> void:
	if not health_bar or not energy_bar:
		print("[HUD] ERROR: health_bar or energy_bar is null!")
		return
	
	# Kiểm tra player có tồn tại không
	if not player or not is_instance_valid(player):
		# Nếu player không tồn tại, vẫn có thể đặt bar về 0
		return
	
	# Đọc TRỰC TIẾP từ player
	var hp = player.current_health
	var max_hp = player.max_health
	var energy = player.current_energy
	var max_energy = player.max_energy
	
	# Cập nhật thanh máu/năng lượng
	var health_value = (hp / max_hp) * 100.0 if max_hp > 0 else 0
	var energy_value = (energy / max_energy) * 100.0 if max_energy > 0 else 0
	
	health_bar.value = health_value
	energy_bar.value = energy_value
	
	# Cập nhật text
	if health_label:
		health_label.text = "HP: %d/%d" % [int(hp), int(max_hp)]
	
	if energy_label:
		energy_label.text = "EN: %d/%d" % [int(energy), int(max_energy)]
	
	# Đổi màu thanh máu theo %
	var health_percent = hp / max_hp if max_hp > 0 else 1.0
	if health_percent < 0.3:
		health_bar.modulate = Color.RED
	elif health_percent < 0.6:
		health_bar.modulate = Color.YELLOW
	else:
		health_bar.modulate = Color.GREEN

func emit_initial_score():
	# ensure UI & Gate know current score on load
	update_score_label(GameManager.score)
	# if GameManager has signal for score_changed it's already connected by Gate; we also connect here if needed
	if typeof(GameManager) != TYPE_NIL:
		var cb := Callable(self, "_on_score_changed")
		if not GameManager.is_connected("score_changed", cb):
			GameManager.connect("score_changed", cb)

func _on_score_changed(new_score:int) -> void:
	update_score_label(new_score)
	
# Called by GameManager to update label
func update_score_label(new_score: int) -> void:
	if score_label:
		score_label.text = "SCORE: %d / %d" % [new_score, 500]

# Win UI
func show_win_panel() -> void:
	if win_panel:
		win_label.text = "You Win!"
		dim_overlay.visible = true
		win_panel.visible = true
		# Pause
		Engine.time_scale = 0.0

# Main menu handler
func _on_main_menu_pressed() -> void:
	# Replace with your main menu path
	get_tree().paused = false
	var main_path = "res://scences/main_menu.tscn"
	if main_path != "":
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file(main_path)
	else:
		print("[HUD] Main scene path not set in GameManager")

# Show Game Over screen (called by GameManager.game_over())
func show_game_over_panel() -> void:
	if gameover_panel:
		gameover_label.text = "Game Over"
		gameover_panel.visible = true

# Handler nút Play Again
func _on_play_again_pressed() -> void:
	# Hide everything, unpause, ask GameManager to reset
	gameover_panel.visible = false
	win_panel.visible = false
	pause_panel.visible = false
	dim_overlay.visible = false
	Engine.time_scale = 1.0
	if typeof(GameManager) != TYPE_NIL:
		GameManager.reset_game()

# Pause/resume handling
func _input(event):
	# Use Input.is_action_just_pressed("ui_cancel") OR KEY_ESCAPE
	if event.is_action_pressed("ui_cancel") and not (GameManager.is_game_over or GameManager.is_game_won):
		_toggle_pause()

func _toggle_pause():
	if pause_panel.visible:
		_resume_game()
	else:
		_pause_game()

func _pause_game():
	dim_overlay.visible = true
	pause_panel.visible = true

	Engine.time_scale = 0.0

func _resume_game():
	pause_panel.visible = false
	dim_overlay.visible = false

	Engine.time_scale = 1.0

func _on_resume_pressed() -> void:
	_resume_game()
