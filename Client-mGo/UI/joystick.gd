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

func _ready():
	# thiết lập ban đầu
	if visibility_mode == 1:
		base.modulate.a = 0.0
	
	# reset thumb về vị trí trung tâm để đảm bảo nó được đặt chính xác
	reset_thumb()
	
func reset_thumb():
	# đặt thumb chính xác vào giữa base
	# cách tính vị trí trung tâm mới
	var base_center = Vector2(base.size.x / 2, base.size.y / 2)
	var thumb_offset = Vector2(thumb.size.x / 2, thumb.size.y / 2)
	
	# đặt vị trí gốc của thumb để tâm của nó nằm giữa base
	thumb.position = base_center - thumb_offset
	output = Vector2.ZERO
	
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
				reset_thumb()  # dùng hàm reset để đảm bảo vị trí chính xác
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
	# tính toán các vị trí trung tâm
	var base_center = Vector2(base.size.x / 2, base.size.y / 2)
	var thumb_center = Vector2(thumb.size.x / 2, thumb.size.y / 2)
	
	# tính vector hướng từ trung tâm base đến điểm chạm
	var direction = (thumb_position - base_center).normalized()
	var distance = (thumb_position - base_center).length()
	
	# áp dụng deadzone
	if distance < deadzone_size:
		reset_thumb()
		output = Vector2.ZERO
		return
	
	# áp dụng clampzone
	if distance > clampzone_size:
		# đặt thumb vị trí mới, tính toán để tâm của thumb nằm đúng vị trí cần thiết
		thumb.position = base_center + direction * clampzone_size - thumb_center
	else:
		thumb.position = thumb_position - thumb_center
	
	# tính toán output vector (0-1)
	var normalized_distance = (distance - deadzone_size) / (clampzone_size - deadzone_size)
	normalized_distance = clamp(normalized_distance, 0.0, 1.0)
	output = direction * normalized_distance

func _is_point_inside_area(point):
	# kiểm tra xem điểm có nằm trong vùng joystick không
	var base_center = base.global_position + Vector2(base.size.x / 2, base.size.y / 2)
	var radius = base.size.x / 2
	return point.distance_to(base_center) < radius 
