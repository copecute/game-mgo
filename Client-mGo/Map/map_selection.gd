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
	
	# Trước khi cập nhật vị trí
	for button_name in maps.keys():
		call_deferred("recreate_button_structure", button_name)
	
	# Đợi tất cả button được tạo lại cấu trúc
	await get_tree().process_frame
	await get_tree().process_frame
	
	# QUAN TRỌNG: Cập nhật vị trí các button TRƯỚC khi hiệu ứng chuyển cảnh
	# và trước khi chọn khu vực đầu tiên
	update_button_positions()
	
	# kết nối với tín hiệu thay đổi kích thước màn hình
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	
	# Phát hiệu ứng chuyển cảnh khi vào màn hình chọn map
	$UI/TransitionEffect.play_transition("Chọn khu vực...")
	
	# Đảm bảo các button đã được đặt vị trí trước khi chọn khu vực đầu tiên
	call_deferred("_select_initial_area")

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

# hàm mới để cập nhật vị trí các button theo map
func update_button_positions():
	# đảm bảo các button nằm trong node MapButtons
	var map_buttons_control = $MapButtons
	
	# thiết lập lại vị trí của MapButtons để nó có cùng kích thước với map
	map_buttons_control.position = Vector2.ZERO
	map_buttons_control.size = Vector2(map_width, map_height)
	
	# Đảm bảo layout đúng
	map_buttons_control.size_flags_horizontal = Control.SIZE_FILL
	map_buttons_control.size_flags_vertical = Control.SIZE_FILL
	
	# vị trí tương đối cho từng nút (tỷ lệ so với kích thước map)
	var button_positions = {
		"KhuNhaO": Vector2(0.31, 0.32),
		"KhuSinhThai": Vector2(0.65, 0.32),
		"KhuGiaiTri": Vector2(0.48, 0.43),
		"CongVien": Vector2(0.31, 0.5),
		"KhuThuongMai": Vector2(0.65, 0.5),
		"NongTrai": Vector2(0.65, 0.67),
		"KhuHangCo": Vector2(0.31, 0.67)
	}
	
	# áp dụng vị trí vào các nút
	for button_name in button_positions.keys():
		var button = map_buttons_control.get_node_or_null(button_name)
		if button:
			# cập nhật các thuộc tính anchor trước
			button.anchor_left = 0
			button.anchor_top = 0
			button.anchor_right = 0
			button.anchor_bottom = 0
			
			# đợi một frame để thuộc tính được áp dụng
			await get_tree().process_frame
			
			var rel_pos = button_positions[button_name]
			var abs_pos = Vector2(rel_pos.x * map_width, rel_pos.y * map_height)
			
			# đảm bảo kích thước button đã được tính
			var button_size = button.size
			if button_size.x == 0 or button_size.y == 0:
				button_size = Vector2(100, 80) # kích thước mặc định nếu chưa có
			
			# Trừ đi một nửa kích thước của button để canh giữa
			abs_pos -= Vector2(button_size.x / 2, button_size.y / 2)
			
			# thiết lập vị trí mới
			button.position = abs_pos
			
			# Debug để kiểm tra vị trí
			print("Button ", button_name, " đặt tại ", button.position, ", kích thước: ", button.size)

	# Sau khi đã đặt vị trí cho tất cả button
	update_button_contents()

# cập nhật lại khi kích thước màn hình thay đổi
func _on_viewport_size_changed():
	# cập nhật lại zoom và vị trí camera
	calculate_and_set_optimal_zoom()
	
	# cập nhật lại vị trí các button
	update_button_positions()

func _select_initial_area():
	# Chờ một frame để đảm bảo UI đã được khởi tạo đầy đủ
	await get_tree().process_frame
	# Tự động chọn khu giải trí 
	_select_area("KhuGiaiTri")

# Hàm cập nhật vị trí các thành phần trong button
func update_button_contents():
	for button_name in maps.keys():
		var button = $MapButtons.get_node_or_null(button_name)
		if button:
			# Lấy các thành phần con
			var label = button.get_node_or_null("Label")
			var img = button.get_node_or_null("img" + button_name)
			
			if label:
				# Thiết lập vị trí label ở trên button
				label.anchor_left = 0
				label.anchor_top = 0
				label.anchor_right = 1
				label.anchor_bottom = 0.5
				
				# Điều chỉnh offset để nhãn hiển thị ở đúng vị trí
				label.offset_top = 5
				label.offset_bottom = 30
			
			if img:
				# Đặt hình ảnh ở dưới nhãn
				img.anchor_left = 0.5
				img.anchor_top = 0.5
				img.anchor_right = 0.5
				img.anchor_bottom = 0.5
				
				# Đẩy hình ảnh xuống dưới nhãn
				var texture_height = img.texture.get_height() if img.texture else 50
				img.offset_top = -texture_height / 2 + 15
				img.offset_bottom = texture_height / 2 + 15

# Cập nhật hàm recreate_button_structure để giữ lại label gốc
func recreate_button_structure(button_name):
	var button = $MapButtons.get_node_or_null(button_name)
	if not button:
		return
		
	# Lấy kích thước button hiện tại để giữ nguyên
	var button_size = button.size
	
	# Lưu lại label hiện có
	var existing_label = button.get_node_or_null("Label")
	var label_text = ""
	
	# Lưu nội dung text nếu label tồn tại
	if existing_label:
		label_text = existing_label.text
	
	# Xóa các node con ngoại trừ label
	for child in button.get_children():
		if child.name != "Label":
			child.queue_free()
	
	# Nếu không có label sẵn, tạo mới
	if not existing_label:
		var label = Label.new()
		label.name = "Label"
		label.text = button_name.capitalize().replace("Khu", "Khu ")
		if button_name == "CongVien":
			label.text = "Công viên"
		elif button_name == "NongTrai": 
			label.text = "Nông trại"
			
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Thiết lập styling cho label
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_font_size_override("font_size", 14)
		
		button.add_child(label)
	
	# Tạo texture rect mới
	var texture_path = "res://assets/UI/map_" + button_name.to_lower() + ".png"
	var img = TextureRect.new()
	img.name = "img" + button_name
	
	# Kiểm tra xem texture có tồn tại không
	if ResourceLoader.exists(texture_path):
		img.texture = load(texture_path)
	else:
		# Sử dụng texture mặc định nếu không tìm thấy
		img.texture = load("res://assets/UI/map_khugiaitri.png")
	
	# Thiết lập rect cho image
	img.anchor_left = 0.5
	img.anchor_top = 0.5
	img.anchor_right = 0.5
	img.anchor_bottom = 0.5
	img.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Điều chỉnh kích thước
	var tex_size = Vector2(img.texture.get_width(), img.texture.get_height()) 
	img.offset_left = -tex_size.x / 2
	img.offset_top = -tex_size.y / 2 + 10 # Đẩy xuống dưới một chút để tạo khoảng cách với label
	img.offset_right = tex_size.x / 2
	img.offset_bottom = tex_size.y / 2 + 10
	
	button.add_child(img)
	
	# Thiết lập kích thước button
	button.custom_minimum_size = Vector2(100, 80)
	button.size = button_size
