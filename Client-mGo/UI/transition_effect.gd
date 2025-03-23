extends Control

signal transition_halfway
signal transition_finished

var is_transitioning = false  # Biến để theo dõi trạng thái
var screen_size = Vector2.ZERO
var animation_progress = 0.0  # Tiến trình animation (0.0 - 1.0)
var animation_duration = 2.0  # Thời gian animation (giây)
var current_time = 0.0  # Thời gian hiện tại của animation
var halfway_emitted = false  # Đã phát tín hiệu halfway chưa

func _ready():
	# Lấy kích thước màn hình
	screen_size = get_viewport_rect().size
	
	# Ẩn hiệu ứng khi khởi tạo
	reset_door_positions()
	$Label.modulate.a = 0
	hide()
	
	# Kết nối với Network để nhận thông tin chuyển khu
	Network.server_message_received.connect(_on_server_message_received)
	
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
			$Label.modulate.a = min(animation_progress * 2, 1.0)
		else:
			$Label.modulate.a = max(1.0 - (animation_progress - 0.5) * 2, 0.0)
		
		# Phát tín hiệu halfway khi đến giữa animation
		if animation_progress >= 0.5 and not halfway_emitted:
			emit_signal("transition_halfway")
			halfway_emitted = true
		
		# Kết thúc animation
		if animation_progress >= 1.0:
			is_transitioning = false
			emit_signal("transition_finished")

func _on_screen_resized():
	# Cập nhật kích thước màn hình
	screen_size = get_viewport_rect().size
	
	# Cập nhật vị trí cửa
	if not is_transitioning:
		reset_door_positions()

func reset_door_positions():
	# Đặt lại vị trí ban đầu của cửa
	var center_y = screen_size.y / 2
	
	# Cửa trên nằm từ trên xuống đến giữa màn hình
	$TopRect.position = Vector2(0, 0)
	$TopRect.size = Vector2(screen_size.x, center_y)
	
	# Cửa dưới nằm từ giữa màn hình xuống dưới
	$BottomRect.position = Vector2(0, center_y)
	$BottomRect.size = Vector2(screen_size.x, center_y)

func update_door_positions(progress: float):
	# Cập nhật vị trí cửa theo tiến trình animation (0.0 - 1.0)
	var center_y = screen_size.y / 2
	
	# Cửa trên di chuyển lên trên
	$TopRect.position.y = lerp(0.0, -center_y, progress)
	$TopRect.size = Vector2(screen_size.x, center_y)
	
	# Cửa dưới di chuyển xuống dưới
	$BottomRect.position.y = lerp(center_y, screen_size.y, progress)
	$BottomRect.size = Vector2(screen_size.x, center_y)

func _on_server_message_received(message):
	var data = JSON.parse_string(message)
	if not data or not data.has("type"):
		return
		
	match data["type"]:
		"map_selected":
			# Khi vào map mới
			play_transition("Đang tải map...")
			
		"instance_changed":
			# Khi chuyển khu
			play_transition("Đang chuyển khu...")

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
	
	# Đặt lại vị trí ban đầu
	reset_door_positions()
	$Label.modulate.a = 0
	
	# Hiển thị hiệu ứng
	show() 