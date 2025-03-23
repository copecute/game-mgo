extends Control

@onready var network = Network  # Thay đổi từ $"../Network" thành Network vì đây là autoload node
@onready var progress_bar = $CenterContainer/VBoxContainer/ProgressBar

var loading_progress = 0.0
var loading_speed = 0.5  # tốc độ tăng progress

func _ready():
	# lắng nghe tín hiệu từ Network singleton
	network.servers_loaded.connect(_on_servers_loaded)
	
	# tải danh sách server
	network.load_servers_list()
	
	# khởi tạo progress bar
	progress_bar.value = 0.0

func _process(delta):
	# cập nhật progress bar mỗi frame
	loading_progress += delta * loading_speed
	progress_bar.value = min(loading_progress, 0.95)  # giữ ở mức 95% cho đến khi tải xong

func _on_servers_loaded(servers):
	if servers.size() > 0:
		# tải thành công, progress bar lên 100%
		progress_bar.value = 1.0
		await get_tree().create_timer(0.5).timeout
		# chuyển sang màn hình đăng nhập
		get_tree().change_scene_to_file("res://Login/Login.tscn")
	else:
		# không thể tải, thiết lập lại progress
		loading_progress = 0.0
		progress_bar.value = 0.0
		await get_tree().create_timer(0.5).timeout
		# thử lại
		network.load_servers_list()
