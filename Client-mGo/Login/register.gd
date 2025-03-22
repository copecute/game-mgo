extends Control

@onready var username_input = $CenterContainer/VBoxContainer/FormContainer/UsernameContainer/UsernameField
@onready var password_input = $CenterContainer/VBoxContainer/FormContainer/PasswordContainer/PasswordField
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var btn_register = $CenterContainer/VBoxContainer/ButtonsContainer/btnRegister
@onready var btn_back = $CenterContainer/VBoxContainer/ButtonsContainer/btnBack
@onready var connection_status = $CenterContainer/VBoxContainer/FormContainer/ConnectionStatus
@onready var register_dialog = $RegisterDialog

var is_registering = false

func _ready():
	Network.server_message_received.connect(_on_server_message_received)
	Network.connection_status_changed.connect(_on_connection_status_changed)
	
	# Hiển thị trạng thái kết nối hiện tại
	if Network.is_connected:
		connection_status.text = "Đã kết nối đến máy chủ"
		connection_status.modulate = Color(0, 1, 0)
	else:
		connection_status.text = "Chưa kết nối đến máy chủ"
		connection_status.modulate = Color(1, 0, 0)
	
	# Ẩn dialog đăng ký
	register_dialog.hide()

func _on_connection_status_changed(status, message):
	if is_registering:
		register_dialog.get_node("VBoxContainer/StatusLabel").text = message
		
		match status:
			"connected":
				# Đã kết nối, gửi thông tin đăng ký
				_send_register_data()
			"error", "disconnected":
				# Hiển thị lỗi và ẩn dialog
				status_label.text = "Lỗi kết nối: " + message
				status_label.modulate = Color(1, 0, 0)  # Màu đỏ
				register_dialog.hide()
				is_registering = false
				btn_register.disabled = false
				btn_back.disabled = false
	else:
		connection_status.text = message
		
		match status:
			"connected":
				connection_status.modulate = Color(0, 1, 0)  # Màu xanh lá
			"connecting":
				connection_status.modulate = Color(1, 1, 0)  # Màu vàng
			"disconnected", "error":
				connection_status.modulate = Color(1, 0, 0)  # Màu đỏ

func _on_RegisterButton_pressed():
	if username_input.text.is_empty() or password_input.text.is_empty():
		status_label.text = "Vui lòng điền đầy đủ thông tin"
		status_label.modulate = Color(1, 0, 0)  # Màu đỏ
		return
	
	# Hiển thị dialog đăng ký
	register_dialog.get_node("VBoxContainer/StatusLabel").text = "Đang kết nối đến máy chủ..."
	register_dialog.popup_centered()
	
	# Vô hiệu hóa các nút trong khi đăng ký
	btn_register.disabled = true
	btn_back.disabled = true
	
	is_registering = true
	
	# Kết nối đến server
	Network.connect_to_server()

func _send_register_data():
	var register_data = {
		"type": "register",
		"data": username_input.text + "," + password_input.text
	}
	Network.send_message(register_data)
	register_dialog.get_node("VBoxContainer/StatusLabel").text = "Đang đăng ký..."
	
	# In ra thông tin để debug
	print("Đang gửi thông tin đăng ký: ", JSON.stringify(register_data))

func _on_server_message_received(message):
	var data = JSON.parse_string(message)
	if data and data.has("type"):
		match data["type"]:
			"register_success":
				status_label.text = data["data"]
				status_label.modulate = Color(0, 1, 0)  # Màu xanh lá
				register_dialog.hide()
				is_registering = false
				btn_register.disabled = false
				btn_back.disabled = false
				await get_tree().create_timer(1.0).timeout
				get_tree().change_scene_to_file("res://Login/Login.tscn")
			"register_failed":
				status_label.text = data["data"]
				status_label.modulate = Color(1, 0, 0)  # Màu đỏ
				register_dialog.hide()
				is_registering = false
				btn_register.disabled = false
				btn_back.disabled = false

func _on_btn_back_pressed():
	get_tree().change_scene_to_file("res://Login/Login.tscn")

func _on_cancel_button_pressed():
	# Hủy đăng ký
	if Network.is_connected:
		Network.websocket.close()
	
	register_dialog.hide()
	is_registering = false
	btn_register.disabled = false
	btn_back.disabled = false
