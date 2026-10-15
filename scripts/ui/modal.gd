class_name Modal
extends Control
## Einfacher Dialog als Overlay (statt Fenster), damit er zum Flat-Stil passt.
## actions: [{"text": "Abbrechen", "variation": "SecondaryButton"}, {"text": "OK", "callback": cb}]


static func open(host: Control, title: String, body: String, actions: Array, extra: Control = null) -> Modal:
	var modal := Modal.new()
	host.add_child(modal)
	modal._build(title, body, actions, extra)
	return modal


func _build(title: String, body: String, actions: Array, extra: Control) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.04, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := UI.card()
	card.custom_minimum_size.x = 620
	center.add_child(card)
	var v := UI.vbox(20)
	card.add_child(v)
	v.add_child(UI.label(title, "TitleLabel"))
	if body != "":
		v.add_child(UI.label(body, "", true))
	if extra != null:
		v.add_child(extra)
	var row := UI.hbox(12)
	v.add_child(row)
	for action in actions:
		var b := UI.button(action["text"], _choose.bind(action), action.get("variation", ""))
		b.custom_minimum_size.y = 84
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)


func _choose(action: Dictionary) -> void:
	queue_free()
	var callback: Callable = action.get("callback", Callable())
	if callback.is_valid():
		callback.call()
