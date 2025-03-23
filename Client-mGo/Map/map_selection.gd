extends Control

# Danh sách các map có thể chọn với đường dẫn đã cập nhật
var maps = {
	"KhuNhaO": "res://Map/TileMap/khuNhaO.tscn",
	"KhuSinhThai": "res://Map/TileMap/khuSinhThai.tscn",
	"KhuGiaiTri": "res://Map/TileMap/khuGiaiTri.tscn",
	"CongVien": "res://Map/TileMap/congVien.tscn",
	"KhuThuongMai": "res://Map/TileMap/khuThuongMai.tscn",
	"NongTrai": "res://Map/TileMap/nongTrai.tscn",
	"KhuHangCo": "res://Map/TileMap/khuHangCo.tscn"
}

# tham chiếu đến camera
@onready var camera = $Camera2D

# thời gian di chuyển camera
var camera_tween_duration = 0.5

# zoom mặc định được tính toán dựa trên kích thước màn hình
var default_zoom = 1.0

# kích thước của map
var map_width = 1280
var map_height = 640

# giới hạn camera
var camera_margin = 100 # khoảng cách giới hạn từ biên map

# biến theo dõi trạng thái kéo thả
var is_dragging = false
var drag_start_position = Vector2()
var camera_start_position = Vector2()

# Mảng chứa danh sách các button theo thứ tự
var map_buttons = []

# Vị trí của button đang được chọn trong mảng
var current_selection = 0

var selected_map_path = ""
var selected_button = null
var player_marker_visible = false

# Ma trận liên kết để di chuyển bằng phím mũi tên
# Mỗi phần tử chứa [trái, phải, lên, xuống]
var navigation_map = {
	"KhuNhaO": ["CongVien", "KhuGiaiTri", "KhuHangCo", "CongVien"],
	"KhuSinhThai": ["KhuHangCo", "KhuThuongMai", "KhuHangCo", "KhuThuongMai"],
	"KhuGiaiTri": ["KhuNhaO", "NongTrai", "KhuThuongMai", "NongTrai"],
	"CongVien": ["KhuNhaO", "KhuHangCo", "KhuNhaO", "KhuHangCo"],
	"KhuThuongMai": ["KhuSinhThai", "NongTrai", "KhuSinhThai", "NongTrai"],
	"NongTrai": ["KhuGiaiTri", "KhuThuongMai", "KhuGiaiTri", "KhuThuongMai"],
	"KhuHangCo": ["CongVien", "KhuSinhThai", "CongVien", "KhuSinhThai"]
}

func _ready():
	# Mặc định chưa chọn map nào
	selected_map_path = ""
	
	# Ẩn marker ban đầu
	$PlayerMarker.hide()
	
	# kích thước map tính bằng pixels
	map_width = 72 * 16 # 72 tiles * 16 pixels
	map_height = 39 * 16 # 39 tiles * 16 pixels
	
	# Thiết lập camera
	camera.enabled = true
	
	# Thiết lập giới hạn camera
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_width 
	camera.limit_bottom = map_height
	
	# Tự động điều chỉnh zoom dựa trên tỷ lệ kích thước màn hình và map
	calculate_and_set_optimal_zoom()
	
	# Đặt vị trí ban đầu ở giữa map
	camera.position = Vector2(map_width / 2, map_height / 2)
	
	# Chuẩn bị danh sách các button
	for button_name in maps.keys():
		map_buttons.append(button_name)
		
		# đảm bảo nút không nhận focus (tránh hiện khung outline)
		var button = get_node_or_null("MapButtons/" + button_name)
		if button:
			button.focus_mode = Control.FOCUS_NONE
	
	# Phát hiệu ứng chuyển cảnh khi vào màn hình chọn map
	$UI/TransitionEffect.play_transition("Chọn khu vực...")
	
	# Tự động chọn khu giải trí (sau khi hiệu ứng bắt đầu)
	await get_tree().create_timer(0.2).timeout # Đợi một chút để UI được khởi tạo
	_select_area("KhuGiaiTri")

func _input(event):
	# Xử lý input phím mũi tên
	if event.is_action_pressed("ui_left"):
		_navigate_selection("left")
	elif event.is_action_pressed("ui_right"):
		_navigate_selection("right")
	elif event.is_action_pressed("ui_up"):
		_navigate_selection("up")
	elif event.is_action_pressed("ui_down"):
		_navigate_selection("down")
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		# Xác nhận chọn map
		if selected_map_path:
			_on_play_button_pressed()
	
	# Xử lý kéo thả camera
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Bắt đầu kéo
				is_dragging = true
				drag_start_position = event.position
				camera_start_position = camera.position
			else:
				# Kết thúc kéo
				is_dragging = false
	
	elif event is InputEventMouseMotion and is_dragging:
		# Tính toán khoảng cách kéo và cập nhật vị trí camera
		var drag_distance = event.position - drag_start_position
		var new_camera_position = camera_start_position - drag_distance / camera.zoom
		
		# Giới hạn camera trong phạm vi map
		new_camera_position.x = clamp(new_camera_position.x, camera.limit_left, camera.limit_right)
		new_camera_position.y = clamp(new_camera_position.y, camera.limit_top, camera.limit_bottom)
		
		# Cập nhật vị trí camera
		camera.position = new_camera_position

# Thêm hàm _unhandled_input để đảm bảo xử lý các sự kiện chuột không bị chặn bởi UI
func _unhandled_input(event):
	# Phát hiện sự kiện lăn chuột để zoom in/out
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in
			zoom_camera(0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out
			zoom_camera(-0.1)

# Hàm hỗ trợ zoom camera cập nhật với giới hạn không vượt ra ngoài map
func zoom_camera(zoom_factor):
	# Lấy kích thước viewport hiện tại
	var viewport_size = get_viewport_rect().size
	
	# Tính toán zoom mới
	var new_zoom = camera.zoom * (1 + zoom_factor)
	
	# Tính toán mức zoom tối thiểu để map lấp đầy màn hình (không thấy vùng ngoài map)
	var min_zoom_x = viewport_size.x / map_width
	var min_zoom_y = viewport_size.y / map_height
	
	# Chọn giá trị lớn hơn để đảm bảo không nhìn thấy vùng ngoài map
	var min_zoom = max(min_zoom_x, min_zoom_y)
	
	# Tính toán mức zoom tối đa (để không zoom in quá gần)
	var max_zoom = 2.0
	
	# Giới hạn zoom trong khoảng [min_zoom, max_zoom]
	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
	
	# Lưu vị trí chuột trước khi zoom
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Tạo hiệu ứng zoom mượt mà
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "zoom", new_zoom, 0.2)
	
	# Điều chỉnh vị trí camera để tránh nhìn thấy vùng ngoài map
	tween.tween_callback(adjust_camera_position_after_zoom)
	
	# Cập nhật zoom mặc định
	default_zoom = new_zoom.x

# Hàm mới để điều chỉnh vị trí camera sau khi zoom
func adjust_camera_position_after_zoom():
	# Tính toán giới hạn hiển thị dựa trên zoom và kích thước viewport
	var viewport_size = get_viewport_rect().size
	var visible_area_half_width = viewport_size.x / (2 * camera.zoom.x)
	var visible_area_half_height = viewport_size.y / (2 * camera.zoom.y)
	
	# Tính toán biên giới camera nên ở đâu
	var effective_left = visible_area_half_width
	var effective_right = map_width - visible_area_half_width
	var effective_top = visible_area_half_height
	var effective_bottom = map_height - visible_area_half_height
	
	# Nếu map nhỏ hơn viewport khi zoom, đặt camera ở giữa map
	if effective_left > effective_right:
		camera.position.x = map_width / 2
	else:
		camera.position.x = clamp(camera.position.x, effective_left, effective_right)
	
	if effective_top > effective_bottom:
		camera.position.y = map_height / 2
	else:
		camera.position.y = clamp(camera.position.y, effective_top, effective_bottom)

# Cập nhật hàm calculate_and_set_optimal_zoom() để sử dụng mức zoom tối thiểu
func calculate_and_set_optimal_zoom():
	# Lấy kích thước của viewport (màn hình hiển thị)
	var viewport_size = get_viewport_rect().size
	
	# Tính tỷ lệ để map lấp đầy màn hình theo chiều ngang và chiều dọc
	var zoom_x = viewport_size.x / map_width
	var zoom_y = viewport_size.y / map_height
	
	# Sử dụng giá trị lớn hơn để đảm bảo không nhìn thấy vùng ngoài map
	var min_zoom = max(zoom_x, zoom_y)
	
	# Điều chỉnh zoom để có khoảng cách xung quanh map
	var optimal_zoom = min_zoom * 0.9  # giảm 10% để có khoảng trống xung quanh
	
	# Đảm bảo zoom không quá nhỏ
	optimal_zoom = max(optimal_zoom, min_zoom)
	
	# Đảm bảo zoom không quá lớn
	optimal_zoom = min(optimal_zoom, 2.0)
	
	# Thiết lập zoom cho camera
	camera.zoom = Vector2(optimal_zoom, optimal_zoom)
	
	# Lưu giá trị zoom mặc định để sử dụng sau này
	default_zoom = optimal_zoom
	
	# Điều chỉnh vị trí camera để không nhìn thấy vùng ngoài map
	adjust_camera_position_after_zoom()

# hàm mới để di chuyển camera đến khu vực được chọn
func move_camera_to_button(button):
	# lấy vị trí toàn cục của nút
	var target_position = button.global_position + Vector2(button.size.x/2, button.size.y/2)
	
	# đảm bảo vị trí nằm trong giới hạn camera
	target_position.x = clamp(target_position.x, camera.limit_left, camera.limit_right)
	target_position.y = clamp(target_position.y, camera.limit_top, camera.limit_bottom)
	
	# tạo tween để di chuyển camera mượt mà
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", target_position, camera_tween_duration)
	
	# zoom vào khu vực được chọn thêm một chút so với zoom mặc định
	var zoom_in_level = default_zoom * 1.5
	tween.parallel().tween_property(camera, "zoom", Vector2(zoom_in_level, zoom_in_level), camera_tween_duration)

# Các hàm xử lý khi nhấn vào các khu vực
func _on_khu_nha_o_pressed():
	_select_area("KhuNhaO")

func _on_khu_sinh_thai_pressed():
	_select_area("KhuSinhThai")

func _on_khu_giai_tri_pressed():
	_select_area("KhuGiaiTri")
	
func _on_cong_vien_pressed():
	_select_area("CongVien")
	
func _on_khu_thuong_mai_pressed():
	_select_area("KhuThuongMai")
	
func _on_nong_trai_pressed():
	_select_area("NongTrai")
	
func _on_khu_hang_co_pressed():
	_select_area("KhuHangCo")

func _on_play_button_pressed():
	if selected_map_path.is_empty():
		# không thể chơi nếu chưa chọn map
		var dialog = AcceptDialog.new()
		dialog.title = "Thông báo"
		dialog.dialog_text = "Vui lòng chọn một khu vực trước khi bắt đầu chơi!"
		add_child(dialog)
		dialog.popup_centered()
		return
	
	# lưu lựa chọn map vào autoload để Map.tscn có thể truy cập
	Network.selected_map_path = selected_map_path
	
	# chuyển đến màn hình Map trực tiếp, không cần hiệu ứng
	get_tree().change_scene_to_file("res://Map/Map.tscn")

func _on_back_button_pressed():
	# ngắt kết nối khi quay lại màn hình đăng nhập
	if Network.is_connected:
		Network.websocket.close()
	
	# chuyển về màn hình đăng nhập trực tiếp, không cần hiệu ứng
	get_tree().change_scene_to_file("res://Login/Login.tscn") 

func _reset_all_buttons():
	# Đặt lại trạng thái tất cả các nút
	for button_name in maps.keys():
		var button = get_node_or_null("MapButtons/" + button_name)
		if button:
			button.modulate = Color(1, 1, 1, 1)

func _select_area(button_name):
	# Đặt lại trạng thái các nút
	_reset_all_buttons()
	
	# Lấy nút và đường dẫn map tương ứng
	var button = get_node("MapButtons/" + button_name)
	selected_map_path = maps[button_name]
	selected_button = button
	
	# chỉ thay đổi màu nút được chọn
	button.modulate = Color(1, 0.8, 0, 1)  # Màu vàng khi chọn
	
	# Di chuyển camera đến khu vực được chọn
	move_camera_to_button(button)
	
	# Hiển thị marker tại vị trí nút nếu cần
	if player_marker_visible:
		$PlayerMarker.visible = true
		$PlayerMarker.global_position = button.global_position + Vector2(button.size.x/2, button.size.y/2)
		$PlayerMarker.global_position -= Vector2($PlayerMarker.size.x/2, $PlayerMarker.size.y/2)

# hàm thiết lập giới hạn camera
func setup_camera_limits():
	# Tính toán giới hạn camera dựa trên kích thước map và zoom
	var viewport_size = get_viewport_rect().size
	var zoom_level = camera.zoom.x  # Giả sử zoom.x = zoom.y
	
	# Tính toán khoảng cách tối đa camera có thể di chuyển từ tâm
	var limit_left = camera_margin
	var limit_right = map_width - camera_margin
	var limit_top = camera_margin 
	var limit_bottom = map_height - camera_margin
	
	# Thiết lập giới hạn cho camera
	camera.limit_left = limit_left
	camera.limit_right = limit_right
	camera.limit_top = limit_top
	camera.limit_bottom = limit_bottom

func _navigate_selection(direction):
	if selected_button == null:
		# Nếu chưa có nút nào được chọn, chọn mặc định khu giải trí
		_select_area("KhuGiaiTri")
		return
	
	var current_button_name = ""
	for button_name in maps.keys():
		var button = get_node_or_null("MapButtons/" + button_name)
		if button == selected_button:
			current_button_name = button_name
			break
	
	if current_button_name == "":
		return
		
	var direction_index = 0
	match direction:
		"left": direction_index = 0
		"right": direction_index = 1
		"up": direction_index = 2
		"down": direction_index = 3
	
	# Lấy tên nút tiếp theo từ ma trận liên kết
	var next_button_name = navigation_map[current_button_name][direction_index]
	_select_area(next_button_name)
