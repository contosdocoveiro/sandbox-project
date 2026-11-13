extends Node
class_name HealthComponent

@export var damage_numbers_component : DamageNumbersComponent
@export var MAX_HEALTH := 10.0
@export var outline_shader_material : Material
@export var body_path: NodePath

@onready var invincibility_timer = $InvincibilityTime

var invincible := false
var health : float
var tween
var body : CanvasItem

signal damage_taken(attack : Attack)

func _ready():
	health = MAX_HEALTH
	
	if not body_path.is_empty():
		body = get_node_or_null(body_path) as CanvasItem
	if body == null and owner:
		body = owner.find_child("Body", true, false) as CanvasItem
	if body == null:
		push_warning("%s: no visual body; damage flash disabled." % get_path())
		return
	
	tween = create_tween().set_loops()
	tween.pause()
	tween.tween_property(owner.find_child("Body"), "modulate", Color.WHITE, 0.1)
	tween.tween_property(owner.find_child("Body"), "modulate", Color.RED, 0.1)

func damage(attack: Attack):
	if(invincible):
		return
	
	health -= attack.attack_damage
	emit_signal("damage_taken", attack)
	
	if(owner.is_in_group("player")):
		invulnerability_start()
		play_player_damage_effect()
	
	if damage_numbers_component:
		damage_numbers_component.display_damage_numbers(attack.attack_damage)
	
	if health <= 0:
		get_parent().queue_free()

func invulnerability_start():
	if body:
		body.set_material(null)
	invincible = true
	invincibility_timer.wait_time = 1.0
	invincibility_timer.start()

func play_player_damage_effect():
	tween.play()


func _on_invincibility_time_timeout() -> void:
	if tween:
		tween.kill()
		tween = null
		
	if body:
		tween = create_tween().set_loops()
		tween.stop()
		tween.tween_property(body, "modulate", Color.WHITE, 0.1)
		tween.tween_property(body, "modulate", Color.RED, 0.1)
		body.set_material(outline_shader_material)
	
	invincible = false
