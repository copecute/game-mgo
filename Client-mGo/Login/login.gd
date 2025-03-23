extends Control

@onready var username_input = $UI/CenterContainer/VBoxContainer/FormContainer/UsernameContainer/UsernameField
@onready var password_input = $UI/CenterContainer/VBoxContainer/FormContainer/PasswordContainer/PasswordField
@onready var status_label = $UI/CenterContainer/VBoxContainer/StatusLabel
@onready var btn_login = $UI/CenterContainer/VBoxContainer/ButtonsContainer/btnLogin
@onready var btn_register = $UI/CenterContainer/VBoxContainer/ButtonsContainer/btnRegister
@onready var server_option = $UI/CenterContainer/VBoxContainer/FormContainer/ServerContainer/ServerOptionButton
@onready var connection_status = $UI/CenterContainer/VBoxContainer/FormContainer/ConnectionStatus
@onready var login_dialog = $UI/LoginDialog

var is_connecting = false
var is_logging_in = false

func _ready():
	Network.server_message_received.connect(_on_server_message_received)
	Network.connection_status_changed.connect(_on_connection_status_changed)
	
	# Điền danh sách server vào option button
	_populate_server_list()
	
	# Ẩn dialog đăng nhập
	login_dialog.hide()

func _populate_server_list():
	server_option.clear()
	
	if Network.servers_list.size() == 0:
		# Nếu chưa tải được danh sách server, tải lại
		Network.servers_loaded.connect(_on_servers_loaded)
		Network.load_servers_list()
		return
		
	for server in Network.servers_list:
		server_option.add_item(server.name, server.id)
	
	# Chọn server đầu tiên
	if server_option.item_count > 0:
		server_option.select(0)
		# Không tự động kết nối nữa
		var server_id = server_option.get_item_id(0)
		Network.select_server(server_id)

func _on_servers_loaded(servers):
	_populate_server_list()

func _on_server_option_button_item_selected(index):
	var server_id = server_option.get_item_id(index)
	Network.select_server(server_id)
	
	# Nếu đã kết nối đến server khác, ngắt kết nối
	if Network.is_connected:
		Network.websocket.close()
		connection_status.text = "Đã chọn máy chủ: " + server_option.get_item_text(index)
		connection_status.modulate = Color(1, 1, 1)  # Màu trắng

func _on_connection_status_changed(status, message):
	if is_logging_in:
		login_dialog.get_node("VBoxContainer/StatusLabel").text = message
		
		match status:
			"connected":
				# Đã kết nối, gửi thông tin đăng nhập
				_send_login_data()
			"error", "disconnected":
				# Hiển thị lỗi và ẩn dialog
				status_label.text = "Lỗi kết nối: " + message
				status_label.modulate = Color(1, 0, 0)  # Màu đỏ
				login_dialog.hide()
				is_logging_in = false
				btn_login.disabled = false
				btn_register.disabled = false
	else:
		connection_status.text = message
		
		match status:
			"connected":
				connection_status.modulate = Color(0, 1, 0)  # Màu xanh lá
			"connecting":
				connection_status.modulate = Color(1, 1, 0)  # Màu vàng
			"disconnected", "error":
				connection_status.modulate = Color(1, 0, 0)  # Màu đỏ

func _on_LoginButton_pressed():
	if username_input.text.is_empty() or password_input.text.is_empty():
		status_label.text = "Vui lòng điền đầy đủ thông tin"
		status_label.modulate = Color(1, 0, 0)  # Màu đỏ
		return
	
	# Hiển thị dialog đăng nhập
	login_dialog.get_node("VBoxContainer/StatusLabel").text = "Đang kết nối đến máy chủ..."
	login_dialog.popup_centered()
	
	# Vô hiệu hóa các nút trong khi đăng nhập
	btn_login.disabled = true
	btn_register.disabled = true
	
	is_logging_in = true
	
	# Kết nối đến server
	Network.connect_to_server()

func _send_login_data():
	# Server mong đợi data là một chuỗi, không phải đối tượng JSON
	var login_data = {
		"type": "login",
		"data": username_input.text + "," + password_input.text
	}
	
	Network.send_message(login_data)
	login_dialog.get_node("VBoxContainer/StatusLabel").text = "Đang đăng nhập..."
	
	# In ra thông tin để debug
	print("Đang gửi thông tin đăng nhập: ", JSON.stringify(login_data))

func _on_server_message_received(message):
	print("Nhận phản hồi từ server: ", message)
	
	var data = JSON.parse_string(message)
	if data and data.has("type"):
		match data["type"]:
			"login_success":
				print("Login success, setting username: ", username_input.text)
				Network.current_username = username_input.text
				login_dialog.hide()
				get_tree().change_scene_to_file("res://Map/map_selection.tscn")
			"login_failed":
				status_label.text = data["data"]
				status_label.modulate = Color(1, 0, 0)  # Màu đỏ
				login_dialog.hide()
				is_logging_in = false
				btn_login.disabled = false
				btn_register.disabled = false
			_:
				print("Nhận tin nhắn không xử lý: ", data["type"])

func _on_btn_register_pressed() -> void:
	get_tree().change_scene_to_file("res://Login/Register.tscn")

func _on_cancel_button_pressed():
	# Hủy đăng nhập
	if Network.is_connected:
		Network.websocket.close()
	
	login_dialog.hide()
	is_logging_in = false
	btn_login.disabled = false
	btn_register.disabled = false
