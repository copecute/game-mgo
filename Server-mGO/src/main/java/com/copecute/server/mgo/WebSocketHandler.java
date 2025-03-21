package com.copecute.server.mgo;

import com.copecute.server.database.UserDAO;
import io.netty.channel.*;
import io.netty.handler.codec.http.websocketx.*;

public class WebSocketHandler extends SimpleChannelInboundHandler<WebSocketFrame> {
    private String username;
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
            if (!gameWorld.hasPlayer(username)) {
                this.username = username;
                
                // 1. Thêm người chơi mới vào game
                Player newPlayer = new Player(username, ctx.channel());
                gameWorld.addPlayerSilently(username, newPlayer);
                
                // 2. Gửi thông tin tất cả người chơi hiện có cho người mới
                for (Player existingPlayer : gameWorld.getPlayers()) {
                    if (!existingPlayer.getUsername().equals(username)) {
                        // Gửi thông tin join trước
                        ctx.channel().writeAndFlush(new TextWebSocketFrame(
                            new Message("player_joined", existingPlayer.getUsername()).toJson()
                        ));
                        
                        // Sau đó gửi vị trí
                        String posData = existingPlayer.getUsername() + "," + 
                                       existingPlayer.getX() + "," + 
                                       existingPlayer.getY();
                        ctx.channel().writeAndFlush(new TextWebSocketFrame(
                            new Message("player_position", posData).toJson()
                        ));
                        
                        System.out.println("Sent existing player to new player: " + existingPlayer.getUsername()); // Debug log
                    }
                }
                
                // 3. Broadcast thông tin người chơi mới cho những người khác
                String newPlayerPos = username + "," + newPlayer.getX() + "," + newPlayer.getY();
                Message joinMsg = new Message("player_joined", username);
                Message posMsg = new Message("player_position", newPlayerPos);
                
                for (Player player : gameWorld.getPlayers()) {
                    if (!player.getUsername().equals(username)) {
                        Channel playerChannel = player.getChannel();
                        playerChannel.writeAndFlush(new TextWebSocketFrame(joinMsg.toJson()));
                        playerChannel.writeAndFlush(new TextWebSocketFrame(posMsg.toJson()));
                    }
                }
                
                // 4. Cuối cùng mới gửi thông báo đăng nhập thành công
                sendLoginResponse(ctx, true, "Đăng nhập thành công");
                
            } else {
                sendLoginResponse(ctx, false, "Tài khoản đã đăng nhập ở nơi khác");
            }
        } else {
            sendLoginResponse(ctx, false, "Sai tên đăng nhập hoặc mật khẩu");
        }
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
        if (username != null) {
            String[] parts = data.split(",");
            float x = Float.parseFloat(parts[0]);
            float y = Float.parseFloat(parts[1]);
            gameWorld.updatePlayerPosition(username, x, y);
        }
    }
    
    private void handleChat(String data) {
        if (username != null) {
            // Broadcast chat message to all players
            Message chatMsg = new Message("chat", data);
            gameWorld.broadcast(chatMsg);
        }
    }
    
    private void handleLogout() {
        if (username != null) {
            gameWorld.removePlayer(username);
            username = null;
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
