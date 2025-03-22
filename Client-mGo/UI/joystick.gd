extends Control

# tín hiệu khi joystick di chuyển
signal joystick_moved(vector)

# các biến cấu hình
@export var deadzone_size : float = 10.0
@export var clampzone_size : float = 75.0
@export var visibility_mode : int = 0  # 0: luôn hiển thị, 1: chỉ hiển thị khi chạm

# các node tham chiếu
@onready var base = $Base
@onready var thumb = $Base/Thumb

# các biến theo dõi trạng thái
var touch_index = -1  # id của touch event đang xử lý
var touch_position = Vector2.ZERO  # vị trí chạm hiện tại
var thumb_position = Vector2.ZERO  # vị trí của thumb
var is_active = false  # joystick có đang được sử dụng không
var output = Vector2.ZERO  # vector hướng đầu ra
var center_position = Vector2.ZERO  # vị trí trung tâm của base

func _ready():
	# thiết lập ban đầu
	if visibility_mode == 1:
		base.modulate.a = 0.0
	
	# lưu vị trí trung tâm
	center_position = Vector2.ZERO
	
	# đặt vị trí ban đầu của thumb
	thumb.position = center_position

func _input(event):
	# xử lý touch input
	if event is InputEventScreenTouch:
		if event.pressed:
			# bắt đầu chạm mới
			if touch_index == -1 and _is_point_inside_area(event.position):
				touch_index = event.index
				touch_position = event.position
				thumb_position = event.position - base.global_position
				is_active = true
				
				# giới hạn thumb trong phạm vi base
				_update_thumb_position()
				
				# hiển thị joystick nếu đang ở chế độ ẩn
				if visibility_mode == 1:
					base.modulate.a = 1.0
		else:
			# kết thúc chạm
			if touch_index == event.index:
				# reset joystick
				is_active = false
				touch_index = -1
				thumb.position = center_position  # trở về vị trí trung tâm
				output = Vector2.ZERO
				emit_signal("joystick_moved", output)
				
				# ẩn joystick nếu đang ở chế độ ẩn
				if visibility_mode == 1:
					base.modulate.a = 0.0
	
	# xử lý di chuyển ngón tay
	elif event is InputEventScreenDrag:
		if touch_index == event.index:
			touch_position = event.position
			thumb_position = event.position - base.global_position
			
			# giới hạn thumb trong phạm vi base
			_update_thumb_position()

func _process(_delta):
	if is_active:
		emit_signal("joystick_moved", output)

func _update_thumb_position():
	# tính toán vector từ tâm đến vị trí chạm
	var direction = thumb_position.normalized()
	var distance = thumb_position.length()
	
	# áp dụng deadzone
	if distance < deadzone_size:
		thumb.position = center_position
		output = Vector2.ZERO
		return
	
	# áp dụng clampzone
	if distance > clampzone_size:
		thumb.position = direction * clampzone_size
	else:
		thumb.position = thumb_position
	
	# tính toán output vector (0-1)
	var normalized_distance = (distance - deadzone_size) / (clampzone_size - deadzone_size)
	normalized_distance = clamp(normalized_distance, 0.0, 1.0)
	output = direction * normalized_distance

func _is_point_inside_area(point):
	# kiểm tra xem điểm có nằm trong vùng joystick không
	var center = base.global_position
	var radius = base.size.x / 2
	return point.distance_to(center) < radius 
