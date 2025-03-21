package com.copecute.server.mgo;

import io.netty.channel.Channel;

// lớp chứa thông tin người chơi
public class Player {
    private String username;
    private float x;
    private float y;
    private Channel channel;
    
    public Player(String username, Channel channel) {
        this.username = username;
        this.channel = channel;
        this.x = 0;
        this.y = 0;
    }
    
    public String getUsername() {
        return username;
    }
    
    public float getX() {
        return x;
    }
    
    public float getY() {
        return y;
    }
    
    public void setPosition(float x, float y) {
        this.x = x;
        this.y = y;
    }
    
    public Channel getChannel() {
        return channel;
    }
} 