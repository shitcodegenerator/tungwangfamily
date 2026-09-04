class_name BattleHud
extends CanvasLayer
## 戰鬥期間的最小 HUD：左上角玩家愛心、上方中央 Boss 生命（炸雞翅圖示）。只在戰鬥進行中顯示。

const HEART_FULL := preload("res://assets/ui/heart_full.png")
const HEART_EMPTY := preload("res://assets/ui/heart_empty.png")
const WING := preload("res://assets/effects/fx_chicken_wing.png")

@onready var hearts: HBoxContainer = $Hearts
@onready var boss_row: HBoxContainer = $BossPanel/Row
@onready var boss_label: Label = $BossPanel/Row/Name

var _wing_icons: Array[TextureRect] = []


func _ready() -> void:
	visible = false


func bind(director: BattleDirector) -> void:
	director.boss_hp_changed.connect(_on_boss_hp)
	director.player_hp_changed.connect(_on_player_hp)
	director.battle_won.connect(func() -> void: visible = false)
	director.battle_lost.connect(func() -> void: visible = false)


func show_battle(boss_name: String) -> void:
	boss_label.text = boss_name
	visible = true


func hide_battle() -> void:
	visible = false


func _on_player_hp(hp: int, max_hp: int) -> void:
	for child: Node in hearts.get_children():
		child.queue_free()
	for index: int in range(max_hp):
		var heart := TextureRect.new()
		heart.texture = HEART_FULL if index < hp else HEART_EMPTY
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heart.stretch_mode = TextureRect.STRETCH_KEEP
		hearts.add_child(heart)


func _on_boss_hp(hp: int, max_hp: int) -> void:
	for icon: TextureRect in _wing_icons:
		icon.queue_free()
	_wing_icons.clear()
	for index: int in range(max_hp):
		var icon := TextureRect.new()
		icon.texture = WING
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		icon.modulate = Color.WHITE if index < hp else Color(0.3, 0.3, 0.3, 0.6)
		boss_row.add_child(icon)
		_wing_icons.append(icon)


## 純函式：HUD 文字摘要（測試用）。
static func summary(player_hp: int, boss_hp: int) -> String:
	return "♥×%d　炸物魔王 %d" % [player_hp, boss_hp]
