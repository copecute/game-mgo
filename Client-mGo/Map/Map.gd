extends Node2D

@onready var player_manager = $PlayerManager
var current_map = null

func _ready():
	Network.server_message_received.connect(_on_server_message_received)
	
	# Lưu trữ tham chiếu đến các dialog
	Network.instance_dialog = $UI/InstanceDialog
	Network.chat_dialog = $UI/ChatDialog
	Network.instance_display = $UI/InstanceDisplay
	
	# Kết nối tín hiệu từ hiệu ứng chuyển cảnh
	$UI/TransitionEffect.transition_halfway.connect(_on_transition_halfway)
	$UI/TransitionEffect.transition_finished.connect(_on_transition_finished)
	
	# Phát hiệu ứng chuyển cảnh khi vào map sau một frame
	call_deferred("_play_initial_transition")
	
	# Load map đã chọn
	load_selected_map()
	
	# Kết nối các tín hiệu từ UI
	$UI/GameMenu.chat_pressed.connect(_on_chat_pressed)
	$UI/GameMenu.logout_pressed.connect(_on_logout_pressed)
	$UI/GameMenu.change_instance_pressed.connect(_on_change_instance_pressed)
	
	# Thông báo cho server về map đã chọn
	send_map_selection()

func _play_initial_transition():
	# Phát hiệu ứng chuyển cảnh khi vào map
	$UI/TransitionEffect.play_transition("Đang tải map...")

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
	print("Hiển thị chat dialog")
	$UI/ChatDialog.show()

func _on_logout_pressed():
	if Network.is_connected:
		Network.websocket.close()
	get_tree().change_scene_to_file("res://Login/Login.tscn")

func _on_change_instance_pressed():
	print("Hiển thị instance dialog")
	print("Map path: ", Network.selected_map_path)
	# Hiển thị dialog chọn khu với map hiện tại
	if Network.selected_map_path.is_empty():
		print("Map path trống, sử dụng mặc định")
		Network.selected_map_path = "res://Map/TileMap/map_1.tscn"
	$UI/InstanceDialog.show_for_map(Network.selected_map_path)

func _on_server_message_received(message):
	var data = JSON.parse_string(message)
	if data and data.has("type"):
		match data["type"]:
			"map_selected":
				# Xác nhận map đã được chọn
				print("map đã được chọn: ", data["data"])
				# Không cần làm gì thêm vì player_manager sẽ xử lý các người chơi
			"current_instance":
				# Thông tin về khu hiện tại
				var instance_id = int(data["data"])
				print("Đang ở khu: ", instance_id)
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

# Hàm xử lý tín hiệu show_instance_dialog
func _on_show_instance_dialog(map_id):
	print("Hiển thị instance dialog từ tín hiệu")
	print("Map path: ", map_id)
	if map_id.is_empty():
		print("Map path trống, sử dụng mặc định")
		map_id = "res://Map/TileMap/map_1.tscn"
	$UI/InstanceDialog.show_for_map(map_id)

# Hàm xử lý tín hiệu show_chat_dialog
func _on_show_chat_dialog():
	print("Hiển thị chat dialog từ tín hiệu")
	$UI/ChatDialog.show() 

func _on_transition_halfway():
	# Được gọi khi hiệu ứng chuyển cảnh đến giữa
	# Có thể thực hiện các tác vụ tải ở đây
	pass

func _on_transition_finished():
	# Được gọi khi hiệu ứng chuyển cảnh kết thúc
	# Có thể thực hiện các tác vụ sau khi tải xong ở đây
	pass 
