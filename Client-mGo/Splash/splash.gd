extends Control

@onready var network = Network  # Thay đổi từ $"../Network" thành Network vì đây là autoload node

var max_retries = 3
var retry_attempts = 0

func _ready():
	$Label.text = "Đang kết nối đến máy chủ..."
	
	# Lắng nghe tín hiệu từ Network singleton
	network.server_message_received.connect(_on_server_message_received)
	
	# Thêm kiểm tra trạng thái kết nối
	await get_tree().create_timer(1.0).timeout
	if network.is_connected:
		_on_connection_success()

func connect_to_server():
	if retry_attempts >= max_retries:
		$Label.text = "Không thể kết nối đến máy chủ!"
		return
	
	$Label.text = "Đang kết nối... (Lần thử: %d)" % (retry_attempts + 1)
	network.connect_to_server()
	retry_attempts += 1
	
	# Nếu sau 3 giây vẫn chưa kết nối, thử lại
	await get_tree().create_timer(3.0).timeout
	if not network.is_connected:
		connect_to_server()

func _on_server_message_received(_message):
	_on_connection_success()

func _on_connection_success():
	$Label.text = "Kết nối thành công!"
	await get_tree().create_timer(1.0).timeout
	# Chuyển sang màn hình đăng nhập
	get_tree().change_scene_to_file("res://Login/Login.tscn")
