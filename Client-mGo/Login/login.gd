extends Control

@onready var username_input = $CenterContainer/VBoxContainer/FormContainer/UsernameContainer/UsernameField
@onready var password_input = $CenterContainer/VBoxContainer/FormContainer/PasswordContainer/PasswordField
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var btn_login = $CenterContainer/VBoxContainer/ButtonsContainer/btnLogin
@onready var btn_register = $CenterContainer/VBoxContainer/ButtonsContainer/btnRegister

func _ready():
	Network.server_message_received.connect(_on_server_message_received)
	if btn_login:
		btn_login.pressed.connect(_on_LoginButton_pressed)

func _on_LoginButton_pressed():
	if username_input.text.is_empty() or password_input.text.is_empty():
		status_label.text = "Vui lòng điền đầy đủ thông tin"
		return
		
	var login_data = {
		"type": "login",
		"data": username_input.text + "," + password_input.text
	}
	Network.send_message(login_data)

func _on_server_message_received(message):
	var data = JSON.parse_string(message)
	if data and data.has("type"):
		match data["type"]:
			"login_success":
				print("Login success, setting username: ", username_input.text)
				Network.current_username = username_input.text
				get_tree().change_scene_to_file("res://Map/Map.tscn")
			"login_failed":
				status_label.text = data["data"]

func _on_btn_register_pressed() -> void:
	get_tree().change_scene_to_file("res://Login/Register.tscn")
