extends Node

var websocket = null
var is_connected := false
var server_url := "ws://127.0.0.1:8669"  # mặc định
var current_username := ""  # thêm biến lưu username
var servers_list := []  # danh sách server
var selected_server_id := 0  # server được chọn
var is_connecting := false  # Thêm biến để theo dõi trạng thái đang kết nối
var ping_timer := 0.0  # Thêm biến để theo dõi thời gian ping
var ping_interval := 30.0  # Ping mỗi 30 giây để giữ kết nối
var selected_map_path := ""  # Thêm biến để lưu map đã chọn

# Biến toàn cục để lưu trữ tham chiếu đến các dialog
var instance_dialog = null
var chat_dialog = null
var instance_display = null

signal server_message_received(message)
signal servers_loaded(servers)
signal connection_status_changed(status, message)
signal show_instance_dialog(map_id)
signal show_chat_dialog

func _ready():
	# không tự động kết nối nữa, đợi người dùng chọn server
	pass

func load_servers_list():
	# tạo HTTP request để lấy danh sách server
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_server_list_request_completed)
	
	# gửi request
	var error = http_request.request("https://mgo.minhgiang.pro/server.json")
	if error != OK:
		print("lỗi khi gửi request: ", error)
		# Thêm server mặc định nếu không tải được
		servers_list = [
			{
				"id": 1,
				"name": "Server local",
				"address": "ws://127.0.0.1:8669"
			}
		]
		emit_signal("servers_loaded", servers_list)

func _on_server_list_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("lỗi khi tải danh sách server: ", result)
		# Thêm server mặc định nếu không tải được
		servers_list = [
			{
				"id": 1,
				"name": "Server local",
				"address": "ws://127.0.0.1:8669"
			}
		]
		emit_signal("servers_loaded", servers_list)
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("servers") and json.servers.size() > 0:
		servers_list = json.servers
		print("đã tải được ", servers_list.size(), " server")
		emit_signal("servers_loaded", servers_list)
	else:
		print("định dạng json không hợp lệ hoặc không có server")
		# Thêm server mặc định nếu không tải được
		servers_list = [
			{
				"id": 1,
				"name": "Server local",
				"address": "ws://127.0.0.1:8669"
			}
		]
		emit_signal("servers_loaded", servers_list)

func select_server(server_id):
	for server in servers_list:
		if server.id == server_id:
			selected_server_id = server_id
			server_url = server.address
			
			# Đảm bảo URL có định dạng đúng
			if not server_url.begins_with("ws://") and not server_url.begins_with("wss://"):
				server_url = "ws://" + server_url
				
			print("đã chọn server: ", server.name, " - ", server_url)
			return true
	return false

func connect_to_server():
	if selected_server_id == 0 and servers_list.size() > 0:
		# nếu chưa chọn server, chọn server đầu tiên
		select_server(servers_list[0].id)
		
	print("đang thử kết nối đến " + server_url)
	emit_signal("connection_status_changed", "connecting", "Đang kết nối đến máy chủ...")
	
	# Đóng kết nối cũ nếu có
	if is_connected and websocket != null:
		websocket.close()
		is_connected = false
	
	# Tạo websocket mới để tránh lỗi
	websocket = WebSocketPeer.new()
	is_connecting = true
	
	var err = websocket.connect_to_url(server_url)
	if err != OK:
		print("lỗi kết nối: ", err)
		emit_signal("connection_status_changed", "error", "Không thể kết nối")
		websocket = null  # Xóa websocket nếu không kết nối được
		is_connecting = false
		return
	print("bắt đầu kết nối...")

func _process(delta):
	if websocket == null:
		return
		
	# Xử lý ping để giữ kết nối
	if is_connected:
		ping_timer += delta
		if ping_timer >= ping_interval:
			ping_timer = 0.0
			_send_ping()
	
	websocket.poll()
	
	var state = websocket.get_ready_state()
	match state:
		WebSocketPeer.STATE_CONNECTING:
			# đang kết nối, chờ đợi
			pass
		WebSocketPeer.STATE_OPEN:
			if not is_connected:
				print("đã kết nối thành công!")
				is_connected = true
				is_connecting = false
				emit_signal("connection_status_changed", "connected", "Đã kết nối thành công")
				# Reset ping timer khi kết nối thành công
				ping_timer = 0.0
			# nhận message từ server
			while websocket.get_available_packet_count():
				var msg = websocket.get_packet().get_string_from_utf8()
				print("network received: ", msg)  # debug log
				emit_signal("server_message_received", msg)
		WebSocketPeer.STATE_CLOSING:
			# đang đóng kết nối
			pass
		WebSocketPeer.STATE_CLOSED:
			var code = websocket.get_close_code()
			var reason = websocket.get_close_reason()
			print("websocket đóng với code: %d, reason: %s" % [code, reason])
			is_connected = false
			is_connecting = false
			emit_signal("connection_status_changed", "disconnected", "Không thể kết nối")
			websocket = null  # Xóa websocket sau khi đóng kết nối
			# không tự động kết nối lại

func _send_ping():
	if not is_connected or websocket == null:
		return
		
	# Gửi ping để giữ kết nối
	var ping_data = {
		"type": "ping",
		"data": "keepalive"
	}
	
	var json = JSON.stringify(ping_data)
	var err = websocket.send_text(json)
	if err != OK:
		print("lỗi khi gửi ping: ", err)
	else:
		print("đã gửi ping để giữ kết nối")

func send_message(data: Dictionary):
	if not is_connected or websocket == null:
		print("chưa kết nối, không thể gửi tin nhắn")
		return
		
	var json = JSON.stringify(data)
	print("network sending: ", json)  # debug log
	
	# Thêm debug để kiểm tra trạng thái websocket
	print("Trạng thái websocket: ", websocket.get_ready_state())
	
	var err = websocket.send_text(json)
	if err != OK:
		print("lỗi khi gửi tin nhắn: ", err)
	else:
		print("Đã gửi tin nhắn thành công")
		# Reset ping timer khi gửi tin nhắn
		ping_timer = 0.0

func _exit_tree():
	if websocket != null and is_connected:
		websocket.close()
		websocket = null
