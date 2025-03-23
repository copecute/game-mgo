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
	$UI/PlayerMarker.hide()
	
	# Chuẩn bị danh sách các button
	for button_name in maps.keys():
		map_buttons.append(button_name)
		
		# đảm bảo nút không nhận focus (tránh hiện khung outline)
		var button = get_node_or_null("UI/MapViewport/MapButtons/" + button_name)
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

func _navigate_selection(direction):
	if selected_button == null:
		# Nếu chưa có nút nào được chọn, chọn mặc định khu giải trí
		_select_area("KhuGiaiTri")
		return
	
	var current_button_name = ""
	for button_name in maps.keys():
		var button = get_node_or_null("UI/MapViewport/MapButtons/" + button_name)
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

func _reset_all_buttons():
	# Đặt lại trạng thái tất cả các nút
	for button_name in maps.keys():
		var button = get_node_or_null("UI/MapViewport/MapButtons/" + button_name)
		if button:
			button.modulate = Color(1, 1, 1, 1)

func _select_area(button_name):
	# Đặt lại trạng thái các nút
	_reset_all_buttons()
	
	# Lấy nút và đường dẫn map tương ứng
	var button = get_node("UI/MapViewport/MapButtons/" + button_name)
	selected_map_path = maps[button_name]
	selected_button = button
	
	# chỉ thay đổi màu nút được chọn, không grab_focus()
	button.modulate = Color(1, 0.8, 0, 1)  # Màu vàng khi chọn
	
	# hiển thị ảnh minh họa cho khu vực đã chọn (nếu cần)
	# ...
	
	# Hiển thị marker tại vị trí nút nếu cần
	if player_marker_visible:
		$UI/PlayerMarker.visible = true
		$UI/PlayerMarker.global_position = button.global_position + Vector2(button.size.x/2, button.size.y/2)
		$UI/PlayerMarker.global_position -= Vector2($UI/PlayerMarker.size.x/2, $UI/PlayerMarker.size.y/2)

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
