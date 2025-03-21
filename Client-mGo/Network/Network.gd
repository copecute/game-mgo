extends Node

var websocket := WebSocketPeer.new()
var is_connected := false
var server_url := "ws://127.0.0.1:8669"
var current_username := ""  # thêm biến lưu username

signal server_message_received(message)

func _ready():
	connect_to_server()

func connect_to_server():
	print("Đang thử kết nối đến " + server_url)
	
	var err = websocket.connect_to_url(server_url)
	if err != OK:
		print("Lỗi kết nối: ", err)
		return
	print("Bắt đầu kết nối...")

func _process(_delta):
	if websocket == null:
		return
		
	websocket.poll()
	
	var state = websocket.get_ready_state()
	match state:
		WebSocketPeer.STATE_CONNECTING:
			# đang kết nối, chờ đợi
			pass
		WebSocketPeer.STATE_OPEN:
			if not is_connected:
				print("Đã kết nối thành công!")
				is_connected = true
			# nhận message từ server
			while websocket.get_available_packet_count():
				var msg = websocket.get_packet().get_string_from_utf8()
				print("Network received: ", msg)  # Debug log
				emit_signal("server_message_received", msg)
		WebSocketPeer.STATE_CLOSING:
			# đang đóng kết nối
			pass
		WebSocketPeer.STATE_CLOSED:
			var code = websocket.get_close_code()
			var reason = websocket.get_close_reason()
			print("WebSocket đóng với code: %d, reason: %s" % [code, reason])
			is_connected = false
			# thử kết nối lại sau 3 giây
			await get_tree().create_timer(3.0).timeout
			connect_to_server()

func send_message(data: Dictionary):
	if not is_connected:
		print("Chưa kết nối, không thể gửi tin nhắn")
		return
		
	var json = JSON.stringify(data)
	print("Network sending: ", json)  # Debug log
	var err = websocket.send_text(json)
	if err != OK:
		print("Lỗi khi gửi tin nhắn: ", err)

func _exit_tree():
	if websocket != null and is_connected:
		websocket.close()
