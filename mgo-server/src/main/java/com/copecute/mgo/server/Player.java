package com.copecute.mgo.server;

// lưu thông tin người chơi
public class Player {
    private String username;
    private int hp;
    private int mp;
    private int level;
    private int exp;
    private int x;
    private int y;
    private String map;

    public Player(String username) {
        this.username = username;
        this.hp = 100;
        this.mp = 100;
        this.level = 1;
        this.exp = 0;
        this.x = 0;
        this.y = 0;
        this.map = "start";
    }

    public String getUsername() {
        return username;
    }

    public int getHp() {
        return hp;
    }

    public void setHp(int hp) {
        this.hp = hp;
    }

    public int getMp() {
        return mp;
    }

    public void setMp(int mp) {
        this.mp = mp;
    }

    public int getLevel() {
        return level;
    }

    public void setLevel(int level) {
        this.level = level;
    }

    public int getExp() {
        return exp;
    }

    public void setExp(int exp) {
        this.exp = exp;
    }

    public int getX() {
        return x;
    }

    public void setX(int x) {
        this.x = x;
    }

    public int getY() {
        return y;
    }

    public void setY(int y) {
        this.y = y;
    }

    public String getMap() {
        return map;
    }

    public void setMap(String map) {
        this.map = map;
    }
}