extends Node2D

var player_scene = preload("res://Player/Player.tscn")
var players = {}  # Dictionary lưu tất cả người chơi {username: player_node}
const INTERPOLATION_SPEED = 4.0  # Tốc độ di chuyển mượt
var pending_players = {}  # Dictionary lưu thông tin người chơi đang chờ xử lý
var received_messages = []  # Lưu các message nhận được trước khi scene ready
var current_instance_id = 1  # Lưu ID của khu vực hiện tại
var default_spawn_position = Vector2(500, 300)  # Vị trí mặc định khi spawn

func _ready():
	print("PlayerManager: Connecting to Network signal")
	Network.server_message_received.connect(_on_server_message_received)
	print("PlayerManager: Current username is ", Network.current_username)
	
	# tạo player cho người chơi hiện tại trước
	spawn_player(Network.current_username)
	
	# xử lý lại tất cả message đã nhận theo thứ tự
	for msg in received_messages:
		print("PlayerManager: Xử lý tin nhắn đã lưu: ", msg)
		_handle_message(msg)
	received_messages.clear()
	
	# không xóa tất cả người chơi khi khởi tạo nữa
	# chỉ xóa khi chuyển khu
	
	# yêu cầu danh sách người chơi từ server
	request_players_list()
	
	# Debug log
	print("PlayerManager: Đã yêu cầu danh sách người chơi")

func request_players_list():
	# gửi yêu cầu lấy danh sách người chơi hiện có trong khu
	var request = {
		"type": "get_players",
		"data": ""
	}
	Network.send_message(request)

func clear_all_players():
	# xóa tất cả người chơi hiện tại (bao gồm cả người chơi hiện tại)
	for username in players.keys():
		if players[username] != null:
			players[username].queue_free()
	
	# khởi tạo lại dictionary rỗng
	players = {}

func _handle_message(msg: String) -> void:
	var data = JSON.parse_string(msg)
	if not data or not data.has("type"):
		print("Invalid message format")
		return
		
	print("Processing message type: ", data["type"])
	
	match data["type"]:
		"player_join", "player_joined": # hỗ trợ cả hai định dạng
			print("PlayerManager: Xử lý tin nhắn player_join/joined")
			# Xử lý người chơi mới tham gia
			var parts = data["data"].split(",")
			if parts.size() >= 3:
				var username = parts[0]
				var x = float(parts[1])
				var y = float(parts[2])
				
				print("PlayerManager: Player joined - ", username, " at ", x, ",", y)
				
				# Nếu là người chơi hiện tại, bỏ qua
				if username == Network.current_username:
					return
					
				# Nếu người chơi này đã tồn tại, xóa trước khi tạo mới
				if username in players:
					remove_player(username)
				
				# Tạo người chơi mới
				spawn_player(username)
				
				# Cập nhật vị trí
				if players[username]:
					players[username].global_position = Vector2(x, y)
					players[username].set_meta("target_position", Vector2(x, y))
			elif typeof(data["data"]) == TYPE_STRING:
				# định dạng cũ chỉ có username
				var username = data["data"]
				print("PlayerManager: Player joined (no position) - ", username)
				if username != Network.current_username:
					if not username in players:
						spawn_player(username)
						
		"player_leave", "player_left": # hỗ trợ cả hai định dạng
			# Xử lý người chơi rời đi
			var username = data["data"]
			if username != Network.current_username:
				remove_player(username)
				
		"player_move", "player_moved", "player_position":
			# Xử lý thông tin di chuyển (hỗ trợ nhiều định dạng)
			var parts = data["data"].split(",")
			if parts.size() >= 3:
				var username = parts[0]
				var x = float(parts[1])
				var y = float(parts[2])
				
				# Bỏ qua nếu là người chơi hiện tại
				if username == Network.current_username:
					return
				
				# Cập nhật vị trí cho người chơi
				if username in players and players[username] != null:
					players[username].set_meta("target_position", Vector2(x, y))
				else:
					# Nếu chưa tồn tại, tạo mới với vị trí nhận được
					spawn_player(username)
					if players[username]:
						players[username].global_position = Vector2(x, y)
						players[username].set_meta("target_position", Vector2(x, y))
		
		"player_chat", "chat":
			# Xử lý chat từ người chơi
			var parts = data["data"].split(",", true, 1)
			if parts.size() >= 2:
				var username = parts[0]
				var message = parts[1]
				
				# Hiển thị bong bóng chat cho người chơi
				if username in players and players[username] != null:
					var chat_bubble = players[username].get_node("ChatBubble")
					if chat_bubble:
						chat_bubble.show_message(message)
		
		"current_instance":
			# Cập nhật ID khu vực hiện tại
			current_instance_id = int(data["data"])
			
		"instance_changed":
			# Đã chuyển khu thành công, xóa các người chơi cũ
			current_instance_id = int(data["data"])
			
			# Chỉ xóa người chơi khác, giữ lại người chơi hiện tại
			for username in players.keys():
				if username != Network.current_username and players[username] != null:
					players[username].queue_free()
					players.erase(username)
			
			# Người chơi hiện tại đã được tạo lúc _ready, không cần tạo lại
			# Đặt vị trí mặc định
			if Network.current_username in players and players[Network.current_username] != null:
				players[Network.current_username].global_position = default_spawn_position
			
			# Yêu cầu danh sách người chơi mới từ server
			request_players_list()
			
		"players_list":
			print("PlayerManager: Nhận được danh sách người chơi")
			# Nhận danh sách người chơi hiện có trong khu
			var players_data = data["data"].split(";")
			print("PlayerManager: Số lượng người chơi nhận được: ", players_data.size())
			
			for player_info in players_data:
				var parts = player_info.split(",")
				if parts.size() >= 3:
					var username = parts[0]
					var x = float(parts[1])
					var y = float(parts[2])
					
					print("PlayerManager: Người chơi từ danh sách: ", username, " tại ", x, ",", y)
					
					# Bỏ qua nếu là người chơi hiện tại
					if username == Network.current_username:
						continue
						
					# Kiểm tra nếu chưa tồn tại mới tạo
					if not username in players:
						spawn_player(username)
					
					# Cập nhật vị trí
					if players[username]:
						players[username].global_position = Vector2(x, y)
						players[username].set_meta("target_position", Vector2(x, y))

func _on_server_message_received(message: String) -> void:
	print("PlayerManager: Nhận được tin nhắn: ", message)
	
	if not is_inside_tree():
		# Nếu node chưa được thêm vào scene tree, lưu tin nhắn để xử lý sau
		print("PlayerManager: Lưu tin nhắn để xử lý sau")
		received_messages.append(message)
		return
	
	_handle_message(message)

func spawn_player(username: String) -> void:
	# Nếu người chơi đã tồn tại, bỏ qua
	if username in players and players[username] != null:
		print("Player already exists: ", username)
		return
		
	print("Spawning player: ", username)  # Debug log
	var player = player_scene.instantiate()
	player.username = username
	
	# kiểm tra name_label tồn tại trước khi gán giá trị
	if player.has_node("name_label"):
		player.get_node("name_label").text = username
	elif player.has_method("set_player_name"):
		# nếu có phương thức setter
		player.set_player_name(username)
	elif player.get("name_label") != null:
		# nếu name_label là property chứ không phải node
		player.name_label.text = username
	
	# đặt vị trí ban đầu trong phạm vi map
	player.global_position = default_spawn_position
	
	players[username] = player
	add_child(player)
	
	# Nếu là người chơi khác, tắt input control và collision
	if username != Network.current_username:
		player.set_process_unhandled_input(false)
		player.collision_layer = 0
		player.collision_mask = 0
	else:
		# Nếu là người chơi hiện tại, gửi vị trí ban đầu lên server
		var move_data = {
			"type": "move",
			"data": str(player.global_position.x) + "," + str(player.global_position.y)
		}
		Network.send_message(move_data)

func remove_player(username: String) -> void:
	if username in players and players[username] != null:
		print("Removing player: ", username)  # Debug log
		players[username].queue_free()
		players.erase(username)

func _process(delta: float) -> void:
	# Xử lý chuyển động mượt cho các người chơi khác
	for username in players:
		if username != Network.current_username:
			var player = players[username]
			if player != null and player.has_meta("target_position"):
				var target = player.get_meta("target_position")
				var old_pos = player.global_position
				player.global_position = player.global_position.lerp(target, delta * INTERPOLATION_SPEED)
				
				# Cập nhật animation và hướng nhìn
				var moving = player.global_position.distance_to(target) > 1
				if moving:
					player.anim.play("Run")
					# Cập nhật hướng nhìn
					var direction = player.global_position - old_pos
					if direction.x != 0:
						player.anim.flip_h = direction.x < 0
				else:
					player.anim.play("Idile")
