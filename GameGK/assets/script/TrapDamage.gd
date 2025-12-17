extends Area2D

@export var damage := 15.0
@export var damage_interval := 1.0   # 1 giây gây dame một lần

var can_damage := true

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

var bodies_in_area = []

func _on_body_entered(body):
	if body.is_in_group("player"):
		bodies_in_area.append(body)
		_damage_loop(body)

func _on_body_exited(body):
	if body in bodies_in_area:
		bodies_in_area.erase(body)

func _damage_loop(body):
	while body in bodies_in_area:
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("[Trap] Player took damage: ", damage)
		await get_tree().create_timer(damage_interval).timeout
