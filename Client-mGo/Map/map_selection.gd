extends Control

# Danh sách các map có thể chọn
var maps = {
	"Map 1": "res://Map/TileMap/map_1.tscn",
	"Map 2": "res://Map/TileMap/map_2.tscn"
}

var selected_map_path = ""

func _ready():
	# Điền danh sách map vào OptionButton
	var map_option = $CenterContainer/VBoxContainer/MapContainer/MapOptionButton
	for map_name in maps.keys():
		map_option.add_item(map_name)
	
	# Chọn map đầu tiên mặc định
	if map_option.item_count > 0:
		map_option.select(0)
		selected_map_path = maps.values()[0]

func _on_map_option_button_item_selected(index):
	# Lấy tên map từ index được chọn
	var map_name = $CenterContainer/VBoxContainer/MapContainer/MapOptionButton.get_item_text(index)
	# Lưu đường dẫn map đã chọn
	selected_map_path = maps[map_name]

func _on_play_button_pressed():
	if selected_map_path.is_empty():
		$CenterContainer/VBoxContainer/StatusLabel.text = "Vui lòng chọn map!"
		$CenterContainer/VBoxContainer/StatusLabel.modulate = Color(1, 0, 0)
		return
	
	# Lưu lựa chọn map vào autoload để Map.tscn có thể truy cập
	Network.selected_map_path = selected_map_path
	
	# Chuyển đến màn hình Map
	get_tree().change_scene_to_file("res://Map/Map.tscn")

func _on_back_button_pressed():
	# Ngắt kết nối khi quay lại màn hình đăng nhập
	if Network.is_connected:
		Network.websocket.close()
	
	get_tree().change_scene_to_file("res://Login/Login.tscn") 
