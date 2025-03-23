package com.copecute.server.mgo;

import com.copecute.server.database.UserDAO;
import io.netty.channel.*;
import io.netty.handler.codec.http.websocketx.*;

public class WebSocketHandler extends SimpleChannelInboundHandler<WebSocketFrame> {
    private String username;
    private String currentMapInstance = null;
    private final GameWorld gameWorld = GameWorld.getInstance();

    @Override
    protected void channelRead0(ChannelHandlerContext ctx, WebSocketFrame frame) {
        if (frame instanceof TextWebSocketFrame) {
            String json = ((TextWebSocketFrame) frame).text();
            Message message = Message.fromJson(json);
            
            switch (message.getType()) {
                case "login":
                    handleLogin(ctx, message.getData());
                    break;
                case "register":
                    handleRegister(ctx, message.getData());
                    break;
                case "move":
                    handleMove(message.getData());
                    break;
                case "chat":
                    handleChat(message.getData());
                    break;
                case "select_map":
                    handleSelectMap(ctx.channel(), message.getData());
                    break;
                case "change_instance":
                    handleChangeInstance(ctx.channel(), message.getData());
                    break;
                case "get_instances":
                    handleGetInstances(ctx.channel(), message.getData());
                    break;
                case "ping":
                    handlePing(ctx.channel());
                    break;
                case "pong":
                    // Nhận phản hồi pong, không cần xử lý gì
                    break;
                default:
                    System.out.println("Không xử lý được tin nhắn: " + message.getType());
            }
        } else if (frame instanceof CloseWebSocketFrame) {
            handleLogout();
            ctx.close();
        }
    }

    private void handleLogin(ChannelHandlerContext ctx, String data) {
        String[] parts = data.split(",");
        String username = parts[0];
        String password = parts[1];
        
        if (UserDAO.authenticate(username, password)) {
            if (!gameWorld.hasPlayerInAnyMap(username)) {
                this.username = username;
                
                // Không thêm vào thế giới game ngay - sẽ thêm khi chọn map
                sendLoginResponse(ctx, true, "Đăng nhập thành công");
            } else {
                sendLoginResponse(ctx, false, "Tài khoản đã đăng nhập ở nơi khác");
            }
        } else {
            sendLoginResponse(ctx, false, "Sai tên đăng nhập hoặc mật khẩu");
        }
    }
    
    private void handleSelectMap(Channel channel, String mapId) {
        if (username == null) {
            // Chưa đăng nhập, không thể chọn map
            return;
        }
        
        // Tìm khu có chỗ trống
        String mapInstanceKey = gameWorld.findAvailableInstance(mapId);
        String oldMapInstanceKey = currentMapInstance;
        currentMapInstance = mapInstanceKey;
        
        // Di chuyển người chơi đến khu mới
        gameWorld.movePlayerToMapInstance(username, oldMapInstanceKey, currentMapInstance, channel);
        
        // Gửi xác nhận đã chọn map
        channel.writeAndFlush(new TextWebSocketFrame(
            new Message("map_selected", mapId).toJson()));
    }
    
    private void handleChangeInstance(Channel channel, String data) {
        if (username == null || currentMapInstance == null) {
            // Chưa đăng nhập hoặc chưa vào map
            return;
        }
        
        // Format: mapId,instanceId
        String[] parts = data.split(",");
        if (parts.length != 2) {
            return;
        }
        
        String mapId = parts[0];
        int instanceId = Integer.parseInt(parts[1]);
        
        // Tạo key cho khu mới
        String newMapInstanceKey = mapId + ":" + instanceId;
        
        // Kiểm tra xem khu mới có đủ chỗ không
        int playerCount = gameWorld.getInstancePlayerCount(newMapInstanceKey);
        if (playerCount >= 25) {
            // Khu đã đầy, gửi thông báo lỗi
            channel.writeAndFlush(new TextWebSocketFrame(
                new Message("change_instance_failed", "Khu đã đầy").toJson()));
            return;
        }
        
        // Di chuyển người chơi đến khu mới
        String oldMapInstanceKey = currentMapInstance;
        currentMapInstance = newMapInstanceKey;
        gameWorld.movePlayerToMapInstance(username, oldMapInstanceKey, currentMapInstance, channel);
        
        // Gửi xác nhận đã chuyển khu
        channel.writeAndFlush(new TextWebSocketFrame(
            new Message("instance_changed", String.valueOf(instanceId)).toJson()));
    }
    
    private void handleGetInstances(Channel channel, String mapId) {
        if (username == null) {
            // Chưa đăng nhập, không thể lấy thông tin khu
            return;
        }
        
        // Gửi thông tin về các khu của map
        gameWorld.sendMapInstancesInfo(mapId, channel);
        
        // Gửi thông tin về khu hiện tại
        if (currentMapInstance != null) {
            String[] parts = currentMapInstance.split(":");
            if (parts.length == 2) {
                int instanceId = Integer.parseInt(parts[1]);
                channel.writeAndFlush(new TextWebSocketFrame(
                    new Message("current_instance", String.valueOf(instanceId)).toJson()
                ));
            }
        }
    }
    
    private void handlePing(Channel channel) {
        // Gửi phản hồi pong
        channel.writeAndFlush(new TextWebSocketFrame(
            new Message("pong", "keepalive").toJson()));
    }
    
    private void sendLoginResponse(ChannelHandlerContext ctx, boolean success, String message) {
        Message response = new Message(
            success ? "login_success" : "login_failed",
            message
        );
        ctx.channel().writeAndFlush(new TextWebSocketFrame(response.toJson()));
    }
    
    private void handleRegister(ChannelHandlerContext ctx, String data) {
        String[] parts = data.split(",");
        String username = parts[0];
        String password = parts[1];
        
        if (UserDAO.register(username, password)) {
            ctx.channel().writeAndFlush(new TextWebSocketFrame(
                new Message("register_success", "Đăng ký thành công").toJson()));
        } else {
            ctx.channel().writeAndFlush(new TextWebSocketFrame(
                new Message("register_failed", "Tên đăng nhập đã tồn tại").toJson()));
        }
    }
    
    private void handleMove(String data) {
        if (username != null && currentMapInstance != null) {
            String[] parts = data.split(",");
            float x = Float.parseFloat(parts[0]);
            float y = Float.parseFloat(parts[1]);
            gameWorld.updatePlayerPosition(currentMapInstance, username, x, y);
        }
    }
    
    private void handleChat(String data) {
        if (username != null && currentMapInstance != null) {
            // Broadcast chat message đến tất cả người chơi trong khu
            Message chatMsg = new Message("chat", data);
            gameWorld.broadcastToMap(currentMapInstance, chatMsg);
        }
    }
    
    private void handleLogout() {
        if (username != null) {
            if (currentMapInstance != null) {
                gameWorld.removePlayer(currentMapInstance, username);
            } else {
                gameWorld.removePlayerFromAllMaps(username);
            }
            username = null;
            currentMapInstance = null;
        }
    }

    @Override
    public void handlerAdded(ChannelHandlerContext ctx) {
        System.out.println("Client connected: " + ctx.channel().remoteAddress());
    }

    @Override
    public void handlerRemoved(ChannelHandlerContext ctx) {
        handleLogout();
        System.out.println("Client disconnected: " + ctx.channel().remoteAddress());
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
        cause.printStackTrace();
        handleLogout();
        ctx.close();
    }
}
