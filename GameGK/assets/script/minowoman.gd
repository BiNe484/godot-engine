extends CharacterBody2D

@export var score_value: int = 150
@export var speed = 65.0
@export var chase_speed = 110.0
@export var attack_range = 50.0
@export var detection_range = 200.0
@export var attack_damage = 15.0
@export var attack_cooldown = 1.0
@export var stun_duration = 1.0
@export var idle_duration_min := 3
@export var idle_duration_max := 5
var is_idle_wandering = false


# HP System
@export var max_health = 60.0
var current_health = max_health

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var player = null
var is_attacking = false
var is_dead = false
var is_taking_damage = false
var facing_right = false
var can_attack = true
var attack_timer = 0.0

var anim: AnimatedSprite2D
var detection_area: Area2D
var collision_shape: CollisionShape2D
var health_bar: ProgressBar  # ← Thanh máu

func _ready():
	anim = get_node_or_null("AnimatedSprite2D")
	detection_area = get_node_or_null("DetectionArea")
	collision_shape = get_node_or_null("CollisionShape2D")
	
	if not anim:
		push_error("AnimatedSprite2D not found!")
		return
	
	if detection_area:
		if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
			detection_area.body_entered.connect(_on_detection_area_body_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
			detection_area.body_exited.connect(_on_detection_area_body_exited)
	else:
		push_warning("DetectionArea not found!")
	
	# ← TẠO THANH MÁU
	create_health_bar()
	
	play_anim("idle")

func _physics_process(delta):
	
	update_floor_check_direction()
	if is_dead or not anim:
		return
		
	# Nếu đang bị đánh thì đứng yên và không làm gì hết
	if is_taking_damage:
		velocity.x = 0
		move_and_slide()
		return
		
	# Attack cooldown
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	if not is_on_floor():
		velocity.y += gravity * delta

	# Chạy chase hoặc patrol
	if player and is_instance_valid(player) and not is_attacking:
		chase_player()
	elif not is_attacking:
		patrol()

	move_and_slide()

func update_floor_check_direction():
	var fc = $FloorCheck
	if facing_right:
		fc.target_position = Vector2(17, 48)
	else:
		fc.target_position = Vector2(-17, 48)

func patrol():
	if is_idle_wandering:
		velocity.x = 0
		play_anim("idle")
		return

	velocity.x = speed if facing_right else -speed

	# --- QUAY ĐẦU KHI ĐẾN MÉP SÀN ---
	if not $FloorCheck.is_colliding():
		facing_right = !facing_right
		start_idle_wander()
		return

	# --- QUAY ĐẦU KHI GẶP TƯỜNG ---
	if is_on_wall():
		facing_right = !facing_right
		start_idle_wander()
		return

	play_anim("walk")

	if randf() < 0.005:
		start_idle_wander()

func start_idle_wander():
	if is_idle_wandering or is_dead:
		return
	is_idle_wandering = true
	play_anim("idle")
	
	var t = randf_range(idle_duration_min, idle_duration_max)
	var timer = Timer.new()
	timer.wait_time = t
	timer.one_shot = true
	add_child(timer)
	timer.start()
	timer.timeout.connect(_on_idle_wander_finished)
	
func _on_idle_wander_finished():
	is_idle_wandering = false

func chase_player():
	if is_taking_damage:
		return
		
	if not player or not is_instance_valid(player):
		player = null
		play_anim("idle")
		return

	# Nếu đang chạy và đập vào tường → quay đầu
	if is_on_wall():
		var col = get_last_slide_collision()
		if col and not col.get_collider().is_in_group("player"):
			facing_right = not facing_right
			velocity.x = (1 if facing_right else -1) * chase_speed
			return

	if not $FloorCheck.is_colliding():
		facing_right = !facing_right
		velocity.x = 0
		play_anim("idle")
		return

	var distance = global_position.distance_to(player.global_position)
	
	if distance <= attack_range and can_attack:
		velocity.x = 0
		attack()
	elif distance <= detection_range:
		var direction = sign(player.global_position.x - global_position.x)
		velocity.x = direction * chase_speed
		facing_right = direction > 0
		play_anim("walk")
	else:
		player = null
		play_anim("idle")

func attack():
	if is_attacking or not anim or not can_attack or is_taking_damage:
		return
	
	is_attacking = true
	can_attack = false
	attack_timer = attack_cooldown
	velocity.x = 0
	
	play_anim("attack")

	await get_tree().create_timer(0.5).timeout
	if is_taking_damage or is_dead:
		is_attacking = false
		return
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range:
			if player.has_method("take_damage"):
				var knock_dir = sign(player.global_position.x - global_position.x)
				player.take_damage(attack_damage, knock_dir)

	# Chờ animation kết thúc
	await get_tree().process_frame
	await anim.animation_finished
	
	is_attacking = false

func take_damage(_damage_amount = 10):
	if is_dead or is_taking_damage:
		return

	is_taking_damage = true
	current_health -= _damage_amount
	update_health_bar()

	if current_health <= 0:
		die()
		return

	velocity.x = 0
	play_anim("hurt")  # hoặc random
	hit_flash_effect()

	# Timer để reset trạng thái stun
	var t = Timer.new()
	t.wait_time = stun_duration
	t.one_shot = true
	add_child(t)
	t.start()
	t.timeout.connect(func():
		is_taking_damage = false
		if not is_dead:
			play_anim("idle")
	)

# Hiệu ứng flash chạy song song
func hit_flash_effect():
	if not anim:
		return
	
	# Tạo Tween để flash màu đỏ
	var tween = create_tween()
	tween.set_loops(3)  # Flash 3 lần
	tween.tween_property(anim, "modulate", Color(1, 0.3, 0.3, 1), 0.08)
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.08)
	
	# Đảm bảo reset về màu gốc khi kết thúc
	tween.finished.connect(func(): 
		if anim:
			anim.modulate = Color(1, 1, 1, 1)
	)

func die():
	if is_dead:
		return
	
	print("[Enemy] DIED!")
	is_dead = true
	# Thêm điểm cho player/game manager trước khi queue_free
	if typeof(GameManager) != TYPE_NIL:
		GameManager.add_score(score_value)
	else:
		print("[Enemy] WARNING: GameManager not found; cannot add score.")

	velocity = Vector2.ZERO
	
	# TẮT physics process
	set_physics_process(false)
	
	# Disable collision
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# ĐẢM BẢO modulate bình thường trước khi chết
	if anim:
		anim.modulate = Color(1, 1, 1, 1)
		play_anim("dead")
		
		if anim.is_playing():
			await anim.animation_finished
		else:
			await get_tree().create_timer(1.0).timeout
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished

	queue_free()

func play_anim(anim_name: String):
	if not anim or not anim.sprite_frames:
		return
	
	var full_name = anim_name + ("_left" if not facing_right else "")
	
	if anim.sprite_frames.has_animation(full_name):
		anim.play(full_name)
	elif anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)

func _on_detection_area_body_entered(body):
	if body and is_instance_valid(body):
		if body.name == "Player" or body.is_in_group("player"):
			player = body
			print("Player detected!")

func _on_detection_area_body_exited(body):
	if body == player:
		player = null
		print("Player lost!")

# ===== THANH MÁU =====
func create_health_bar():
	# Tạo ProgressBar
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(40, 4)  # Nhỏ nhỏ thôi
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	
	# Style thanh máu
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Nền đen
	style_bg.set_corner_radius_all(2)
	
	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(0, 0.8, 0, 1)  # Màu xanh lá
	style_fg.set_corner_radius_all(2)
	
	health_bar.add_theme_stylebox_override("background", style_bg)
	health_bar.add_theme_stylebox_override("fill", style_fg)
	
	# Đặt vị trí trên đầu enemy
	health_bar.position = Vector2(-20, -40)  # Điều chỉnh tùy sprite
	
	add_child(health_bar)
	print("[Enemy] Health bar created!")

func update_health_bar():
	if not health_bar:
		return
	
	var health_percent = (current_health / max_health) * 100.0
	health_bar.value = health_percent
	
	# Đổi màu theo máu
	var style = health_bar.get_theme_stylebox("fill")
	if style is StyleBoxFlat:
		if health_percent > 60:
			style.bg_color = Color(0, 0.8, 0, 1)  # Xanh lá
		elif health_percent > 30:
			style.bg_color = Color(1, 0.8, 0, 1)  # Vàng
		else:
			style.bg_color = Color(1, 0, 0, 1)  # Đỏ
