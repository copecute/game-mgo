extends Control

var current_instance_id = 1

func _ready():
	# Kết nối với Network để nhận thông tin khu
	Network.server_message_received.connect(_on_server_message_received)
	update_display()

func _on_server_message_received(message):
	var data = JSON.parse_string(message)
	if not data or not data.has("type"):
		return
		
	match data["type"]:
		"current_instance":
			# Cập nhật khu hiện tại
			current_instance_id = int(data["data"])
			update_display()
			
		"instance_changed":
			# Đã chuyển khu thành công
			current_instance_id = int(data["data"])
			update_display()

func update_display():
	$Panel/Label.text = "Khu vực: " + str(current_instance_id) 