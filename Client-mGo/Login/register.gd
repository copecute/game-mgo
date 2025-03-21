extends Control

@onready var username_input = $CenterContainer/VBoxContainer/FormContainer/UsernameContainer/UsernameField
@onready var password_input = $CenterContainer/VBoxContainer/FormContainer/PasswordContainer/PasswordField
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var btn_register = $CenterContainer/VBoxContainer/ButtonsContainer/btnRegister
@onready var btn_back = $CenterContainer/VBoxContainer/ButtonsContainer/btnBack

func _ready():
	Network.server_message_received.connect(_on_server_message_received)

func _on_RegisterButton_pressed():
	if username_input.text.is_empty() or password_input.text.is_empty():
		status_label.text = "Vui lòng điền đầy đủ thông tin"
		return
		
	var register_data = {
		"type": "register",
		"data": username_input.text + "," + password_input.text
	}
	Network.send_message(register_data)

func _on_server_message_received(message):
	var data = JSON.parse_string(message)
	if data and data.has("type"):
		match data["type"]:
			"register_success":
				status_label.text = data["data"]
				await get_tree().create_timer(1.0).timeout
				get_tree().change_scene_to_file("res://Login/Login.tscn")
			"register_failed":
				status_label.text = data["data"]

func _on_btn_back_pressed():
	get_tree().change_scene_to_file("res://Login/Login.tscn")
