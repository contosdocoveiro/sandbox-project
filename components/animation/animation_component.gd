class_name AnimationComponent
extends Node2D

@export var actor : CharacterBody2D
@export var animation_player : AnimationPlayer
@export var sprite : Node2D
var current_animation : String
var can_transition : bool
var state_manager
	

func animate():
	pass
	
