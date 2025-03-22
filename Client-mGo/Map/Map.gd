func _on_server_message_received(message):
	var data = JSON.parse_string(message)
	if data and data.has("type"):
		match data["type"]:
			"player_list":
				# xử lý danh sách người chơi
				pass
			"player_move":
				# xử lý di chuyển người chơi
				pass
			"ping":
				# Nhận ping từ server, trả lại pong
				var pong_data = {
					"type": "pong",
					"data": "keepalive"
				}
				Network.send_message(pong_data)
			"pong":
				# Nhận pong từ server, không cần làm gì
				pass
			_:
				# Xử lý các loại tin nhắn khác
				pass 