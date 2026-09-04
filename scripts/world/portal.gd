class_name ScenePortal
extends Area2D
## 場景傳送門：領頭角色走進去時發出 entered。目標 "return" 代表回到進入前的場景與位置。
## 只偵測角色層（2），不阻擋移動；跟隨者踩到不會觸發。

signal entered(portal: ScenePortal)

const CHARACTER_LAYER_BIT := 2

var portal_id: String = ""
var target_scene: String = ""
var entry_name: String = "default"
## 從目標場景回來時，領頭者要站的位置（本場景世界座標）。
var return_position: Vector2 = Vector2.ZERO


func _init() -> void:
	collision_layer = 0
	collision_mask = CHARACTER_LAYER_BIT
	monitorable = false


func setup(id: String, target: String, entry: String, size: Vector2, return_point: Vector2) -> void:
	portal_id = id
	target_scene = target
	entry_name = entry
	return_position = return_point
	name = "Portal_" + id
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is PlayableCharacter and (body as PlayableCharacter).is_controlled:
		entered.emit(self)


func is_return() -> bool:
	return target_scene == "return"
