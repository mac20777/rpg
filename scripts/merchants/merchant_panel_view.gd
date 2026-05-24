class_name MerchantPanelView
extends RefCounted

signal purchase_requested(offer_index: int)

var panel: PanelContainer
var title_label: Label
var hint_label: Label
var buttons_box: VBoxContainer


func create(root: Control) -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-390.0, 118.0)
	panel.custom_minimum_size = Vector2(370.0, 250.0)
	panel.visible = false
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	title_label = Label.new()
	title_label.text = "流浪商人"
	title_label.add_theme_font_size_override("font_size", 20)
	box.add_child(title_label)

	hint_label = Label.new()
	hint_label.text = "1/2/3 购买，Esc 关闭"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 13)
	box.add_child(hint_label)

	buttons_box = VBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 6)
	box.add_child(buttons_box)


func is_visible() -> bool:
	return panel != null and panel.visible


func hide() -> void:
	if panel != null:
		panel.visible = false


func set_hint(message: String) -> void:
	if is_visible() and hint_label != null:
		hint_label.text = message


func show_offers(title: String, hint: String, offers: Array, validations: Array) -> void:
	if panel == null:
		return
	title_label.text = title
	hint_label.text = hint
	for child in buttons_box.get_children():
		child.queue_free()
	for offer_index in range(offers.size()):
		var offer: Dictionary = offers[offer_index]
		var validation: Dictionary = validations[offer_index] if offer_index < validations.size() else {}
		buttons_box.add_child(_make_offer_button(offer_index, offer, validation))
	panel.visible = true


func _make_offer_button(offer_index: int, offer: Dictionary, validation: Dictionary) -> Button:
	var reason := String(validation.get("reason", ""))
	var button := Button.new()
	button.text = "%d. %s  %d金\n%s%s" % [
		offer_index + 1,
		String(offer.get("title", "商品")),
		int(offer.get("price", 0)),
		String(offer.get("desc", "")),
		"" if reason.is_empty() else "\n%s" % reason
	]
	button.custom_minimum_size = Vector2(330.0, 58.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = not bool(validation.get("can_buy", false))
	button.pressed.connect(_on_offer_button_pressed.bind(offer_index))
	return button


func _on_offer_button_pressed(offer_index: int) -> void:
	purchase_requested.emit(offer_index)
