extends Control

signal chat_pressed
signal logout_pressed

@onready var chat_dialog = $"../ChatDialog"  # Tham chiếu đến chat dialog

func _ready():
	$MenuBar.hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Cho phép sự kiện chuột đi qua
	$MenuBar.mouse_filter = Control.MOUSE_FILTER_STOP  # Chỉ bắt sự kiện trong MenuBar

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Enter key
		# Chỉ toggle menu khi chat dialog không hiển thị
		if not chat_dialog.visible:
			$MenuBar.visible = !$MenuBar.visible

func _on_menu_button_pressed():
	$MenuBar.visible = !$MenuBar.visible

func _on_chat_button_pressed():
	emit_signal("chat_pressed")
	$MenuBar.hide()

func _on_logout_button_pressed():
	emit_signal("logout_pressed")
	Network.websocket.close()
	get_tree().change_scene_to_file("res://Login/Login.tscn") 

func _on_btn_chat_pressed() -> void:
		emit_signal("chat_pressed")
