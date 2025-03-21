extends Control

const MAX_CHARS = 100

func _ready():
	hide()
	$Panel/VBoxContainer/ChatInput.max_length = MAX_CHARS

func _input(event):
	# Chỉ bắt sự kiện phím khi không hiển thị dialog
	if not visible and event is InputEventKey and event.pressed:
		# Bỏ qua các phím điều khiển di chuyển
		if event.is_action_pressed("ui_up") or \
		   event.is_action_pressed("ui_down") or \
		   event.is_action_pressed("ui_left") or \
		   event.is_action_pressed("ui_right"):
			return
			
		# Kiểm tra nếu là phím chữ hoặc số
		var keycode = event.keycode
		if (keycode >= KEY_A and keycode <= KEY_Z) or \
		   (keycode >= KEY_0 and keycode <= KEY_9):
			# Ngăn sự kiện được xử lý tiếp
			get_viewport().set_input_as_handled()
			show()
			# Thêm ký tự đầu tiên vào input
			$Panel/VBoxContainer/ChatInput.text = char(event.unicode)
			$Panel/VBoxContainer/ChatInput.grab_focus()
			# Di chuyển con trỏ về cuối
			$Panel/VBoxContainer/ChatInput.caret_column = 1

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			$Panel/VBoxContainer/ChatInput.clear()
			$Panel/VBoxContainer/ChatInput.grab_focus()

func _on_chat_input_submitted(text: String):
	if text.strip_edges().is_empty():  # Kiểm tra sau khi loại bỏ khoảng trắng
		hide()
	else:
		send_chat(text)
		$Panel/VBoxContainer/ChatInput.clear()
		hide()

func _on_send_button_pressed():
	var text = $Panel/VBoxContainer/ChatInput.text
	if text.strip_edges().is_empty():  # Kiểm tra sau khi loại bỏ khoảng trắng
		hide()
	else:
		send_chat(text)
		$Panel/VBoxContainer/ChatInput.clear()
		hide()

func send_chat(text: String):
	var chat_data = {
		"type": "chat",
		"data": Network.current_username + "," + text
	}
	Network.send_message(chat_data) 