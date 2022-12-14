tool
extends Sprite

export(float) var magnitude = 0
export(float) var amount = 0 setget set_amount, get_amount
export(bool) var truncate = false



func get_step(): return pow(10, magnitude)
func trunc(a, interval): return floor(a / interval) * interval


signal amount_changed()
func set_amount(a):
	if truncate:
		var step = get_step()
		var digitDelta = abs(trunc(a, step) - trunc(amount, step))
		if digitDelta != 0:
			var d = abs(a - amount)
	
			var am = amount
			
			amount = a
			emit_signal("amount_changed")
			
			var t = Tween.new()
			
			
			#var time = floor(d / step) * pow(10, magnitude) / 30.0
			var time = 0.2
			t.interpolate_method(self, "set_amount_direct", trunc(am, step), trunc(a, step), time)
			add_child(t)
			t.start()
			t.connect("tween_all_completed", t, "queue_free")
			
			connect("amount_changed", t, "queue_free")
	else:
		amount = a
		set_rect_amount(fmod(a / pow(10, magnitude), 10))
func get_amount(): return amount
func set_amount_direct(a):
	#amount = a
	set_rect_amount(fmod(a / pow(10, magnitude), 10))

func set_rect_amount(amount):
	region_rect.position = Vector2(0, (10 - amount) * region_rect.size.y)
