class_name EffectSprite
extends Sprite2D
## 一次性特效貼圖：顯示指定秒數後淡出並自我移除。可選擇放大（pop）或原地閃爍。

var _life: float = 0.6
var _total: float = 0.6
var _pop: bool = true


static func spawn(parent: Node, texture: Texture2D, world_position: Vector2, seconds: float = 0.6, pop: bool = true, z: int = 9) -> EffectSprite:
	var effect := EffectSprite.new()
	effect.texture = texture
	effect.centered = true
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.position = world_position
	effect.z_index = z
	effect._life = seconds
	effect._total = seconds
	effect._pop = pop
	if pop:
		effect.scale = Vector2(0.5, 0.5)
	parent.add_child(effect)
	return effect


func _process(delta: float) -> void:
	_life -= delta
	var t := 1.0 - clampf(_life / _total, 0.0, 1.0)
	if _pop:
		scale = Vector2.ONE * (0.5 + 0.7 * minf(1.0, t * 3.0))
	modulate.a = 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
	if _life <= 0.0:
		queue_free()
