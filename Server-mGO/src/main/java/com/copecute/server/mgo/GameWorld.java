package com.copecute.server.mgo;

import io.netty.channel.Channel;
import io.netty.handler.codec.http.websocketx.TextWebSocketFrame;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Set;
import java.util.Collection;
import java.util.Map;

// lớp quản lý tất cả người chơi trong game
public class GameWorld {
    private static final GameWorld instance = new GameWorld();
    // map từ tên map đến danh sách người chơi trong map đó
    private final ConcurrentHashMap<String, ConcurrentHashMap<String, Player>> worldPlayers = new ConcurrentHashMap<>();
    
    private GameWorld() {
        // khởi tạo các map mặc định
        worldPlayers.put("res://Map/TileMap/map_1.tscn", new ConcurrentHashMap<>());
        worldPlayers.put("res://Map/TileMap/map_2.tscn", new ConcurrentHashMap<>());
    }
    
    public static GameWorld getInstance() {
        return instance;
    }
    
    // thêm người chơi mới mà không broadcast ngay
    public void addPlayerSilently(String mapId, String username, Player player) {
        // đảm bảo map tồn tại
        worldPlayers.putIfAbsent(mapId, new ConcurrentHashMap<>());
        worldPlayers.get(mapId).put(username, player);
    }
    
    // broadcast thông tin người chơi mới chỉ trong map cụ thể
    public void broadcastNewPlayer(String mapId, String username) {
        // thông báo cho tất cả người chơi trong map về người chơi mới
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapId);
        if (mapPlayers != null) {
            Player newPlayer = mapPlayers.get(username);
            if (newPlayer != null) {
                String posData = username + "," + newPlayer.getX() + "," + newPlayer.getY();
                Message joinMsg = new Message("player_joined", username);
                Message posMsg = new Message("player_position", posData);
                
                // Gửi cả thông tin join và position
                for (Player player : mapPlayers.values()) {
                    if (!player.getUsername().equals(username)) {
                        Channel channel = player.getChannel();
                        channel.writeAndFlush(new TextWebSocketFrame(joinMsg.toJson()));
                        channel.writeAndFlush(new TextWebSocketFrame(posMsg.toJson()));
                    }
                }
            }
        }
    }
    
    // Thay thế phương thức addPlayer cũ
    public void addPlayer(String mapId, String username, Channel channel) {
        Player newPlayer = new Player(username, channel);
        
        // đảm bảo map tồn tại
        worldPlayers.putIfAbsent(mapId, new ConcurrentHashMap<>());
        
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapId);
        mapPlayers.put(username, newPlayer);
        
        // 1. Gửi thông tin tất cả người chơi hiện có trong map cho người chơi mới
        for (Player existingPlayer : mapPlayers.values()) {
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
        
        // 2. Gửi thông tin người chơi mới cho tất cả người chơi khác trong map
        String newPlayerPos = username + "," + newPlayer.getX() + "," + newPlayer.getY();
        Message joinMsg = new Message("player_joined", username);
        Message posMsg = new Message("player_position", newPlayerPos);
        
        for (Player player : mapPlayers.values()) {
            if (!player.getUsername().equals(username)) {
                Channel playerChannel = player.getChannel();
                playerChannel.writeAndFlush(new TextWebSocketFrame(joinMsg.toJson()));
                playerChannel.writeAndFlush(new TextWebSocketFrame(posMsg.toJson()));
            }
        }
    }
    
    // xóa người chơi khỏi map cụ thể
    public void removePlayer(String mapId, String username) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapId);
        if (mapPlayers != null) {
            mapPlayers.remove(username);
            
            // thông báo cho tất cả người chơi trong map về người chơi đã rời đi
            broadcastMessageToMap(mapId, "player_left", username);
        }
    }
    
    // xóa người chơi khỏi tất cả map
    public void removePlayerFromAllMaps(String username) {
        for (Map.Entry<String, ConcurrentHashMap<String, Player>> entry : worldPlayers.entrySet()) {
            String mapId = entry.getKey();
            ConcurrentHashMap<String, Player> players = entry.getValue();
            
            if (players.remove(username) != null) {
                // thông báo cho tất cả người chơi trong map về người chơi đã rời đi
                broadcastMessageToMap(mapId, "player_left", username);
            }
        }
    }
    
    // cập nhật vị trí người chơi trong map cụ thể
    public void updatePlayerPosition(String mapId, String username, float x, float y) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapId);
        if (mapPlayers != null) {
            Player player = mapPlayers.get(username);
            if (player != null) {
                player.setPosition(x, y);
                
                // thông báo cho tất cả người chơi trong map về vị trí mới
                Message msg = new Message("player_moved", username + "," + x + "," + y);
                broadcastToMap(mapId, msg);
            }
        }
    }
    
    // gửi tin nhắn đến tất cả người chơi trong map cụ thể
    public void broadcastToMap(String mapId, Message message) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapId);
        if (mapPlayers != null) {
            String json = message.toJson();
            mapPlayers.values().forEach(player -> 
                player.getChannel().writeAndFlush(new TextWebSocketFrame(json)));
        }
    }
    
    private void broadcastMessageToMap(String mapId, String type, String data) {
        broadcastToMap(mapId, new Message(type, data));
    }
    
    // kiểm tra người chơi có tồn tại trong map không
    public boolean hasPlayerInMap(String mapId, String username) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapId);
        return mapPlayers != null && mapPlayers.containsKey(username);
    }
    
    // kiểm tra người chơi có tồn tại trong bất kỳ map nào không
    public boolean hasPlayerInAnyMap(String username) {
        for (ConcurrentHashMap<String, Player> players : worldPlayers.values()) {
            if (players.containsKey(username)) {
                return true;
            }
        }
        return false;
    }
    
    // lấy map hiện tại của người chơi
    public String getPlayerCurrentMap(String username) {
        for (Map.Entry<String, ConcurrentHashMap<String, Player>> entry : worldPlayers.entrySet()) {
            if (entry.getValue().containsKey(username)) {
                return entry.getKey();
            }
        }
        return null;
    }
    
    // chuyển người chơi sang map khác
    public void movePlayerToMap(String username, String oldMapId, String newMapId, Channel channel) {
        // xóa khỏi map cũ
        if (oldMapId != null) {
            removePlayer(oldMapId, username);
        }
        
        // thêm vào map mới
        addPlayer(newMapId, username, channel);
    }
    
    public Set<String> getPlayerNamesInMap(String mapId) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapId);
        return mapPlayers != null ? mapPlayers.keySet() : Set.of();
    }
    
    // thêm phương thức lấy vị trí người chơi trong map
    public String getPlayerPosition(String mapId, String username) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapId);
        if (mapPlayers != null) {
            Player player = mapPlayers.get(username);
            if (player != null) {
                return username + "," + player.getX() + "," + player.getY();
            }
        }
        return null;
    }
    
    // thêm phương thức lấy tất cả người chơi và vị trí trong map
    public void sendAllPlayersInMapTo(String mapId, Channel channel) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapId);
        if (mapPlayers != null) {
            for (Player player : mapPlayers.values()) {
                String posData = player.getUsername() + "," + player.getX() + "," + player.getY();
                channel.writeAndFlush(new TextWebSocketFrame(
                    new Message("player_position", posData).toJson()
                ));
            }
        }
    }
    
    public Collection<Player> getPlayersInMap(String mapId) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapId);
        return mapPlayers != null ? mapPlayers.values() : Set.of();
    }
} 