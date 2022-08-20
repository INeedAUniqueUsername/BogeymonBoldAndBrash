extends Node2D
var creatures = []
const Place = preload("res://Common.gd").Place

onready var boxes = [$UI/LeftA, $UI/LeftB, $UI/RightA, $UI/RightB]
func _ready():
	for holder in get_tree().get_nodes_in_group("Place"):
		if holder.get_child_count() == 0:
			continue
		var c = holder.get_child(0)
		creatures.append(c)
		var side = { $Left:0, $Right:1 }[holder.get_parent()]
		var index = ["A", "B", "C", "D", "E", "F"].find(holder.name)
		c.place = Place.new(side, index, holder)
		
	
	$UI/CreatureMenu/TopBar.connect("button_down", self, "drag_menu")
	$UI/CreatureMenu/Attack.connect("pressed", self, "show_move_list")
	$UI/CreatureMenu/Pass.connect("pressed", self, "creature_pass")
	var moveButtons = $UI/CreatureMenu/MoveList.get_children()
	var moveDesc = $UI/CreatureMenu/MoveList/Description
	for i in range(4):
		var b = moveButtons[i]
		b.connect("pressed", self, "choose_move", [i])
		b.connect("mouse_entered", self, "show_move_desc", [i])
		b.connect("mouse_exited", moveDesc, "hide")
	
	var strike = $UI/CreatureMenu/MoveList/PartyStrike
	strike.connect("pressed", self, "toggle_strike")
	strike.connect("mouse_entered", self, "show_strike_desc")
	strike.connect("mouse_exited", moveDesc, "hide")
	update_strike_label()
	
	for c in creatures:
		c.summon()
		
		var box = StatBox.instance()
		box.texture = [load("res://InfoBoxCyan.png"), load("res://InfoBoxRed.png")][Game.innovate(c.place.side)]
		[$UI/Left, $UI/Right][c.place.side].add_child(box)
		box.rect_scale = Vector2(0.75, 0.75)
		
		box.nameLabel.text = c.species
		box.hpRoller.set_amount(c.hp, 50.0)
		
		
		c.connect("hp_changed", self, "creature_hp_changed", [c, box])
		c.connect("damaged", self, "creature_damaged", [c, box])
		box.hpRoller.connect("roller_stopped", self, "on_roller_stopped", [c, box])
		
		
	while true:
		for c in creatures:
			c.allowStrike = true
		for c in creatures:
			if !c:
				continue
			if c.fainted:
				continue
			if c.cpu:
				continue
			if !c.allowStrike:
				continue
			creature = c
			
			update_menu()
			
			var arrow = load("res://SubjectArrow.tscn").instance()
			arrow.global_position = creature.global_position
			add_child(arrow)
			yield(self, "creature_done")
			arrow.queue_free()
			
func drag_menu():
	var bar = $UI/CreatureMenu/TopBar
	var menu = $UI/CreatureMenu
	var lastPos = get_global_mouse_position()
	while bar.pressed:
		var pos = get_global_mouse_position()
		menu.set_global_position(menu.get_global_position() + pos - lastPos)
		lastPos = pos
		yield(get_tree(), "idle_frame")
			
func toggle_strike():
	strikeMode = !strikeMode
	update_strike_label()
	show_strike_desc()
	update_move_list()
func update_strike_label():
	$UI/CreatureMenu/MoveList/PartyStrike/Label.text = {
		true: "*Party Move*",
		false: "*Solo Move*"
	}[strikeMode]
const StatBox = preload("res://InfoBox.tscn")
func creature_hp_changed(c, box):
	box.hpRoller.set_amount(c.hp, c.hurt_rate)
func on_roller_stopped(c, box):
	c.hurt_rate = 10
	if !box.hpRoller.amount == 0:
		return
	c.faint()
	box.statusLabel.text = "Knocked out!"
	if c == creature:
		emit_signal("creature_done")
func creature_damaged(proj, c, box):
	box.shake()
	if !proj.is_in_group("Impact"):
		return
	for i in [16, -16, 16, -16, 8, -8, 8, -8, 4, -4, 4, -4, 2, -2, 2, -2, 1, -1, 1, -1, 0]:
		$Camera2D.position = Vector2(0, i * 2)
		yield(get_tree().create_timer(0.04), "timeout")
signal creature_done()
func creature_pass():
	creature.allowStrike = true
	emit_signal("creature_done")
func show_move_list():
	var m = $UI/CreatureMenu/MoveList
	if m.visible:
		m.hide()
	else:
		m.show()
var creature = null
func update_menu():
	var cm = $UI/CreatureMenu
	cm.show()
	cm.set_global_position(creature.global_position)
	$UI/CreatureMenu/MoveList.hide()
	update_move_list()
	
var strikeMode = false
func update_move_list():
	var b = $UI/CreatureMenu/MoveList.get_children()
	for i in range(4):
		var button = b[i]
		var m = creature.moves[i]
		if m != creature.Moves.None:
			button.get_node("Label").text = creature.NameTable[m]
			button.disabled = !(creature.pp[m] > 0) or (strikeMode and (!creature.StrikeMoves.has(m) or get_allies_for_strike(m).empty()))
			continue
		
		button.get_node("Label").text = ""
		button.disabled = true
		
func request_target(targets, allowCancel = true):
	var arrow = load("res://TargetArrow.tscn").instance()
	arrow.creatures = targets
	arrow.allowCancel = allowCancel
	arrow.global_position = creature.global_position
	add_child(arrow)
	
	
	for c in targets:
		var ch = load("res://TempCrosshair.tscn").instance()
		ch.global_position = c.global_position
		add_child(ch)
		ch.selectColor = Color(1, 0, 0)
		arrow.connect("tree_exiting", ch, "show_selected_single", [arrow, c])
		arrow.connect("tree_exiting", ch, "dismiss")
	$UI/SelectTarget.show()
	
	$UI/SelectTarget/Cancel.connect("pressed", arrow, "queue_free")
	$UI/SelectTarget.connect("pressed", arrow, "select")
	$UI/SelectTarget/Prev.connect("pressed", arrow, "prev")
	$UI/SelectTarget/Next.connect("pressed", arrow, "next")
	
	yield(arrow, "tree_exiting")
	$UI/SelectTarget.hide()
	return arrow.target
	
func request_target_multi(targets, green = false):
	var arrow = load("res://MultiTargetArrow.tscn").instance()
	arrow.creatures = targets
	arrow.allowCancel = true
	arrow.global_position = creature.global_position
	add_child(arrow)
	
	
	if green:
		arrow.sprite.texture = load("res://TargetArrowGreen.png")
	
	for c in targets:
		var ch = load("res://TempCrosshair.tscn").instance()
		ch.global_position = c.global_position
		add_child(ch)
		ch.selectColor = Color(0, 1, 0)
		arrow.connect("selection_changed", ch, "show_selected_multi", [arrow, c])
		arrow.connect("tree_exiting", ch, "dismiss")
	$UI/SelectTargetMulti.show()
	
	$UI/SelectTargetMulti/Cancel.connect("pressed", arrow, "queue_free")
	$UI/SelectTargetMulti.connect("pressed", arrow, "select")
	$UI/SelectTargetMulti/Prev.connect("pressed", arrow, "prev")
	$UI/SelectTargetMulti/Next.connect("pressed", arrow, "next")
	
	yield(arrow, "tree_exiting")
	$UI/SelectTargetMulti.hide()
	return arrow.targets
	
func get_opposing_creatures():
	var result = []
	for c in creatures:
		
		if c.place.side == creature.place.side:
			continue
		result.append(c)
	return result
func get_allied_creatures():
	var result = []
	for c in creatures:
		if c == creature or c.place.side != creature.place.side:
			continue
		result.append(c)
	return result
func get_allies_for_strike(move):
	var r = []
	for a in get_allied_creatures():
		if !a.allowStrike:
			continue
		if !(a.moves.has(move) and a.pp[move] > 0):
			continue
		r.append(a)
	return r
	
func show_move_desc(i):
	var Moves = creature.Moves
	var m = creature.moves[i]
	if m == 0:
		return
	var desc = $UI/CreatureMenu/MoveList/Description
	desc.get_node("Label").text = creature.DescTable[m]
	desc.show()
	
func show_strike_desc():
	var d = $UI/CreatureMenu/MoveList/Description
	d.get_node("Label").text = {
		false: "This Bogeymon uses the chosen move by itself.",
		true: "This Bogeymon calls available allies to use the chosen move in unison."
	}[strikeMode]
	d.show()
func choose_move(i):
	$UI/CreatureMenu.hide()
	if yield(handle_move(i), "completed"):
		emit_signal("creature_done")
		return
	$UI/CreatureMenu.show()
func handle_move(i):
	var Moves = creature.Moves
	var m = creature.moves[i]
	
	if strikeMode:
		var allies = get_allies_for_strike(m)
		if allies.empty():
			return
		var attackers = yield(request_target_multi(allies, true), "completed")
		if attackers.empty():
			return
		
		# DO NOT PASS IN CREATURES ARRAY
		#debounce keys
		#yield(get_tree().create_timer(1.0), "timeout")
		
		var msg = "The party used %s!" % [creature.NameTable[m].to_upper()]
		
		match m:
			Moves.SnapFreeze:
				var target = yield(request_target(get_opposing_creatures(), true), "completed")
				if !target:
					return
					
				yield(showMessage(msg), "completed")
				yield(creature.use_snap_freeze(target, attackers), "completed")
				
			Moves.BrickThrow:
				var target = yield(request_target(get_opposing_creatures(), true), "completed")
				if !target:
					return
					
				yield(showMessage(msg), "completed")
				yield(creature.use_brick_throw(target, attackers), "completed")
				
			_:
				assert(false)
		hideMessage()
		
		creature.allowStrike = false
		for a in attackers:
			a.allowStrike = false
		strikeMode = false
		return true
	
	var msg = "%s used %s!" % [creature.species, creature.NameTable[m].to_upper()]
	
	match m:
		Moves.SnapFreeze:
			var target = yield(request_target(get_opposing_creatures(), true), "completed")
			if !target:
				return
				
			yield(showMessage(msg), "completed")
			yield(creature.use_snap_freeze(target), "completed")
		Moves.BrickThrow:
			var target = yield(request_target(get_opposing_creatures(), true), "completed")
			if !target:
				return
				
			yield(showMessage(msg), "completed")
			yield(creature.use_brick_throw(target), "completed")
		Moves.Sunblast:
			yield(showMessage(msg), "completed")
			yield(creature.sunblast(), "completed")
		Moves.DungBowl:
			yield(showMessage(msg), "completed")
			yield(creature.dung_bowl(), "completed")
			
		Moves.SpearThrust:
			var target = yield(request_target(get_opposing_creatures(), true), "completed")
			if !target:
				return
				
			yield(showMessage(msg), "completed")
			yield(creature.use_spear_thrust(target), "completed")
		Moves.CrowSlash:
			var target = yield(request_target(get_opposing_creatures(), true), "completed")
			if !target:
				return
				
			yield(showMessage(msg), "completed")
			yield(creature.use_crow_slash(target), "completed")
		_:
			assert(false)
	hideMessage()
	
	return true
	
var dialogVisible = false
func showMessage(text):
	var dt = $UI/Dialog/Text
	if !dialogVisible:
		dt.text = text
		$UI/Dialog/Anim.play("Show")
		yield($UI/Dialog/Anim, "animation_finished")
	
	dialogVisible = true
	
	var t = Tween.new()
	t.interpolate_property(dt, "visible_characters", 0, len(text), len(text) / 24.0)
	add_child(t)
	t.connect("tween_all_completed", t, "queue_free")
	t.start()
	yield(t, "tween_all_completed")
func hideMessage():
	$UI/Dialog/Anim.play("Hide")
	yield($UI/Dialog/Anim, "animation_finished")
	dialogVisible = false
