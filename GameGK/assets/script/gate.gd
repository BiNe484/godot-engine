extends Area2D
@onready var win = $"../win"

@export var required_score: int = 100
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var can_open: bool = false
var is_opening: bool = false


func _ready():
	anim.play("open")
	anim.frame = 0
	anim.stop()
	collision_shape.disabled = false

	# Connect signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# Score signal
	if typeof(GameManager) != TYPE_NIL:
		if not GameManager.score_changed.is_connected(_on_score_changed):
			GameManager.score_changed.connect(_on_score_changed)

	can_open = GameManager.score >= required_score


func _on_score_changed(new_score: int) -> void:
	can_open = new_score >= required_score


func _on_body_entered(body: Node) -> void:
	if not can_open or is_opening:
		return

	if body and is_instance_valid(body):
		if body.is_in_group("player") or body.name == "Player":
			_open_gate(body)


func _open_gate(player: Node):
	is_opening = true

	anim.play("open")
	await get_tree().create_timer(1.0).timeout

	player.visible = false
	player.set_process(false)
	player.set_physics_process(false)
	win.play()
	if typeof(GameManager) != TYPE_NIL:
		GameManager.win()
