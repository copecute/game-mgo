package com.copecute.mgo.client.renderer;

import com.copecute.mgo.client.player.PlayerInfo;
import java.awt.*;
import java.awt.image.BufferedImage;
import javax.swing.JPanel;
import java.util.Map;

// xử lý render game
public class GameRenderer {
    private static final int TILE_SIZE = 32;
    private static final int SPRITE_WIDTH = 32;
    private static final int SPRITE_HEIGHT = 32;
    private static final int CHAT_DISPLAY_TIME = 5000;
    
    private final BufferedImage mapBuffer;
    private final BufferedImage playerSprite;
    private final JPanel panel;
    
    public GameRenderer(BufferedImage mapBuffer, BufferedImage playerSprite, JPanel panel) {
        this.mapBuffer = mapBuffer;
        this.playerSprite = playerSprite;
        this.panel = panel;
    }
    
    public void render(Graphics g, Map<String, PlayerInfo> players, String currentPlayer, 
                      Point cameraPosition, int viewportWidth, int viewportHeight) {
        
        // vẽ map
        g.drawImage(mapBuffer, -cameraPosition.x, -cameraPosition.y, 
                   mapBuffer.getWidth(), mapBuffer.getHeight(), panel);
                   
        // vẽ người chơi và chat
        for (Map.Entry<String, PlayerInfo> entry : players.entrySet()) {
            String username = entry.getKey();
            PlayerInfo player = entry.getValue();
            
            int x = player.pixelPosition.x - cameraPosition.x;
            int y = player.pixelPosition.y - cameraPosition.y;
            
            // chỉ vẽ trong viewport
            if (isInViewport(x, y, viewportWidth, viewportHeight)) {
                renderPlayer(g, player, x, y, username);
                renderChat(g, player, x, y);
            }
        }
    }

    private boolean isInViewport(int x, int y, int viewportWidth, int viewportHeight) {
        return x >= -TILE_SIZE && x <= viewportWidth * TILE_SIZE &&
               y >= -TILE_SIZE && y <= viewportHeight * TILE_SIZE;
    }

    private void renderPlayer(Graphics g, PlayerInfo player, int x, int y, String username) {
        // vẽ sprite
        int spriteX = player.frameIndex * SPRITE_WIDTH;
        int spriteY = player.isMoving ? 0 : SPRITE_HEIGHT;
        
        if (player.facingRight) {
            g.drawImage(playerSprite, x, y, x + SPRITE_WIDTH, y + SPRITE_HEIGHT,
                       spriteX, spriteY, spriteX + SPRITE_WIDTH, spriteY + SPRITE_HEIGHT, panel);
        } else {
            g.drawImage(playerSprite, x + SPRITE_WIDTH, y, x, y + SPRITE_HEIGHT,
                       spriteX, spriteY, spriteX + SPRITE_WIDTH, spriteY + SPRITE_HEIGHT, panel);
        }
        
        // vẽ tên
        renderPlayerName(g, username, x, y);
    }

    private void renderPlayerName(Graphics g, String username, int x, int y) {
        FontMetrics fm = g.getFontMetrics();
        int nameWidth = fm.stringWidth(username);
        int nameX = x + (SPRITE_WIDTH - nameWidth) / 2;
        
        g.setColor(new Color(0, 0, 0, 180));
        g.fillRoundRect(nameX - 2, y - 20, nameWidth + 4, 15, 5, 5);
        
        g.setColor(Color.WHITE);
        g.drawString(username, nameX, y - 8);
    }

    private void renderChat(Graphics g, PlayerInfo player, int x, int y) {
        if (player.chatMessage != null) {
            long currentTime = System.currentTimeMillis();
            if (currentTime - player.chatTime < CHAT_DISPLAY_TIME) {
                FontMetrics fm = g.getFontMetrics();
                int messageWidth = fm.stringWidth(player.chatMessage);
                int messageX = x + (SPRITE_WIDTH - messageWidth) / 2;
                
                g.setColor(new Color(0, 0, 0, 180));
                g.fillRoundRect(messageX - 5, y - 45, messageWidth + 10, 20, 10, 10);
                g.setColor(new Color(255, 255, 255, 100));
                g.drawRoundRect(messageX - 5, y - 45, messageWidth + 10, 20, 10, 10);
                
                g.setColor(Color.WHITE);
                g.drawString(player.chatMessage, messageX, y - 30);
            } else {
                player.chatMessage = null;
            }
        }
    }
} 