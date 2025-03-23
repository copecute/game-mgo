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
	
	# Debug message
	print("Map: Preparing to load map")
	
	# Load map đã chọn
	load_selected_map()
	
	# Kết nối các tín hiệu từ UI
	$UI/GameMenu.chat_pressed.connect(_on_chat_pressed)
	$UI/GameMenu.logout_pressed.connect(_on_logout_pressed)
	$UI/GameMenu.change_instance_pressed.connect(_on_change_instance_pressed)
	
	# Phát hiệu ứng chuyển cảnh khi vào map sau một frame
	call_deferred("_play_initial_transition")
	
	# Thông báo cho server về map đã chọn
	call_deferred("send_map_selection")
	
	# Yêu cầu danh sách người chơi sau khi gửi thông tin map
	call_deferred("request_players_after_delay")

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
	if not data:
		return
		
	match data["type"]:
		"map_selected":
			# Đã chọn map thành công, tiến hành tải map
			load_map(Network.selected_map_path)
			
		"instance_changed":
			# Đã chuyển khu thành công
			print("Đã chuyển đến khu: " + data["data"])
			
			# Cập nhật UI hiển thị khu hiện tại 
			if $UI/InstanceDisplay:
				$UI/InstanceDisplay.current_instance_id = int(data["data"])
				$UI/InstanceDisplay.update_display()

func load_map(map_path):
	# Nếu đang có map, xóa map hiện tại
	if current_map:
		current_map.queue_free()
		current_map = null
	
	# Tải map mới
	var map_scene = load(map_path)
	if map_scene:
		current_map = map_scene.instantiate()
		add_child(current_map)
		move_child(current_map, 0)  # Đặt map ở dưới cùng (z-index)
		
		# Đảm bảo map đã được thêm vào scene tree trước khi yêu cầu danh sách người chơi
		await get_tree().process_frame
		
		# Yêu cầu danh sách người chơi từ server
		player_manager.request_players_list()
		
	else:
		print("Không thể tải map: " + map_path)

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
	# Hiện tại là yêu cầu danh sách người chơi lần nữa để đảm bảo có đầy đủ
	if player_manager:
		player_manager.request_players_list()

func request_players_after_delay():
	# Đợi một chút để đảm bảo server đã xử lý map selection
	await get_tree().create_timer(0.5).timeout
	
	# Yêu cầu danh sách người chơi
	if player_manager:
		print("Map: Requesting player list after delay")
		player_manager.request_players_list()
	
