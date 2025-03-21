package com.copecute.server.mgo;

import com.google.gson.Gson;

// lớp để xử lý tin nhắn giữa client và server
public class Message {
    private String type;
    private String data;
    
    public Message(String type, String data) {
        this.type = type;
        this.data = data;
    }
    
    public String getType() {
        return type;
    }
    
    public String getData() {
        return data;
    }
    
    // chuyển đổi message thành json string
    public String toJson() {
        return new Gson().toJson(this);
    }
    
    // chuyển đổi json string thành message object
    public static Message fromJson(String json) {
        return new Gson().fromJson(json, Message.class);
    }
} 