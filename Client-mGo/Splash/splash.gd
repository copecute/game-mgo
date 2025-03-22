extends Control

@onready var network = Network  # Thay đổi từ $"../Network" thành Network vì đây là autoload node
@onready var status_label = $Label

func _ready():
	status_label.text = "Đang tải danh sách máy chủ..."
	
	# Lắng nghe tín hiệu từ Network singleton
	network.servers_loaded.connect(_on_servers_loaded)
	
	# Tải danh sách server
	network.load_servers_list()

func _on_servers_loaded(servers):
	if servers.size() > 0:
		status_label.text = "Đã tải danh sách máy chủ!"
		await get_tree().create_timer(1.0).timeout
		# Chuyển sang màn hình đăng nhập
		get_tree().change_scene_to_file("res://Login/Login.tscn")
	else:
		status_label.text = "Không thể tải danh sách máy chủ!"
		await get_tree().create_timer(2.0).timeout
		# Thử lại
		network.load_servers_list()
