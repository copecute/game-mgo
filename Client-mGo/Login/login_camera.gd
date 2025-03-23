extends Camera2D

# thời gian cho một chuyển động đầy đủ của camera
var movement_duration = 15.0

# kích thước của map
var map_width = 72 * 16  # 72 tiles * 16 pixel = 1152 pixels
var map_height = 39 * 16  # 39 tiles * 16 pixel = 624 pixels

# biên giới an toàn (để camera không nhìn ra ngoài map)
var safe_margin = 100

# các điểm mục tiêu mà camera sẽ di chuyển qua
var target_points = []
var current_target = 0

# đường dẫn movement
var tween

func _ready():
	# tính toán các điểm mục tiêu dựa trên kích thước map
	# và khoảng nhìn của camera
	var viewport_size = get_viewport_rect().size
	var visible_width = viewport_size.x / zoom.x
	var visible_height = viewport_size.y / zoom.y
	
	# tính toán giới hạn di chuyển camera để không nhìn thấy vùng ngoài map
	var min_x = visible_width / 2 + safe_margin
	var max_x = map_width - visible_width / 2 - safe_margin
	var min_y = visible_height / 2 + safe_margin
	var max_y = map_height - visible_height / 2 - safe_margin
	
	# tạo các điểm mục tiêu ở 4 góc (trong giới hạn an toàn)
	target_points = [
		Vector2(min_x, min_y),  # góc trên bên trái
		Vector2(max_x, min_y),  # góc trên bên phải
		Vector2(max_x, max_y),  # góc dưới bên phải
		Vector2(min_x, max_y),  # góc dưới bên trái
	]
	
	# thiết lập vị trí ban đầu
	position = target_points[0]
	
	# bắt đầu di chuyển camera
	move_to_next_target()

# hàm di chuyển camera đến điểm mục tiêu tiếp theo
func move_to_next_target():
	# tăng chỉ số điểm mục tiêu và quay lại từ đầu nếu cần
	current_target = (current_target + 1) % target_points.size()
	
	# tạo tween mới
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target_points[current_target], movement_duration)
	
	# kết nối signal hoàn thành để di chuyển đến điểm tiếp theo
	tween.finished.connect(move_to_next_target) 
