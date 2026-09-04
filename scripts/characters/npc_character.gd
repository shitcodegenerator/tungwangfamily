class_name NpcCharacter
extends StaticBody2D
## 站立待機的 NPC：外觀沿用 CharacterData 與主角相同的精靈表規格（240×256），只播 idle 動畫。
## 有碰撞（物理層 1，角色會被擋住）；互動由 TownWorld 另外建立的 Interactable 處理，這裡只負責轉向面對玩家。

const SPRITE_OFFSET := PlayableCharacter.SPRITE_OFFSET

@export var data: CharacterData

var facing: Vector2i = Vector2i.DOWN

@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func setup(character_data: CharacterData, facing_name: String = "down") -> void:
	data = character_data
	name = "Npc_" + String(data.id)
	sprite.sprite_frames = PlayableCharacter.build_sprite_frames(data.sprite_sheet)
	sprite.centered = false
	sprite.offset = SPRITE_OFFSET
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rect := RectangleShape2D.new()
	rect.size = data.collision_size
	collision_shape.shape = rect
	collision_shape.position = Vector2(0.0, -data.collision_size.y / 2.0)
	facing = facing_from_name(facing_name)
	_play_idle()


func face_toward(point: Vector2) -> void:
	facing = PlayableCharacter.direction_to_facing(point - global_position, facing)
	_play_idle()


func _play_idle() -> void:
	var animation := StringName("idle_" + facing_name())
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation):
		sprite.play(animation)


func facing_name() -> String:
	match facing:
		Vector2i.LEFT:
			return "left"
		Vector2i.RIGHT:
			return "right"
		Vector2i.UP:
			return "up"
		_:
			return "down"


static func facing_from_name(facing_name_value: String) -> Vector2i:
	match facing_name_value:
		"left":
			return Vector2i.LEFT
		"right":
			return Vector2i.RIGHT
		"up":
			return Vector2i.UP
		_:
			return Vector2i.DOWN
