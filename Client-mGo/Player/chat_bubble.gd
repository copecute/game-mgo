extends Control

var duration = 5.0  # Thời gian hiển thị
var timer = 0.0
@onready var label = $Panel/Label
@onready var panel = $Panel
const MAX_CHARS = 100  # Giới hạn ký tự
const MIN_WIDTH = 100  # Chiều rộng tối thiểu
const MAX_WIDTH = 200  # Chiều rộng tối đa
const MIN_HEIGHT = 50  # Chiều cao tối thiểu
const PADDING = 10  # Khoảng cách giữa text và viền

func _ready():
	hide()

func _process(delta):
	if visible:
		timer += delta
		if timer >= duration:
			hide()
			timer = 0.0

func show_message(message: String):
	# Giới hạn độ dài tin nhắn
	if message.length() > MAX_CHARS:
		message = message.substr(0, MAX_CHARS) + "..."
	
	label.text = message
	
	# Đợi một frame để label cập nhật kích thước
	await get_tree().process_frame
	
	# Tính toán kích thước mới dựa trên nội dung với giới hạn chiều rộng
	var font = label.get_theme_font("font")
	var font_size = label.get_theme_font_size("font_size")
	
	# Tính toán chiều rộng cần thiết
	var text_size = font.get_string_size(
		message,
		HORIZONTAL_ALIGNMENT_LEFT,
		MAX_WIDTH - PADDING * 2,
		font_size
	)
	
	# Tính số dòng dựa trên chiều rộng tối đa
	var line_height = font.get_height(font_size)
	var lines = ceil(text_size.x / (MAX_WIDTH - PADDING * 2))
	var required_height = max(MIN_HEIGHT, line_height * lines + PADDING * 2)
	
	# Cập nhật kích thước control và vị trí
	var required_width = clamp(text_size.x + PADDING * 2, MIN_WIDTH, MAX_WIDTH)
	custom_minimum_size = Vector2(required_width, required_height)
	size = custom_minimum_size
	position = Vector2(-required_width / 2, -required_height - 30)  # Điều chỉnh vị trí theo chiều cao
	
	# Hiển thị bubble
	show()
	timer = 0.0 
