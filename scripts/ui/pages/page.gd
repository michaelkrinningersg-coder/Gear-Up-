class_name Page
extends ScrollContainer
## Basis für alle Seiten: scrollbarer Inhalt, Zugriff auf Modell und Effektebene.

var model: GameModel
## Ebene über allem für schwebende Texte, Toasts und Dialoge.
var fx: Control
var content: VBoxContainer


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_deadzone = 12
	content = UI.vbox(18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(content)


func setup(game_model: GameModel, effects_layer: Control) -> void:
	model = game_model
	fx = effects_layer
	_build()
	# Luft unten, damit der Kartenschatten nicht abgeschnitten wird
	var bottom := Control.new()
	bottom.custom_minimum_size.y = 8
	content.add_child(bottom)


## Baut die Seite einmalig auf.
func _build() -> void:
	pass


## Wird jedes Bild aufgerufen, solange die Seite sichtbar ist.
func refresh() -> void:
	pass
