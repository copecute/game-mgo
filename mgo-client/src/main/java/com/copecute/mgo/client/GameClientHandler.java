package com.copecute.mgo.client;

import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundHandlerAdapter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

// xu ly tin nhan tu server
public class GameClientHandler extends ChannelInboundHandlerAdapter {
    private static final Logger logger = LoggerFactory.getLogger(GameClientHandler.class);
    private final GameClient gameClient;
    private final StringBuilder messageBuffer = new StringBuilder();

    public GameClientHandler(GameClient gameClient) {
        this.gameClient = gameClient;
    }

    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) {
        String message = (String) msg;
        messageBuffer.append(message);

        // xu ly tung message duoc phan tach boi \n
        int newlineIndex;
        while ((newlineIndex = messageBuffer.indexOf("\n")) != -1) {
            String completeMessage = messageBuffer.substring(0, newlineIndex);
            messageBuffer.delete(0, newlineIndex + 1);
            
            handleMessage(completeMessage);
        }
    }

    private void handleMessage(String message) {
        logger.info("nhan tu server: {}", message);

        String[] parts = message.split(":");
        String command = parts[0];

        switch (command) {
            case "LOGIN_SUCCESS":
                handleLoginSuccess(parts);
                break;
            case "LOGIN_FAIL":
                handleLoginFail(parts);
                break;
            case "REGISTER_SUCCESS":
                handleRegisterSuccess(parts);
                break;
            case "REGISTER_FAIL":
                handleRegisterFail(parts);
                break;
            case "MOVE":
                handleMove(parts);
                break;
            case "MOVE_FAIL":
                handleMoveFail(parts);
                break;
            case "PLAYER_JOINED":
                handlePlayerJoined(parts);
                break;
            case "PLAYER_LEFT":
                handlePlayerLeft(parts);
                break;
            case "CHAT":
                handleChat(parts);
                break;
            default:
                logger.warn("lenh khong hop le: {}", command);
        }
    }

    private void handleLoginSuccess(String[] parts) {
        if (parts.length != 2) return;
        String username = parts[1];
        gameClient.setUsername(username);
        gameClient.loginSuccess();
        logger.info("dang nhap thanh cong voi username: {}", username);
    }

    private void handleLoginFail(String[] parts) {
        if (parts.length != 2) return;
        String reason = parts[1];
        gameClient.showMessage("Dang nhap that bai: " + reason);
        logger.warn("dang nhap that bai: {}", reason);
    }

    private void handleRegisterSuccess(String[] parts) {
        if (parts.length != 2) return;
        String message = parts[1];
        gameClient.showMessage(message);
        logger.info("dang ky thanh cong");
    }

    private void handleRegisterFail(String[] parts) {
        if (parts.length != 2) return;
        String reason = parts[1];
        gameClient.showMessage("Dang ky that bai: " + reason);
        logger.warn("dang ky that bai: {}", reason);
    }

    private void handleMove(String[] parts) {
        if (parts.length != 4) return;
        String username = parts[1];
        try {
            int x = Integer.parseInt(parts[2]);
            int y = Integer.parseInt(parts[3]);
            gameClient.updatePlayerPosition(username, x, y);
            logger.info("nguoi choi {} di chuyen den ({}, {})", username, x, y);
        } catch (NumberFormatException e) {
            logger.error("toa do khong hop le");
        }
    }

    private void handleMoveFail(String[] parts) {
        if (parts.length != 2) return;
        String reason = parts[1];
        logger.warn("di chuyen that bai: {}", reason);
    }

    private void handlePlayerJoined(String[] parts) {
        if (parts.length != 2) return;
        String username = parts[1];
        gameClient.playerJoined(username);
        logger.info("nguoi choi {} da tham gia", username);
    }

    private void handlePlayerLeft(String[] parts) {
        if (parts.length != 2) return;
        String username = parts[1];
        gameClient.playerLeft(username);
        logger.info("nguoi choi {} da roi di", username);
    }

    private void handleChat(String[] parts) {
        if (parts.length != 3) return;
        String username = parts[1];
        String message = parts[2];
        gameClient.handleChat(username, message);
        logger.info("nguoi choi {} chat: {}", username, message);
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
        // chi log loi neu khong phai la loi mat ket noi
        if (!(cause instanceof java.net.SocketException)) {
            logger.error("❌ loi ket noi: ", cause);
            gameClient.showMessage("Loi ket noi: " + cause.getMessage());
        } else {
            // neu la loi mat ket noi thi chi log thong bao
            logger.info("da ngat ket noi voi server");
        }
        ctx.close();
    }
}