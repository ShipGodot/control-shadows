@tool
@icon("./icons/shadow.svg")
class_name ControlShadow
extends ColorRect

@export var inset : bool = false:
	set(value):
		inset = value
		show_behind_parent = !value
		_update_shader()

@export_range(0.0, 1024.0) var corner_radius : float = 0.0:
	set(value):
		corner_radius = value
		_update_shader()

@export_range(1.0, 80.0) var blur_amount : float = 2.0:
	set(value):
		blur_amount = value
		_update_shader()

@export var shadow_color : Color = Color(0.0, 0.0, 0.0, 1.0):
	set(value):
		shadow_color = value
		_update_shader()

@export var offset_x : float = 0.0:
	set(value):
		offset_x = value
		_recalculate_rect()

@export var offset_y : float = 0.0:
	set(value):
		offset_y = value
		_recalculate_rect()

@export var bounding_box_scale : float = 2.0:
	set(value):
		bounding_box_scale = value
		_recalculate_rect()

var _parent : Control

func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	show_behind_parent = !inset
	mouse_filter = MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = preload("./shaders/shadow.gdshader")
	set_meta("_edit_lock_", true)
	_connect_parent_signals()
	_update_shader()



func _update_shader() -> void:
	material.set_shader_parameter("blur_sigma", blur_amount)
	material.set_shader_parameter("corner_radius", corner_radius)
	material.set_shader_parameter("shadow_color", shadow_color)
	material.set_shader_parameter("inset", inset)


func _recalculate_rect() -> void:
	if not _parent:
		return

	var parent_size := _parent.size
	size = floor(parent_size * bounding_box_scale)
	var new_position := -( size / 2.0 - (parent_size / 2.0) )
	set_deferred("position", new_position)
	if material:
		material.set_shader_parameter("target_size", parent_size)
		material.set_shader_parameter("shadow_box_size", size)
		material.set_shader_parameter("offset", Vector2(offset_x, offset_y))


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not get_parent() is Control:
		warnings.append("This node expects a Control node as its parent.")
	elif get_parent() is Container:
		warnings.append("This node does not work on Container nodes.")

	return warnings


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PARENTED:
			_connect_parent_signals()
		NOTIFICATION_UNPARENTED:
			_disconnect_parent_signals()


func _connect_parent_signals() -> void:
	_parent = get_parent() as Control
	if not _parent:
		update_configuration_warnings()
		return
	if not _parent.item_rect_changed.is_connected(_recalculate_rect):
		_parent.item_rect_changed.connect(_recalculate_rect)
	_recalculate_rect()


func _disconnect_parent_signals() -> void:
	if _parent and is_instance_valid(_parent):
		if _parent.item_rect_changed.is_connected(_recalculate_rect):
			_parent.item_rect_changed.disconnect(_recalculate_rect)
	_parent = null
