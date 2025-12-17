extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# ===== CONFIG =====
@export var left_limit: float = 100.0
@export var right_limit: float = 700.0
@export var move_speed: float = 140.0
@export var jump_velocity: float = -500.0
@export var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Random action timer
var action_timer: float = 0.0
var next_action_time: float = 1.0

# State
var current_dir: int = 1   # 1 = right, -1 = left
var state: String = "idle" # idle, run, jump, attack, dash

func _ready():
	randomize()
	_pick_new_action()

func _physics_process(delta):

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# ===== ACTION STATES =====
	match state:

		"idle":
			velocity.x = move_toward(velocity.x, 0, 20)
			anim.play("idle")

		"run":
			velocity.x = current_dir * move_speed
			anim.flip_h = current_dir < 0
			anim.play("run")

		"jump":
			velocity.x = current_dir * move_speed * 0.5
			anim.play("fly")

		"attack":
			velocity.x = 0
			anim.play("attack")

		"dash":
			velocity.x = current_dir * 500
			anim.flip_h = current_dir < 0
			anim.play("dash")

	move_and_slide()

	# ===== TIMER FOR NEXT ACTION =====
	action_timer += delta
	if action_timer >= next_action_time:
		_pick_new_action()

	# ===== Prevent leaving screen =====
	_border_check()


# ============================================================
#                   RANDOM ACTION LOGIC
# ============================================================
func _pick_new_action():
	action_timer = 0.0
	next_action_time = randf_range(0.7, 1.8)

	var choices = [
		"idle",
		"run",
		"run",
		"jump",
		"attack",
		"dash"
	]

	state = choices[randi() % choices.size()]

	# Random hướng khi chạy hoặc dash
	if state in ["run", "dash"]:
		current_dir = 1 if randf() > 0.5 else -1

	# Khi nhảy → bật velocity
	if state == "jump" and is_on_floor():
		velocity.y = jump_velocity


# ============================================================
#           GIỚI HẠN KHÔNG CHO MODEL ĐI RA NGOÀI
# ============================================================
func _border_check():
	if global_position.x < left_limit:
		global_position.x = left_limit + 2
		current_dir = 1
	elif global_position.x > right_limit:
		global_position.x = right_limit - 2
		current_dir = -1
