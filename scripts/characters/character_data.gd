class_name CharacterData
extends Resource
## 單一角色的資料：外觀、速度、碰撞尺寸與微晃動相位。四位角色共用同一場景與腳本，只靠這份資料區分。

@export var id: StringName = &""
@export var display_name: String = ""
@export var sprite_sheet: Texture2D
@export var walk_speed: float = 96.0
## 站立微晃動的相位（秒），讓四人不會同步晃動。
@export var bob_phase: float = 0.0
@export var collision_size: Vector2 = Vector2(18.0, 10.0)
