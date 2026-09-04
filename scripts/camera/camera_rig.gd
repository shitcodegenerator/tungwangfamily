class_name CameraRig
extends Camera2D
## 鏡頭：平滑跟隨目前領頭角色，並以世界邊界限制，不讓畫面看到主城外的空白。

## 讓鏡頭中心落在角色身體而非腳底。
const TARGET_OFFSET := Vector2(0.0, -20.0)

var target: Node2D


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	limit_smoothed = true
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func set_world_bounds(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


func follow(new_target: Node2D, snap: bool = false) -> void:
	target = new_target
	if snap and target != null:
		global_position = target.global_position + TARGET_OFFSET
		reset_smoothing()


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	global_position = target.global_position + TARGET_OFFSET
