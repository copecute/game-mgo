package com.copecute.server.mgo;

import io.netty.channel.Channel;
import io.netty.handler.codec.http.websocketx.TextWebSocketFrame;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Set;
import java.util.Collection;
import java.util.Map;
import java.util.ArrayList;
import java.util.List;

// lớp quản lý tất cả người chơi trong game
public class GameWorld {
    private static final GameWorld instance = new GameWorld();
    // map từ tên map và khu đến danh sách người chơi
    // format: "mapId:instanceId" -> players
    private final ConcurrentHashMap<String, ConcurrentHashMap<String, Player>> worldPlayers = new ConcurrentHashMap<>();
    
    // Số lượng người chơi tối đa trong một khu
    private static final int MAX_PLAYERS_PER_INSTANCE = 25;
    // Số lượng khu tối đa cho mỗi map
    private static final int MAX_INSTANCES_PER_MAP = 20;
    
    // Danh sách các map có sẵn
    private final List<String> availableMaps = new ArrayList<>();
    
    private GameWorld() {
        // khởi tạo các map mặc định
        availableMaps.add("res://Map/TileMap/map_1.tscn");
        availableMaps.add("res://Map/TileMap/map_2.tscn");
        
        // khởi tạo 20 khu cho mỗi map
        for (String mapId : availableMaps) {
            for (int i = 1; i <= MAX_INSTANCES_PER_MAP; i++) {
                createInstance(mapId, i);
            }
        }
    }
    
    // Tạo một khu mới cho map
    private void createInstance(String mapId, int instanceId) {
        String mapInstanceKey = getMapInstanceKey(mapId, instanceId);
        worldPlayers.put(mapInstanceKey, new ConcurrentHashMap<>());
        System.out.println("Đã tạo khu " + instanceId + " cho map " + mapId);
    }
    
    // Tạo key cho map và khu
    private String getMapInstanceKey(String mapId, int instanceId) {
        return mapId + ":" + instanceId;
    }
    
    // Phân tách key thành mapId và instanceId
    private String[] parseMapInstanceKey(String key) {
        return key.split(":");
    }
    
    public static GameWorld getInstance() {
        return instance;
    }
    
    // Thêm người chơi vào map
    public void addPlayer(String mapInstanceKey, String username, Channel channel) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapInstanceKey);
        if (mapPlayers == null) {
            // Nếu map không tồn tại, tạo mới
            String[] parts = parseMapInstanceKey(mapInstanceKey);
            if (parts.length == 2) {
                String mapId = parts[0];
                int instanceId = Integer.parseInt(parts[1]);
                createInstance(mapId, instanceId);
                mapPlayers = worldPlayers.get(mapInstanceKey);
            }
        }
        
        if (mapPlayers != null) {
            Player player = new Player(username, channel);
            mapPlayers.put(username, player);
            
            // Thông báo cho tất cả người chơi trong map về người chơi mới
            broadcastToMap(mapInstanceKey, new Message("player_joined", username));
            
            // Gửi thông tin về khu hiện tại cho người chơi
            String[] parts = parseMapInstanceKey(mapInstanceKey);
            if (parts.length == 2) {
                int instanceId = Integer.parseInt(parts[1]);
                channel.writeAndFlush(new TextWebSocketFrame(
                    new Message("current_instance", String.valueOf(instanceId)).toJson()
                ));
            }
            
            // Gửi thông tin về tất cả người chơi trong map cho người chơi mới
            sendAllPlayersInMapTo(mapInstanceKey, channel);
        }
    }
    
    // Tìm khu có chỗ trống cho map
    public String findAvailableInstance(String mapId) {
        // Tìm khu có ít người chơi nhất
        int minPlayers = Integer.MAX_VALUE;
        int selectedInstance = 1;
        
        for (int i = 1; i <= MAX_INSTANCES_PER_MAP; i++) {
            String mapInstanceKey = getMapInstanceKey(mapId, i);
            ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapInstanceKey);
            
            if (mapPlayers != null) {
                int playerCount = mapPlayers.size();
                if (playerCount < minPlayers) {
                    minPlayers = playerCount;
                    selectedInstance = i;
                    
                    // Nếu tìm thấy khu trống, dùng luôn
                    if (playerCount == 0) {
                        break;
                    }
                }
            } else {
                // Nếu khu chưa được tạo, tạo mới và dùng luôn
                createInstance(mapId, i);
                selectedInstance = i;
                break;
            }
        }
        
        return getMapInstanceKey(mapId, selectedInstance);
    }
    
    // Di chuyển người chơi từ map cũ sang map mới
    public void movePlayerToMapInstance(String username, String oldMapInstanceKey, String newMapInstanceKey, Channel channel) {
        // Xóa người chơi khỏi map cũ
        if (oldMapInstanceKey != null) {
            removePlayer(oldMapInstanceKey, username);
        } else {
            // Nếu không có map cũ, xóa khỏi tất cả map
            removePlayerFromAllMaps(username);
        }
        
        // Thêm người chơi vào map mới
        addPlayer(newMapInstanceKey, username, channel);
    }
    
    // Xóa người chơi khỏi map
    public void removePlayer(String mapInstanceKey, String username) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapInstanceKey);
        if (mapPlayers != null) {
            mapPlayers.remove(username);
            
            // Thông báo cho tất cả người chơi trong map về người chơi đã rời đi
            broadcastToMap(mapInstanceKey, new Message("player_left", username));
        }
    }
    
    // Xóa người chơi khỏi tất cả map
    public void removePlayerFromAllMaps(String username) {
        for (Map.Entry<String, ConcurrentHashMap<String, Player>> entry : worldPlayers.entrySet()) {
            String mapInstanceKey = entry.getKey();
            ConcurrentHashMap<String, Player> mapPlayers = entry.getValue();
            
            if (mapPlayers.containsKey(username)) {
                mapPlayers.remove(username);
                
                // Thông báo cho tất cả người chơi trong map về người chơi đã rời đi
                broadcastToMap(mapInstanceKey, new Message("player_left", username));
            }
        }
    }
    
    // Cập nhật vị trí người chơi
    public void updatePlayerPosition(String mapInstanceKey, String username, float x, float y) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapInstanceKey);
        if (mapPlayers != null) {
            Player player = mapPlayers.get(username);
            if (player != null) {
                player.setPosition(x, y);
                
                // Thông báo cho tất cả người chơi trong map về vị trí mới
                String posData = username + "," + x + "," + y;
                broadcastToMap(mapInstanceKey, new Message("player_moved", posData), username);
            }
        }
    }
    
    // Gửi tin nhắn đến tất cả người chơi trong map
    public void broadcastToMap(String mapInstanceKey, Message message) {
        broadcastToMap(mapInstanceKey, message, null);
    }
    
    // Gửi tin nhắn đến tất cả người chơi trong map, trừ người gửi
    public void broadcastToMap(String mapInstanceKey, Message message, String excludeUsername) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapInstanceKey);
        if (mapPlayers != null) {
            for (Player player : mapPlayers.values()) {
                if (excludeUsername == null || !player.getUsername().equals(excludeUsername)) {
                    player.getChannel().writeAndFlush(new TextWebSocketFrame(message.toJson()));
                }
            }
        }
    }
    
    // Lấy danh sách các khu của map
    public List<Integer> getMapInstances(String mapId) {
        List<Integer> instances = new ArrayList<>();
        
        for (int i = 1; i <= MAX_INSTANCES_PER_MAP; i++) {
            String mapInstanceKey = getMapInstanceKey(mapId, i);
            if (worldPlayers.containsKey(mapInstanceKey)) {
                instances.add(i);
            }
        }
        
        return instances;
    }
    
    // Lấy số lượng người chơi trong khu
    public int getInstancePlayerCount(String mapInstanceKey) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapInstanceKey);
        return mapPlayers != null ? mapPlayers.size() : 0;
    }
    
    // thêm phương thức lấy vị trí người chơi trong khu
    public String getPlayerPosition(String mapInstanceKey, String username) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapInstanceKey);
        if (mapPlayers != null) {
            Player player = mapPlayers.get(username);
            if (player != null) {
                return username + "," + player.getX() + "," + player.getY();
            }
        }
        return null;
    }
    
    // thêm phương thức lấy tất cả người chơi và vị trí trong khu
    public void sendAllPlayersInMapTo(String mapInstanceKey, Channel channel) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapInstanceKey);
        if (mapPlayers != null) {
            for (Player player : mapPlayers.values()) {
                String posData = player.getUsername() + "," + player.getX() + "," + player.getY();
                channel.writeAndFlush(new TextWebSocketFrame(
                    new Message("player_position", posData).toJson()
                ));
            }
        }
    }
    
    public Collection<Player> getPlayersInMap(String mapInstanceKey) {
        ConcurrentHashMap<String, Player> mapPlayers = worldPlayers.get(mapInstanceKey);
        return mapPlayers != null ? mapPlayers.values() : Set.of();
    }
    
    // Gửi thông tin về các khu của map cho người chơi
    public void sendMapInstancesInfo(String mapId, Channel channel) {
        StringBuilder instancesInfo = new StringBuilder();
        
        for (int i = 1; i <= MAX_INSTANCES_PER_MAP; i++) {
            String mapInstanceKey = getMapInstanceKey(mapId, i);
            int playerCount = getInstancePlayerCount(mapInstanceKey);
            
            // Format: instanceId,playerCount;instanceId,playerCount;...
            if (instancesInfo.length() > 0) {
                instancesInfo.append(";");
            }
            instancesInfo.append(i).append(",").append(playerCount);
        }
        
        channel.writeAndFlush(new TextWebSocketFrame(
            new Message("map_instances", instancesInfo.toString()).toJson()
        ));
    }
    
    // Kiểm tra xem người chơi có trong bất kỳ map nào không
    public boolean hasPlayerInAnyMap(String username) {
        for (ConcurrentHashMap<String, Player> mapPlayers : worldPlayers.values()) {
            if (mapPlayers.containsKey(username)) {
                return true;
            }
        }
        return false;
    }
} 