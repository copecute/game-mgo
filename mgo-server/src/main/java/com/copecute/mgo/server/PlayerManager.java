package com.copecute.mgo.server;

import java.util.concurrent.ConcurrentHashMap;

// quản lý danh sách người chơi online
public class PlayerManager {
    private static final ConcurrentHashMap<String, Player> players = new ConcurrentHashMap<>();

    public static Player addPlayer(String username) {
        Player player = new Player(username);
        players.put(username, player);
        return player;
    }

    public static Player getPlayer(String username) {
        return players.get(username);
    }

    public static void removePlayer(String username) {
        players.remove(username);
    }

    public static int getPlayerCount() {
        return players.size();
    }

    public static ConcurrentHashMap<String, Player> getPlayers() {
        return players;
    }
}