class_name CarryableItem
extends Interactable
## 地上可撿取的投擲物：沿用 Interactable（物理層 3）與 E 互動流程，不另建第二套輸入。
## 被撿起時由 CarrySystem 移除本節點，把貼圖掛到角色的 CarryAnchor；投擲後落地再由世界重新生成。
## 目錄 assets/items/throwables.json 提供名稱、effect_type 與傷害（初版三種全部 plain_damage、傷害 1）。

const CATALOG_PATH := "res://assets/items/throwables.json"
const ITEM_TEXTURE_DIR := "res://assets/items/"
const FRAME_SIZE := 28
## 精靈表 4 幀：地面、舉起、飛行、命中
const FRAME_GROUND := 0
const FRAME_CARRY := 1
const FRAME_FLY := 2
const FRAME_HIT := 3
const INTERACT_SIZE := Vector2(26.0, 26.0)

static var _catalog: Dictionary = {}

var item_id: String = ""
## 原始放置點：命中 Boss 後物品消耗，之後在此重新生成。
var home_position: Vector2 = Vector2.ZERO
var sprite: Sprite2D


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		_catalog = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _catalog


static func item_info(id: String) -> Dictionary:
	return catalog().get(id, {"name": id, "effect_type": "plain_damage", "damage": 1})


static func damage_for(id: String) -> int:
	return int(item_info(id).get("damage", 1))


static func texture_for(id: String) -> Texture2D:
	var path := ITEM_TEXTURE_DIR + id + ".png"
	return load(path) if ResourceLoader.exists(path) else null


## 建立指定幀的 AtlasTexture（供舉起、飛行、命中特效共用）。
static func frame_texture(id: String, frame: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture_for(id)
	atlas.region = Rect2(frame * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
	return atlas


func setup_item(id: String, world_position: Vector2, home: Vector2) -> void:
	item_id = id
	home_position = home
	position = world_position
	setup(StringName(id), "", PackedStringArray(), INTERACT_SIZE, Vector2(0.0, -26.0))
	name = "Item_" + id + "_" + str(get_instance_id())
	sprite = Sprite2D.new()
	sprite.texture = frame_texture(id, FRAME_GROUND)
	sprite.centered = true
	sprite.position = Vector2(0.0, -10.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	# Y-sort 以本節點（物品底部）為準，貼圖往上偏移
	y_sort_enabled = true


func display_name() -> String:
	return String(item_info(item_id).get("name", item_id))
