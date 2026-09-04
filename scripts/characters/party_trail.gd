class_name PartyTrail
extends RefCounted
## 隊伍軌跡：紀錄領頭角色走過的位置點，讓跟隨者沿著同一條路走。純資料，不依賴場景樹。

const DEFAULT_SPACING := 4.0
const DEFAULT_CAPACITY := 96

var points: PackedVector2Array = PackedVector2Array()
var spacing: float
var capacity: int


func _init(point_spacing: float = DEFAULT_SPACING, max_points: int = DEFAULT_CAPACITY) -> void:
	spacing = point_spacing
	capacity = max_points


## 若與最後一點距離達到 spacing 就記錄新點；超過容量時丟掉最舊的點。
func record(position: Vector2) -> void:
	if not points.is_empty() and points[points.size() - 1].distance_to(position) < spacing:
		return
	points.append(position)
	if points.size() > capacity:
		points.remove_at(0)


func clear() -> void:
	points.clear()


func is_empty() -> bool:
	return points.is_empty()


## 從 head（目前位置）沿軌跡往回走 distance 的世界座標。軌跡不夠長時回傳最舊的點。
func point_behind(head: Vector2, distance: float) -> Vector2:
	return point_behind_static(points, head, distance)


static func point_behind_static(trail: PackedVector2Array, head: Vector2, distance: float) -> Vector2:
	if trail.is_empty():
		return head
	var remaining := distance
	var current := head
	for i: int in range(trail.size() - 1, -1, -1):
		var previous := trail[i]
		var segment := current.distance_to(previous)
		if segment >= remaining:
			if segment <= 0.0001:
				return previous
			return current.lerp(previous, remaining / segment)
		remaining -= segment
		current = previous
	return trail[0]
