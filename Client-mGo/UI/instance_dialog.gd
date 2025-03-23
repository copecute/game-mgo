extends Control

signal instance_selected(instance_id)

var current_map_id = ""
var current_instance_id = 1
var instances_data = []  # Danh sách các khu [id, số người chơi]
var instance_buttons = []  # Danh sách các nút khu

func _ready():
	hide()
	$Panel/VBoxContainer/ButtonsContainer/CancelButton.pressed.connect(_on_cancel_button_pressed)
	
	# Kết nối với Network để nhận thông tin khu
	Network.server_message_received.connect(_on_server_message_received)

func show_for_map(map_id):
	print("Showing instance dialog for map: ", map_id)
	current_map_id = map_id
	$Panel/VBoxContainer/TitleLabel.text = "Chọn khu - " + get_map_name(map_id)
	
	# Xóa danh sách cũ
	clear_instance_buttons()
	instances_data.clear()
	
	# Hiển thị dialog
	show()
	
	# Yêu cầu danh sách khu từ server
	var request = {
		"type": "get_instances",
		"data": map_id
	}
	print("Gửi yêu cầu lấy thông tin khu: ", request)
	Network.send_message(request)

func get_map_name(map_id):
	# Trích xuất tên map từ đường dẫn
	var parts = map_id.split("/")
	var filename = parts[parts.size() - 1]
	return filename.replace(".tscn", "").capitalize()

func clear_instance_buttons():
	# Xóa tất cả các nút khu cũ
	for button in instance_buttons:
		if is_instance_valid(button):
			button.queue_free()
	instance_buttons.clear()

func _on_server_message_received(message):
	var data = JSON.parse_string(message)
	if not data or not data.has("type"):
		return
		
	match data["type"]:
		"map_instances":
			# Format: instanceId,playerCount;instanceId,playerCount;...
			var instances_str = data["data"]
			var instances = instances_str.split(";")
			
			clear_instance_buttons()
			instances_data.clear()
			
			print("Nhận được thông tin về ", instances.size(), " khu")
			
			for instance in instances:
				var parts = instance.split(",")
				if parts.size() == 2:
					var instance_id = int(parts[0])
					var player_count = int(parts[1])
					
					# Thêm vào danh sách
					instances_data.append([instance_id, player_count])
					
					# Tạo nút cho khu
					var button = Button.new()
					var is_current = instance_id == current_instance_id
					var is_full = player_count >= 25
					
					# Thiết lập nút
					button.text = "Khu %d\n(%d/25)" % [instance_id, player_count]
					button.custom_minimum_size = Vector2(100, 60)
					button.disabled = is_current || is_full
					
					# Thiết lập màu sắc dựa trên trạng thái
					if is_current:
						button.modulate = Color(0.2, 1.0, 0.2)  # Xanh lá (khu hiện tại)
					elif is_full:
						button.modulate = Color(1.0, 0.2, 0.2)  # Đỏ (khu đầy)
					elif player_count > 15:
						button.modulate = Color(1.0, 0.8, 0.2)  # Vàng (khu đông)
					else:
						button.modulate = Color(0.2, 0.8, 1.0)  # Xanh dương (khu vắng)
					
					# Kết nối sự kiện nhấn nút
					button.pressed.connect(_on_instance_button_pressed.bind(instance_id))
					
					# Thêm vào grid
					$Panel/VBoxContainer/GridContainer.add_child(button)
					instance_buttons.append(button)
			
			# Nếu không có khu nào, hiển thị thông báo
			if instances_data.size() == 0:
				$Panel/VBoxContainer/StatusLabel.text = "Không có khu nào được tìm thấy"
				$Panel/VBoxContainer/StatusLabel.modulate = Color(1, 0, 0)  # Màu đỏ
			else:
				$Panel/VBoxContainer/StatusLabel.text = ""
			
		"current_instance":
			# Cập nhật khu hiện tại
			current_instance_id = int(data["data"])
			
		"instance_changed":
			# Đã chuyển khu thành công
			current_instance_id = int(data["data"])
			hide()
			
		"change_instance_failed":
			# Không thể chuyển khu
			$Panel/VBoxContainer/StatusLabel.text = data["data"]
			$Panel/VBoxContainer/StatusLabel.modulate = Color(1, 0, 0)  # Màu đỏ

func _on_instance_button_pressed(instance_id):
	# Nếu chọn khu hiện tại, không làm gì
	if instance_id == current_instance_id:
		return
		
	# Gửi yêu cầu chuyển khu
	var request = {
		"type": "change_instance",
		"data": current_map_id + "," + str(instance_id)
	}
	Network.send_message(request)
	
	# Cập nhật trạng thái
	$Panel/VBoxContainer/StatusLabel.text = "Đang chuyển khu..."
	$Panel/VBoxContainer/StatusLabel.modulate = Color(1, 1, 1)  # Màu trắng

func _on_cancel_button_pressed():
	hide() 