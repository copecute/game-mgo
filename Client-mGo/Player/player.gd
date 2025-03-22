extends CharacterBody2D

@export var speed := 120
@onready var anim = $AnimatedSprite2D
@onready var name_label = $NameLabel
@onready var camera = $Camera2D

# kích thước map tính bằng pixels
const MAP_WIDTH = 72 * 16  # 72 tiles * 16 pixels
const MAP_HEIGHT = 39 * 16 # 39 tiles * 16 pixels

var target_position = Vector2.ZERO
var moving_to_target = false
var username = ""
var last_position = Vector2.ZERO
var last_sent_position = Vector2.ZERO
const POSITION_UPDATE_THRESHOLD = 5.0
var joystick_direction = Vector2.ZERO

func _ready():
	if username.is_empty():
		username = Network.current_username
	name_label.text = username
	last_position = global_position
	last_sent_position = global_position
	
	# thiết lập giới hạn camera
	var viewport_size = get_viewport_rect().size
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP_WIDTH
	camera.limit_bottom = MAP_HEIGHT
	
	# kết nối với joystick nếu là người chơi hiện tại
	if username == Network.current_username:
		var joystick = get_node_or_null("/root/Map/UI/Joystick")
		if joystick:
			joystick.joystick_moved.connect(_on_joystick_moved)

func _on_joystick_moved(vector):
	joystick_direction = vector
	# nếu joystick đang được sử dụng, hủy di chuyển theo click chuột
	if vector != Vector2.ZERO:
		moving_to_target = false

func _unhandled_input(event):
	# Chỉ xử lý input cho nhân vật của mình
	if username != Network.current_username:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# kiểm tra xem click có phải trên joystick không
		var joystick = get_node_or_null("/root/Map/UI/Joystick")
		if joystick and joystick._is_point_inside_area(event.position):
			return
			
		target_position = get_global_mouse_position()
		moving_to_target = true

func _process(delta):
	# Chỉ xử lý di chuyển cho nhân vật của mình
	if username != Network.current_username:
		return
		
	var direction = Vector2.ZERO

	# ưu tiên điều khiển bằng joystick
	if joystick_direction != Vector2.ZERO:
		direction = joystick_direction
	else:
		# Điều khiển bằng phím
		if Input.is_action_pressed("ui_right"):
			direction.x += 1
			anim.flip_h = false
			moving_to_target = false
		if Input.is_action_pressed("ui_left"):
			direction.x -= 1
			anim.flip_h = true
			moving_to_target = false
		if Input.is_action_pressed("ui_down"):
			direction.y += 1
			moving_to_target = false
		if Input.is_action_pressed("ui_up"):
			direction.y -= 1
			moving_to_target = false

		# Nếu không bấm phím, di chuyển tới vị trí click chuột
		if moving_to_target:
			direction = (target_position - global_position).normalized()
			
			if global_position.distance_to(target_position) < 5:
				moving_to_target = false

			if direction.x > 0:
				anim.flip_h = false
			elif direction.x < 0:
				anim.flip_h = true

	velocity = direction * speed if direction != Vector2.ZERO else Vector2.ZERO
	move_and_slide()

	# Kiểm tra trạng thái để đổi animation
	if velocity.length() > 0:
		anim.play("Run")
	else:
		anim.play("Idile")

	# Gửi vị trí mới lên server nếu:
	# 1. Đang di chuyển và đã đi được một khoảng cách nhất định
	# 2. Vừa dừng di chuyển (để cập nhật vị trí cuối cùng)
	var distance_moved = global_position.distance_to(last_sent_position)
	if (velocity.length() > 0 and distance_moved > POSITION_UPDATE_THRESHOLD) or \
	   (velocity.length() == 0 and last_position != global_position):
		_send_position_to_server()
		last_sent_position = global_position
	
	last_position = global_position

func _send_position_to_server():
	var move_data = {
		"type": "move",
		"data": str(global_position.x) + "," + str(global_position.y)
	}
	Network.send_message(move_data)
