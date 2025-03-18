package com.copecute.mgo.client.player;

import java.awt.Point;
import java.util.ArrayList;
import java.util.List;

// lưu thông tin người chơi
public class PlayerInfo {
    private static final int TILE_SIZE = 32;
    
    public Point position; // vị trí theo ô (tile)
    public Point pixelPosition; // vị trí theo pixel
    public List<Point> path; // đường đi tới đích
    public boolean isMoving; // trạng thái di chuyển
    public int frameIndex; // frame hiện tại của animation
    public long lastFrameTime; // thời điểm frame cuối
    public boolean facingRight; // hướng nhân vật (true: phải, false: trái)
    public String chatMessage; // nội dung chat
    public long chatTime; // thời điểm chat
    public Point targetPosition; // điểm đích để di chuyển mượt
    
    public PlayerInfo(Point position) {
        this.position = position;
        this.pixelPosition = new Point(position.x * TILE_SIZE, position.y * TILE_SIZE);
        this.path = new ArrayList<>();
        this.isMoving = false;
        this.frameIndex = 0;
        this.lastFrameTime = System.currentTimeMillis();
        this.facingRight = true;
        this.chatMessage = null;
        this.chatTime = 0;
        this.targetPosition = new Point(position);
    }
} 