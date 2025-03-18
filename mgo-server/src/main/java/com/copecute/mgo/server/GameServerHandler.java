package com.copecute.mgo.server;

import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundHandlerAdapter;
import io.netty.channel.group.ChannelGroup;
import io.netty.channel.group.DefaultChannelGroup;
import io.netty.util.concurrent.GlobalEventExecutor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;

// xu ly tin nhan tu client
public class GameServerHandler extends ChannelInboundHandlerAdapter {
    private static final Logger logger = LoggerFactory.getLogger(GameServerHandler.class);
    private static final ChannelGroup channels = new DefaultChannelGroup(GlobalEventExecutor.INSTANCE);
    private String username; // luu username cua nguoi dung da dang nhap
    private ChannelHandlerContext context; // luu context de gui message

    @Override
    public void channelActive(ChannelHandlerContext ctx) {
        channels.add(ctx.channel());
        this.context = ctx;
        logger.info("client ket noi: {}", ctx.channel().remoteAddress());
    }

    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) {
        String message = (String) msg;
        // Xử lý khi có ký tự \n ở cuối message
        if (message.endsWith("\n")) {
            message = message.substring(0, message.length() - 1);
        }
        
        // them username vao log de biet request tu client nao
        logger.info("nhan tu client {}: {}", username != null ? username : "chua dang nhap", message);

        String[] parts = message.split(":");
        String command = parts[0];

        switch (command) {
            case "LOGIN":
                handleLogin(ctx, parts);
                break;
            case "REGISTER":
                handleRegister(ctx, parts);
                break;
            case "MOVE":
                handleMove(ctx, parts);
                break;
            case "CHAT":
                handleChat(ctx, parts);
                break;
            default:
                ctx.writeAndFlush("ERROR:Lenh khong hop le\n");
        }
    }

    private void handleLogin(ChannelHandlerContext ctx, String[] parts) {
        if (parts.length != 3) {
            ctx.writeAndFlush("LOGIN_FAIL:Thong tin dang nhap khong hop le\n");
            return;
        }

        String username = parts[1];
        String password = parts[2];

        if (username.isEmpty() || password.isEmpty()) {
            ctx.writeAndFlush("LOGIN_FAIL:Ten dang nhap va mat khau khong duoc de trong\n");
            return;
        }

        if (DatabaseManager.checkLogin(username, password)) {
            this.username = username;
            
            // tim vi tri trong ngau nhien cho nguoi choi moi
            int x, y;
            do {
                x = (int) (Math.random() * 48) + 1; // 1-48 de tranh tuong vien
                y = (int) (Math.random() * 48) + 1;
            } while (!canMoveTo(x, y));
            
            // tao nguoi choi moi voi vi tri ngau nhien
            Player player = new Player(username);
            player.setX(x);
            player.setY(y);
            PlayerManager.getPlayers().put(username, player);
            
            logger.info("nguoi choi {} dang nhap thanh cong tai ({}, {})", username, x, y);
            
            // gui thong bao dang nhap thanh cong cho nguoi choi moi
            ctx.writeAndFlush("LOGIN_SUCCESS:" + username + "\n");
            
            // gui vi tri cua nguoi choi moi cho chinh ho
            ctx.writeAndFlush("MOVE:" + username + ":" + x + ":" + y + "\n");
            
            // thong bao cho nguoi choi moi ve cac nguoi choi khac
            PlayerManager.getPlayers().forEach((name, p) -> {
                if (!name.equals(username)) {
                    ctx.writeAndFlush("PLAYER_JOINED:" + name + "\n");
                    ctx.writeAndFlush("MOVE:" + name + ":" + p.getX() + ":" + p.getY() + "\n");
                }
            });
            
            // thong bao cho tat ca nguoi choi khac ve nguoi choi moi
            String joinMessage = "PLAYER_JOINED:" + username + "\n";
            String moveMessage = "MOVE:" + username + ":" + x + ":" + y + "\n";
            
            channels.forEach(ch -> {
                if (ch != ctx.channel()) {
                    ch.writeAndFlush(joinMessage);
                    ch.writeAndFlush(moveMessage);
                }
            });
        } else {
            logger.warn("dang nhap that bai voi username: {}", username);
            ctx.writeAndFlush("LOGIN_FAIL:Sai ten dang nhap hoac mat khau\n");
        }
    }

    private boolean canMoveTo(int x, int y) {
        // kiem tra toa do co nam trong map khong
        if (x < 0 || x >= 50 || y < 0 || y >= 50) {
            logger.debug("toa do ({}, {}) nam ngoai map", x, y);
            return false;
        }
        
        // kiem tra co phai tuong khong (tuong o vien va cac vi tri co dinh)
        if (x == 0 || y == 0 || x == 49 || y == 49) {
            logger.debug("toa do ({}, {}) la tuong vien", x, y);
            return false;
        }
        if ((x % 10 == 0 && y % 10 == 0) || (x % 15 == 0 && y % 8 == 0)) {
            logger.debug("toa do ({}, {}) la tuong co dinh", x, y);
            return false;
        }
        
        // kiem tra co nguoi choi khac khong (tru nguoi choi hien tai)
        logger.debug("kiem tra va cham voi nguoi choi khac tai ({}, {}), nguoi choi hien tai: {}", x, y, username);
        for (Map.Entry<String, Player> entry : PlayerManager.getPlayers().entrySet()) {
            String playerName = entry.getKey();
            Player player = entry.getValue();
            // chi kiem tra voi nguoi choi khac, khong kiem tra voi chinh minh
            if (!playerName.equals(username) && player.getX() == x && player.getY() == y) {
                logger.debug("toa do ({}, {}) da co nguoi choi {} (nguoi choi hien tai: {})", 
                    x, y, playerName, username);
                return false;
            }
        }
        
        return true;
    }

    private void handleRegister(ChannelHandlerContext ctx, String[] parts) {
        if (parts.length != 3) {
            ctx.writeAndFlush("REGISTER_FAIL:Thong tin dang ky khong hop le\n");
            return;
        }

        String username = parts[1];
        String password = parts[2];

        if (username.isEmpty() || password.isEmpty()) {
            ctx.writeAndFlush("REGISTER_FAIL:Ten dang ky va mat khau khong duoc de trong\n");
            return;
        }

        if (username.length() < 3 || password.length() < 6) {
            ctx.writeAndFlush("REGISTER_FAIL:Ten dang ky phai tu 3 ky tu va mat khau tu 6 ky tu\n");
            return;
        }

        if (DatabaseManager.register(username, password)) {
            logger.info("dang ky thanh cong tai khoan: {}", username);
            ctx.writeAndFlush("REGISTER_SUCCESS:Dang ky thanh cong\n");
        } else {
            logger.warn("dang ky that bai voi username: {}", username);
            ctx.writeAndFlush("REGISTER_FAIL:Ten dang ky da ton tai\n");
        }
    }

    private void handleMove(ChannelHandlerContext ctx, String[] parts) {
        if (username == null) {
            logger.warn("yeu cau di chuyen tu client chua dang nhap");
            ctx.writeAndFlush("MOVE_FAIL:Ban chua dang nhap\n");
            return;
        }

        if (parts.length != 3) {
            logger.warn("yeu cau di chuyen khong hop le tu {}: thieu toa do, parts.length={}", username, parts.length);
            ctx.writeAndFlush("MOVE_FAIL:Toa do khong hop le\n");
            return;
        }

        try {
            // In log raw input để debug
            logger.debug("Raw MOVE input x='{}', y='{}'", parts[1], parts[2]);
            
            int x = Integer.parseInt(parts[1]);
            int y = Integer.parseInt(parts[2]);
            
            // lay thong tin nguoi choi truoc
            Player player = PlayerManager.getPlayer(username);
            if (player == null) {
                logger.warn("khong tim thay thong tin nguoi choi {}", username);
                ctx.writeAndFlush("MOVE_FAIL:Khong tim thay thong tin nguoi choi\n");
                return;
            }

            // log toa do hien tai va dich
            int oldX = player.getX();
            int oldY = player.getY();
            logger.info("nguoi choi {} yeu cau di chuyen tu ({}, {}) den ({}, {})", 
                username, oldX, oldY, x, y);
            
            // kiem tra khoang cach di chuyen
            int dx = Math.abs(x - oldX);
            int dy = Math.abs(y - oldY);
            
            // Bỏ giới hạn chỉ di chuyển 1 ô, thay vào đó chỉ log cảnh báo nếu di chuyển quá xa
            // nhưng vẫn cho phép di chuyển
            if (dx > 3 || dy > 3) {
                logger.warn("nguoi choi {} yeu cau di chuyen kha xa: tu ({}, {}) den ({}, {}), dx={}, dy={}", 
                    username, oldX, oldY, x, y, dx, dy);
            }

            // Debug các người chơi hiện tại
            logger.debug("Danh sach nguoi choi truoc khi di chuyen:");
            for (Map.Entry<String, Player> entry : PlayerManager.getPlayers().entrySet()) {
                logger.debug("--- Nguoi choi {}: ({}, {})", 
                    entry.getKey(), entry.getValue().getX(), entry.getValue().getY());
            }

            // Luu vi tri cu de khoi phuc neu can
            int tempX = player.getX();
            int tempY = player.getY();
            
            // Tam thoi di chuyen nguoi choi ra khoi vi tri cu (de khong kiem tra va cham voi chinh minh)
            player.setX(-99);
            player.setY(-99);
            
            // kiem tra toa do dich co hop le khong
            boolean canMove = canMoveTo(x, y);
            if (!canMove) {
                // Khoi phuc vi tri cu
                player.setX(tempX);
                player.setY(tempY);
                logger.warn("nguoi choi {} yeu cau di chuyen den toa do khong hop le: ({}, {})", username, x, y);
                ctx.writeAndFlush("MOVE_FAIL:Toa do khong hop le\n");
                return;
            }
            
            // cap nhat vi tri moi
            player.setX(x);
            player.setY(y);
            
            // thong bao cho tat ca nguoi choi ve vi tri moi
            String moveMessage = "MOVE:" + username + ":" + x + ":" + y + "\n";
            channels.writeAndFlush(moveMessage);
            
            logger.info("nguoi choi {} di chuyen thanh cong tu ({}, {}) den ({}, {})", 
                username, oldX, oldY, x, y);
        } catch (NumberFormatException e) {
            logger.warn("toa do khong hop le tu nguoi choi {}: '{}', loi: {}", 
                username, String.join(":", parts[1], parts[2]), e.getMessage());
            ctx.writeAndFlush("MOVE_FAIL:Toa do khong hop le\n");
        }
    }

    private void handleChat(ChannelHandlerContext ctx, String[] parts) {
        if (username == null) {
            ctx.writeAndFlush("CHAT_FAIL:Ban chua dang nhap\n");
            return;
        }

        if (parts.length != 2) {
            ctx.writeAndFlush("CHAT_FAIL:Tin nhan khong hop le\n");
            return;
        }

        String message = parts[1];
        // gui tin nhan toi tat ca nguoi choi
        String chatMessage = "CHAT:" + username + ":" + message + "\n";
        channels.writeAndFlush(chatMessage);
        
        logger.info("nguoi choi {} chat: {}", username, message);
    }

    @Override
    public void channelInactive(ChannelHandlerContext ctx) {
        channels.remove(ctx.channel());
        if (username != null) {
            PlayerManager.removePlayer(username);
            // thong bao cho tat ca nguoi choi
            channels.writeAndFlush("PLAYER_LEFT:" + username + "\n");
            logger.info("nguoi choi {} da ngat ket noi", username);
        }
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
        logger.error("loi ket noi: ", cause);
        channels.remove(ctx.channel());
        if (username != null) {
            PlayerManager.removePlayer(username);
            // thong bao cho tat ca nguoi choi
            channels.writeAndFlush("PLAYER_LEFT:" + username + "\n");
        }
        ctx.close();
    }
} 