extends CharacterBody2D

# ===== STATS =====
@export var max_health: float = 100.0
var current_health: float = max_health

@export var max_energy: float = 100.0
var current_energy: float = max_energy

# Combat
@export var attack_damage: float = 10.0
@export var skill_damage: float = 20.0
@export var attack_range: float = 50.0

#audio
var footstep_timer := 0.0
var footstep_interval := 0.35
@onready var jump = $jump
@onready var takedamage = $takedamage
@onready var diegameover = $die
@onready var step1 = $step1
@onready var basicattack = $attack
@onready var hit = $hit
@onready var skill = $skill
@onready var dash = $dash

# Movement constants
const SPEED = 200.0
const JUMP_VELOCITY = -250.0
const DASH_SPEED = 400.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 0.6
var can_dash := true

# State variables
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking = false
var is_dashing = false
var is_using_skill = false
var is_dead = false
var is_taking_damage = false
var dash_timer = 0.0
var dash_direction = 1
var regen_energy_timer := 0.0
var regen_health_timer := 0.0

# Coyote time
var coyote_time = 0.1
var coyote_timer = 0.0

# References
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	animated_sprite.animation_finished.connect(_on_animation_finished)
	add_to_group("player")

func _physics_process(delta):
	if is_dead:
		return
		# ===== AUTO REGEN =====
	regen_energy_timer += delta
	regen_health_timer += delta

	# Hồi 1 năng lượng mỗi giây
	if regen_energy_timer >= 1.0:
		regen_energy_timer = 0.0
		if current_energy < max_energy:
			current_energy = min(current_energy + 1, max_energy)

	# Hồi 2 máu mỗi 10 giây
	if regen_health_timer >= 10.0:
		regen_health_timer = 0.0
		if current_health < max_health:
			current_health = min(current_health + 2, max_health)

	# Dash timer
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			# Bật lại va chạm sau khi dash xong
			set_collision_layer_value(1, true)
			set_collision_mask_value(1, true)
	
	# Gravity
	if not is_on_floor() and not is_dashing:
		velocity.y += gravity * delta
	
	# Coyote time
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
	
	# Đang attack/skill/bị đánh thì không nhận input
	if is_attacking or is_using_skill or is_taking_damage:
		move_and_slide()
		return
	
	# === INPUT ===
	if Input.is_key_pressed(KEY_J):
		attack()
		return
	
	if Input.is_key_pressed(KEY_K):
		use_skill()
		return
	
	if Input.is_key_pressed(KEY_SHIFT) and not is_dashing and can_dash:
		var dash_cost := 20.0
		if current_energy >= dash_cost:
			var direction_axis = Input.get_axis("ui_left", "ui_right")
			# Nếu không nhấn hướng, dash theo hướng sprite đang quay
			var dash_dir = direction_axis
			if dash_dir == 0:
				dash_dir = -1 if animated_sprite.flip_h else 1
			current_energy -= dash_cost
			start_dash(dash_dir)
			return

	if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE)) and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		animated_sprite.play("fly")
		jump.play()

	var direction := 0
	if Input.is_key_pressed(KEY_A):
		direction = -1
		# Phát âm thanh bước chân
		if direction != 0 and is_on_floor() and not is_dashing:
			footstep_timer -= delta
			if footstep_timer <= 0:
				footstep_timer = footstep_interval
				step1.play()
		else:
			# reset khi đứng lại
			footstep_timer = 0
	elif Input.is_key_pressed(KEY_D):
		direction = 1
		# Phát âm thanh bước chân
		if direction != 0 and is_on_floor() and not is_dashing:
			footstep_timer -= delta
			if footstep_timer <= 0:
				footstep_timer = footstep_interval
				step1.play()
		else:
			# reset khi đứng lại
			footstep_timer = 0
	
	if is_dashing:
		velocity.x = dash_direction * DASH_SPEED
	elif direction != 0:
		velocity.x = direction * SPEED
		animated_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()
	update_animation(direction)

func update_animation(direction):
	if is_dashing:
		animated_sprite.play("dash")
		return
	
	if not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("fly")
		else:
			animated_sprite.play("stop_flying")
		return
	
	if direction != 0:
		if animated_sprite.animation != "run" and animated_sprite.animation != "stop_running":
			animated_sprite.play("run")
	else:
		if animated_sprite.animation == "run":
			animated_sprite.play("stop_running")
		elif animated_sprite.animation != "stop_running":
			animated_sprite.play("idle")

func attack():
	if is_attacking or is_using_skill or is_dashing or is_taking_damage:
		return
	
	is_attacking = true
	velocity.x = 0
	animated_sprite.play("attack")
	basicattack.play()
	
	# Gây sát thương cho enemy trong tầm
	deal_damage_to_enemies(attack_damage)

func use_skill():
	if is_attacking or is_using_skill or is_dashing or is_taking_damage:
		return
	
	var cost := 10.0
	if current_energy < cost:
		return
	
	current_energy -= cost
	
	is_using_skill = true
	velocity.x = 0
	animated_sprite.play("skill")
	skill.play()
	
	# Gây sát thương cho enemy trong tầm (skill mạnh hơn)
	deal_damage_to_enemies(skill_damage)

func deal_damage_to_enemies(damage: float):
	# Tìm tất cả enemy gần player
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	# Tạo hình chữ nhật phía trước player
	var shape = RectangleShape2D.new()
	shape.size = Vector2(attack_range, 60)
	query.shape = shape
	
	# Vị trí tấn công (phía trước player)
	var attack_offset = attack_range / 2
	if animated_sprite.flip_h:
		attack_offset = -attack_offset
	
	query.transform = Transform2D(0, global_position + Vector2(attack_offset, 0))
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var results = space_state.intersect_shape(query, 10)
	
	for result in results:
		var body = result.collider
		if body != self and body.has_method("take_damage"):
			print("[Player] Attacking: ", body.name)
			body.take_damage(damage)
			hit.play()

func start_dash(direction):
	is_dashing = true
	can_dash = false 
	dash_timer = DASH_DURATION
	dash_direction = direction
	velocity.y = 0
	animated_sprite.flip_h = direction < 0
	animated_sprite.play("dash")
	dash.play()
	
	# Vô hình
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# Bật lại dash sau cooldown
	await get_tree().create_timer(DASH_COOLDOWN).timeout
	can_dash = true

func take_damage(damage_amount: float = 1.0, knockback_direction: int = 0) -> void:
	if is_dead or is_taking_damage or is_dashing:  # Không nhận sát thương khi dash
		return
	
	current_health -= damage_amount
	takedamage.play()
	print("[Player] Took damage: ", damage_amount, " | HP: ", current_health, "/", max_health)
	
	if current_health <= 0.0:
		current_health = 0.0
		die()
		return
	
	is_taking_damage = true
	
	if knockback_direction != 0:
		velocity.x = knockback_direction * 300
		velocity.y = -100
	
	hit_effect()
	
	await get_tree().create_timer(0.4).timeout
	is_taking_damage = false

func hit_effect():
	var original_pos = position
	
	for i in range(3):
		animated_sprite.modulate = Color(1, 0.2, 0.2, 1)
		position = original_pos + Vector2(randf_range(-2, 2), 0)
		await get_tree().create_timer(0.05).timeout
		
		animated_sprite.modulate = Color(1, 1, 1, 1)
		position = original_pos
		await get_tree().create_timer(0.05).timeout
	
	position = original_pos
	animated_sprite.modulate = Color(1, 1, 1, 1)

func die():
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector2.ZERO
	diegameover.play()
	animated_sprite.play("death")
	set_physics_process(false)
	print("[Player] DIED!")
	
	# Gọi GameManager để xử lý Game Over (hiển thị UI, block input...)
	if typeof(GameManager) != TYPE_NIL:
		GameManager.game_over()
	else:
		print("[Player] WARNING: GameManager not found; cannot trigger game over UI.")


func _current_dir() -> int:
	var d := 0
	if Input.is_key_pressed(KEY_A):
		d = -1
	elif Input.is_key_pressed(KEY_D):
		d = 1
	return d

func _on_animation_finished():
	var anim_name = animated_sprite.animation
	
	match anim_name:
		"attack":
			is_attacking = false
			var dir := _current_dir()
			if dir != 0 or abs(velocity.x) > 5:
				animated_sprite.play("run")
			else:
				animated_sprite.play("idle")
		
		"skill":
			is_using_skill = false
			animated_sprite.play("stop_skill")
		
		"stop_skill":
			animated_sprite.play("idle")
		
		"stop_running":
			animated_sprite.play("idle")
		
		"stop_flying":
			if is_on_floor():
				animated_sprite.play("idle")
		
		"death":
			pass
