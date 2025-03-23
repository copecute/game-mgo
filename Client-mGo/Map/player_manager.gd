extends Node2D

var player_scene = preload("res://Player/Player.tscn")
var players = {}  # Dictionary lưu tất cả người chơi {username: player_node}
const INTERPOLATION_SPEED = 4.0  # Tốc độ di chuyển mượt
var pending_players = {}  # Dictionary lưu thông tin người chơi đang chờ xử lý
var received_messages = []  # Lưu các message nhận được trước khi scene ready

func _ready():
	print("PlayerManager: Connecting to Network signal")
	Network.server_message_received.connect(_on_server_message_received)
	print("PlayerManager: Current username is ", Network.current_username)
	
	# xóa tất cả người chơi hiện tại khi chuyển map
	clear_all_players()
	
	# xử lý lại tất cả message đã nhận theo thứ tự
	for msg in received_messages:
		_handle_message(msg)
	received_messages.clear()
	
	# tạo player cho người chơi hiện tại sau khi xử lý các player khác
	spawn_player(Network.current_username)

func clear_all_players():
	# xóa tất cả người chơi hiện tại (trừ người chơi hiện tại)
	for username in players.keys():
		if username != Network.current_username:
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
		"player_joined":
			var username = data["data"]
			print("Player joined: ", username)
			if username != Network.current_username:
				spawn_player(username)
		
		"player_left":
			var username = data["data"]
			print("Player left: ", username)
			remove_player(username)
			
		"player_moved", "player_position":
			var move_info = data["data"].split(",")
			var username = move_info[0]
			var pos = Vector2(float(move_info[1]), float(move_info[2]))
			print("Player position update: ", username, " -> ", pos)
			
			if username != Network.current_username:
				if username in players:
					players[username].set_meta("target_position", pos)
				elif username not in players:  # nếu player chưa được tạo, tạo mới
					spawn_player(username)
					players[username].global_position = pos
					players[username].set_meta("target_position", pos)
		
		"chat":
			var chat_info = data["data"].split(",", true, 1)  # Split only first comma
			var username = chat_info[0]
			var message = chat_info[1]
			if username in players:
				var player = players[username]
				player.get_node("ChatBubble").show_message(message)

func _on_server_message_received(message: String) -> void:
	print("PlayerManager received message: ", message)
	
	if not is_inside_tree():  # nếu scene chưa ready, lưu message để xử lý sau
		received_messages.append(message)
		return
		
	_handle_message(message)

func spawn_player(username: String) -> void:
	if username in players:
		print("Player already exists: ", username)  # Debug log
		return
		
	print("Spawning player: ", username)  # Debug log
	var player = player_scene.instantiate()
	player.username = username
	players[username] = player
	add_child(player)
	
	# Nếu là người chơi khác, tắt input control và collision
	if username != Network.current_username:
		player.set_process_unhandled_input(false)
		player.collision_layer = 0
		player.collision_mask = 0

func remove_player(username: String) -> void:
	if username in players:
		print("Removing player: ", username)  # Debug log
		players[username].queue_free()
		players.erase(username)

func _process(delta: float) -> void:
	# Xử lý chuyển động mượt cho các người chơi khác
	for username in players:
		if username != Network.current_username:
			var player = players[username]
			if player.has_meta("target_position"):
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
