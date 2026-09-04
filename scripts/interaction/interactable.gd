class_name Interactable
extends Area2D
## 可互動物件：位於物理層 3（Interactable），只負責「被互動時發出 signal」並攜帶對話資料。
## 不處理對話流程、不知道玩家是誰；由 Main 把 `interacted` 接到 DialogueManager。

signal interacted(interactable: Interactable)

## 物理層 3 的位元值。
const INTERACTABLE_LAYER_BIT := 4

var interactable_id: StringName = &""
var speaker_name: String = ""
var lines: PackedStringArray = PackedStringArray()
## 互動提示圖示相對於 Area2D 原點的位置。
var prompt_offset: Vector2 = Vector2(0.0, -28.0)


func _init() -> void:
	collision_layer = INTERACTABLE_LAYER_BIT
	collision_mask = 0
	monitoring = false
	monitorable = true


## size 為偵測矩形（以本節點為中心）。
func setup(id: StringName, speaker: String, dialogue_lines: PackedStringArray, size: Vector2, prompt: Vector2 = Vector2.INF) -> void:
	interactable_id = id
	speaker_name = speaker
	lines = dialogue_lines
	name = "Interactable_" + String(id)
	prompt_offset = prompt if prompt != Vector2.INF else Vector2(0.0, -size.y / 2.0 - 12.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)


func interact() -> void:
	interacted.emit(self)


func prompt_position() -> Vector2:
	return global_position + prompt_offset
