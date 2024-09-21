class_name HitboxComponent
extends Area2D

@export_category("Components")
@export var health_component : HealthComponent
@export var dash_component : Dash

func damage(attack: Attack): #tradução: dano (se lê dã -> noh)
	if dash_component:
		if dash_component.is_dashing():
			return
	if health_component:
		health_component.damage(attack)
