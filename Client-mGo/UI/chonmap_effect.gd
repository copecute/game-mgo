extends Control

signal transition_halfway

var is_transitioning = false  # Biến để theo dõi trạng thái
var screen_size = Vector2.ZERO
var animation_progress = 0.0  # Tiến trình animation (0.0 - 1.0)
var animation_duration = 2.0  # Thời gian animation (giây)
var current_time = 0.0  # Thời gian hiện tại của animation
var halfway_emitted = false  # Đã phát tín hiệu halfway chưa
var target_scene = ""  # Đường dẫn đến scene sẽ chuyển tới

func _ready():
	# Lấy kích thước màn hình
	screen_size = get_viewport_rect().size
	
	# thiết lập ban đầu - màn hình đen hoàn toàn
	show_fullscreen_black()
	$Label.text = "Đang tải map..."
	$Label.modulate.a = 1.0
	show()
	
	# Kết nối với tín hiệu thay đổi kích thước màn hình
	get_tree().root.size_changed.connect(_on_screen_resized)

func _process(delta):
	if is_transitioning:
		# Cập nhật thời gian
		current_time += delta
		
		# Tính toán tiến trình (0.0 - 1.0)
		animation_progress = min(current_time / animation_duration, 1.0)
		
		# Cập nhật vị trí cửa
		update_door_positions(animation_progress)
		
		# Cập nhật độ trong suốt của nhãn
		if animation_progress < 0.5:
			$Label.modulate.a = max(1.0 - animation_progress * 2, 0.0)
		
		# Phát tín hiệu halfway khi đến giữa animation
		if animation_progress >= 0.5 and not halfway_emitted:
			emit_signal("transition_halfway")
			halfway_emitted = true
		
		# Kết thúc animation
		if animation_progress >= 1.0:
			is_transitioning = false
			hide()  # Ẩn hiệu ứng sau khi hoàn tất
			
			# Chuyển scene nếu có chỉ định
			if not target_scene.is_empty():
				get_tree().change_scene_to_file(target_scene)
				target_scene = ""

func _on_screen_resized():
	# Cập nhật kích thước màn hình
	screen_size = get_viewport_rect().size
	
	# Cập nhật vị trí cửa ngay lập tức
	if is_transitioning:
		# Nếu đang trong quá trình chuyển cảnh, cập nhật vị trí theo tiến trình hiện tại
		update_door_positions(animation_progress)
	else:
		# Nếu không đang transition nhưng vẫn hiển thị, có thể là màn hình đen ban đầu
		if visible:
			show_fullscreen_black()

# hiển thị màn hình đen đầy đủ
func show_fullscreen_black():
	# đặt cả hai cửa để che phủ toàn bộ màn hình
	var center_y = screen_size.y / 2
	
	# cửa trên che nửa trên màn hình
	$TopRect.position = Vector2(0, 0)
	$TopRect.size = Vector2(screen_size.x, center_y)
	
	# cửa dưới che nửa dưới màn hình
	$BottomRect.position = Vector2(0, center_y)
	$BottomRect.size = Vector2(screen_size.x, center_y)

func update_door_positions(progress: float):
	# hiệu ứng chỉ mở cửa từ giữa ra ngoài
	var center_y = screen_size.y / 2
	
	# cửa trên di chuyển lên
	$TopRect.position.y = lerp(0.0, -center_y, progress)
	$TopRect.size = Vector2(screen_size.x, center_y)
	
	# cửa dưới di chuyển xuống
	$BottomRect.position.y = lerp(center_y, screen_size.y, progress)
	$BottomRect.size = Vector2(screen_size.x, center_y)

# hàm mới để chuyển cảnh với hiệu ứng
func transition_to_scene(scene_path, message = "Đang chuyển map..."):
	target_scene = scene_path
	play_transition(message)

func play_transition(message = ""):
	# Nếu đang trong quá trình chuyển cảnh, không kích hoạt lại
	if is_transitioning:
		return
		
	# Đặt lại các biến
	is_transitioning = true
	current_time = 0.0
	animation_progress = 0.0
	halfway_emitted = false
	
	# Hiển thị thông báo nếu có
	if message != "":
		$Label.text = message
	
	# Cập nhật kích thước màn hình
	screen_size = get_viewport_rect().size
	
	# đảm bảo màn hình đen hoàn toàn
	show_fullscreen_black()
	$Label.modulate.a = 1.0
	
	# Hiển thị hiệu ứng
	show() 
