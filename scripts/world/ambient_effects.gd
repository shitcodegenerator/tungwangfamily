class_name AmbientEffects
extends Node2D
## 城鎮生命感粒子：落葉（全天）、蝴蝶（白天）、螢火蟲（黃昏與夜晚）。
## 全部是 CPUParticles2D 純視覺效果，不帶碰撞、不影響角色與 Y-sort。

const LEAF_TEXTURE := preload("res://assets/effects/leaf.png")
const FIREFLY_TEXTURE := preload("res://assets/effects/firefly.png")
const BUTTERFLY_TEXTURE := preload("res://assets/effects/butterfly.png")

var leaves: CPUParticles2D
var butterflies: CPUParticles2D
var fireflies: CPUParticles2D


## middle_rect：中層樹洞街範圍；lower_rect：下層廣場範圍（世界座標）。
func setup(middle_rect: Rect2, lower_rect: Rect2) -> void:
	leaves = _make_leaves(middle_rect)
	butterflies = _make_butterflies(middle_rect)
	fireflies = _make_fireflies(lower_rect)
	for emitter: CPUParticles2D in [leaves, butterflies, fireflies]:
		add_child(emitter)


func set_daytime(state_index: int) -> void:
	if butterflies != null:
		butterflies.emitting = state_index == 0
	if fireflies != null:
		fireflies.emitting = state_index > 0


func _make_leaves(rect: Rect2) -> CPUParticles2D:
	var emitter := _base_emitter("Leaves", LEAF_TEXTURE, 24, 6.0)
	emitter.position = Vector2(rect.get_center().x, rect.position.y + 8.0)
	emitter.emission_rect_extents = Vector2(rect.size.x / 2.0, 8.0)
	emitter.direction = Vector2(0.35, 1.0)
	emitter.spread = 25.0
	emitter.gravity = Vector2(0.0, 10.0)
	emitter.initial_velocity_min = 16.0
	emitter.initial_velocity_max = 28.0
	emitter.angular_velocity_min = -90.0
	emitter.angular_velocity_max = 90.0
	emitter.color_ramp = _fade_gradient(0.1, 0.85)
	return emitter


func _make_butterflies(rect: Rect2) -> CPUParticles2D:
	var emitter := _base_emitter("Butterflies", BUTTERFLY_TEXTURE, 6, 7.0)
	emitter.position = rect.get_center()
	emitter.emission_rect_extents = rect.size / 2.0 - Vector2(48.0, 32.0)
	emitter.spread = 180.0
	emitter.gravity = Vector2.ZERO
	emitter.initial_velocity_min = 10.0
	emitter.initial_velocity_max = 18.0
	emitter.color_ramp = _fade_gradient(0.15, 0.85)
	var material := CanvasItemMaterial.new()
	material.particles_animation = true
	material.particles_anim_h_frames = 2
	material.particles_anim_v_frames = 1
	material.particles_anim_loop = true
	emitter.material = material
	emitter.anim_speed_min = 24.0
	emitter.anim_speed_max = 32.0
	return emitter


func _make_fireflies(rect: Rect2) -> CPUParticles2D:
	var emitter := _base_emitter("Fireflies", FIREFLY_TEXTURE, 26, 5.0)
	emitter.position = rect.get_center()
	emitter.emission_rect_extents = rect.size / 2.0 - Vector2(48.0, 32.0)
	emitter.spread = 180.0
	emitter.gravity = Vector2(0.0, -2.0)
	emitter.initial_velocity_min = 4.0
	emitter.initial_velocity_max = 10.0
	emitter.color_ramp = _fade_gradient(0.25, 0.75)
	emitter.emitting = false
	return emitter


func _base_emitter(node_name: String, texture: Texture2D, amount: int, lifetime: float) -> CPUParticles2D:
	var emitter := CPUParticles2D.new()
	emitter.name = node_name
	emitter.texture = texture
	emitter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	emitter.amount = amount
	emitter.lifetime = lifetime
	emitter.preprocess = lifetime
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.z_index = 6
	return emitter


## 出現與消失：alpha 在 fade_in 之前漸入、fade_out 之後漸出。
static func _fade_gradient(fade_in: float, fade_out: float) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(fade_in, Color(1, 1, 1, 1))
	gradient.add_point(fade_out, Color(1, 1, 1, 1))
	return gradient
