extends Node2D

@onready var player_manager = $PlayerManager
var current_map = null

func _ready():
	Network.server_message_received.connect(_on_server_message_received)
	
	# Load map đã chọn
	load_selected_map()
	
	# Kết nối các tín hiệu từ UI
	$UI/GameMenu.chat_pressed.connect(_on_chat_pressed)
	$UI/GameMenu.logout_pressed.connect(_on_logout_pressed)
	
	# Thông báo cho server về map đã chọn
	send_map_selection()

func load_selected_map():
	# Xóa map hiện tại nếu có
	if current_map != null:
		current_map.queue_free()
	
	# Load map mới
	var map_path = Network.selected_map_path
	if map_path.is_empty():
		# Nếu không có map được chọn, load map mặc định
		map_path = "res://Map/TileMap/map_1.tscn"
		Network.selected_map_path = map_path
	
	var map_scene = load(map_path)
	current_map = map_scene.instantiate()
	
	# Thêm map vào scene tree
	# Thêm map trước PlayerManager để nhân vật hiển thị phía trên map
	add_child(current_map)
	move_child(current_map, 0) # Di chuyển xuống dưới cùng

func send_map_selection():
	# Gửi thông tin map đã chọn lên server
	var map_data = {
		"type": "select_map",
		"data": Network.selected_map_path
	}
	Network.send_message(map_data)

func _on_chat_pressed():
	$UI/ChatDialog.show()

func _on_logout_pressed():
	if Network.is_connected:
		Network.websocket.close()
	get_tree().change_scene_to_file("res://Login/Login.tscn")

func _on_server_message_received(message):
	var data = JSON.parse_string(message)
	if data and data.has("type"):
		match data["type"]:
			"map_selected":
				# Xác nhận map đã được chọn
				print("map đã được chọn: ", data["data"])
				# Không cần làm gì thêm vì player_manager sẽ xử lý các người chơi
			"player_list":
				# Xử lý danh sách người chơi
				pass
			"player_move":
				# Xử lý di chuyển người chơi
				pass
			"ping":
				# Nhận ping từ server, trả lại pong
				var pong_data = {
					"type": "pong",
					"data": "keepalive"
				}
				Network.send_message(pong_data)
			"pong":
				# Nhận pong từ server, không cần làm gì
				pass
			_:
				# Xử lý các loại tin nhắn khác
				pass 
