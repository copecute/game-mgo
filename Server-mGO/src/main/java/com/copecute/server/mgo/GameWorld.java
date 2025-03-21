package com.copecute.server.mgo;

import io.netty.channel.Channel;
import io.netty.handler.codec.http.websocketx.TextWebSocketFrame;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Set;
import java.util.Collection;

// lớp quản lý tất cả người chơi trong game
public class GameWorld {
    private static final GameWorld instance = new GameWorld();
    private final ConcurrentHashMap<String, Player> players = new ConcurrentHashMap<>();
    
    private GameWorld() {}
    
    public static GameWorld getInstance() {
        return instance;
    }
    
    // thêm người chơi mới mà không broadcast ngay
    public void addPlayerSilently(String username, Player player) {
        players.put(username, player);
    }
    
    // broadcast thông tin người chơi mới
    public void broadcastNewPlayer(String username) {
        // thông báo cho tất cả người chơi về người chơi mới
        Player newPlayer = players.get(username);
        if (newPlayer != null) {
            String posData = username + "," + newPlayer.getX() + "," + newPlayer.getY();
            Message joinMsg = new Message("player_joined", username);
            Message posMsg = new Message("player_position", posData);
            
            // Gửi cả thông tin join và position
            for (Player player : players.values()) {
                if (!player.getUsername().equals(username)) {
                    Channel channel = player.getChannel();
                    channel.writeAndFlush(new TextWebSocketFrame(joinMsg.toJson()));
                    channel.writeAndFlush(new TextWebSocketFrame(posMsg.toJson()));
                }
            }
        }
    }
    
    // Thay thế phương thức addPlayer cũ
    public void addPlayer(String username, Channel channel) {
        Player newPlayer = new Player(username, channel);
        players.put(username, newPlayer);
        
        // 1. Gửi thông tin tất cả người chơi hiện có cho người chơi mới
        for (Player existingPlayer : players.values()) {
            if (!existingPlayer.getUsername().equals(username)) {
                String posData = existingPlayer.getUsername() + "," + 
                               existingPlayer.getX() + "," + 
                               existingPlayer.getY();
                
                // Gửi thông tin người chơi hiện có cho người mới
                channel.writeAndFlush(new TextWebSocketFrame(
                    new Message("player_joined", existingPlayer.getUsername()).toJson()
                ));
                channel.writeAndFlush(new TextWebSocketFrame(
                    new Message("player_position", posData).toJson()
                ));
            }
        }
        
        // 2. Gửi thông tin người chơi mới cho tất cả người chơi khác
        String newPlayerPos = username + "," + newPlayer.getX() + "," + newPlayer.getY();
        Message joinMsg = new Message("player_joined", username);
        Message posMsg = new Message("player_position", newPlayerPos);
        
        for (Player player : players.values()) {
            if (!player.getUsername().equals(username)) {
                Channel playerChannel = player.getChannel();
                playerChannel.writeAndFlush(new TextWebSocketFrame(joinMsg.toJson()));
                playerChannel.writeAndFlush(new TextWebSocketFrame(posMsg.toJson()));
            }
        }
    }
    
    // xóa người chơi
    public void removePlayer(String username) {
        players.remove(username);
        
        // thông báo cho tất cả người chơi về người chơi đã rời đi
        broadcastMessage("player_left", username);
    }
    
    // cập nhật vị trí người chơi
    public void updatePlayerPosition(String username, float x, float y) {
        Player player = players.get(username);
        if (player != null) {
            player.setPosition(x, y);
            
            // thông báo cho tất cả người chơi về vị trí mới
            Message msg = new Message("player_moved", username + "," + x + "," + y);
            broadcast(msg);
        }
    }
    
    // gửi tin nhắn đến tất cả người chơi
    public void broadcast(Message message) {
        String json = message.toJson();
        players.values().forEach(player -> 
            player.getChannel().writeAndFlush(new TextWebSocketFrame(json)));
    }
    
    private void broadcastMessage(String type, String data) {
        broadcast(new Message(type, data));
    }
    
    // kiểm tra người chơi có tồn tại không
    public boolean hasPlayer(String username) {
        return players.containsKey(username);
    }
    
    public Set<String> getPlayerNames() {
        return players.keySet();
    }
    
    // thêm phương thức lấy vị trí người chơi
    public String getPlayerPosition(String username) {
        Player player = players.get(username);
        if (player != null) {
            return username + "," + player.getX() + "," + player.getY();
        }
        return null;
    }
    
    // thêm phương thức lấy tất cả người chơi và vị trí
    public void sendAllPlayersTo(Channel channel) {
        for (Player player : players.values()) {
            String posData = player.getUsername() + "," + player.getX() + "," + player.getY();
            channel.writeAndFlush(new TextWebSocketFrame(
                new Message("player_position", posData).toJson()
            ));
        }
    }
    
    public Collection<Player> getPlayers() {
        return players.values();
    }
} 