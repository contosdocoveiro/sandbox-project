class_name EnemyAnimationComponent
extends AnimationComponent


func _ready() -> void:
	state_manager = actor.find_child("EnemyStateManagerComponent")

func animate():
	if(state_manager.current_state == "idle"):
		animation_player.play("idle")
	elif(state_manager.current_state == "running"):
		animation_player.play("run")
	elif(state_manager.current_state == "attacking"):
		animation_player.play("attack")
	elif(state_manager.current_state == "charging"):
		animation_player.play("charging")
	elif(state_manager.current_state == "charge end"):
		animation_player.play("charge end")
	elif(state_manager.current_state == "hurt"):
		animation_player.stop()
		animation_player.play("hurt")

func _process(delta: float) -> void:
	if(state_manager.current_state != "charge end" or 
	state_manager.current_state != "hurt"):
		if actor.velocity.x < -20 and not actor.sprite.flip_h:
			sprite.flip_h = true
		elif actor.velocity.x > 20 and actor.sprite.flip_h:
			sprite.flip_h = false
