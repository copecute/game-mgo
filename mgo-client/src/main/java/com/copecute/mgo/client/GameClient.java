package com.copecute.mgo.client;

import io.netty.bootstrap.Bootstrap;
import io.netty.channel.*;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.SocketChannel;
import io.netty.channel.socket.nio.NioSocketChannel;
import io.netty.handler.codec.string.StringDecoder;
import io.netty.handler.codec.string.StringEncoder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.swing.*;
import java.awt.*;
import java.awt.event.KeyAdapter;
import java.awt.event.KeyEvent;

// giao diện game và kết nối tới server
public class GameClient {
    private static final Logger logger = LoggerFactory.getLogger(GameClient.class);
    private final String host;
    private final int port;
    private Channel channel;
    private JFrame frame;
    private CardLayout cardLayout;
    private JPanel loginPanel;
    private JPanel gamePanel;
    private GameMap gameMap;
    private String username;

    public GameClient(String host, int port) {
        this.host = host;
        this.port = port;
        createAndShowGUI();
    }

    private void createAndShowGUI() {
        frame = new JFrame("MGO Game Client");
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setSize(800, 600);
        frame.setLocationRelativeTo(null);

        cardLayout = new CardLayout();
        frame.setLayout(cardLayout);

        // panel đăng nhập
        loginPanel = new JPanel(new GridBagLayout());
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(5, 5, 5, 5);

        JPanel loginForm = new JPanel(new GridLayout(3, 2, 5, 5));
        loginForm.setBorder(BorderFactory.createTitledBorder("Đăng nhập / Đăng ký"));

        JTextField txtUsername = new JTextField(20);
        JPasswordField txtPassword = new JPasswordField(20);
        JButton btnLogin = new JButton("Đăng nhập");
        JButton btnRegister = new JButton("Đăng ký");

        loginForm.add(new JLabel("Tên đăng nhập:"));
        loginForm.add(txtUsername);
        loginForm.add(new JLabel("Mật khẩu:"));
        loginForm.add(txtPassword);
        loginForm.add(btnLogin);
        loginForm.add(btnRegister);

        loginPanel.add(loginForm, gbc);

        // panel game
        gamePanel = new JPanel(new BorderLayout());
        
        // tạo game map
        gameMap = new GameMap(this);
        JScrollPane mapScroll = new JScrollPane(gameMap);
        
        // thêm vào panel game
        gamePanel.add(mapScroll, BorderLayout.CENTER);

        frame.add(loginPanel, "LOGIN");
        frame.add(gamePanel, "GAME");

        // xử lý sự kiện
        btnLogin.addActionListener(e -> {
            username = txtUsername.getText();
            String password = new String(txtPassword.getPassword());
            if (channel != null) {
                channel.writeAndFlush("LOGIN:" + username + ":" + password);
            }
        });

        btnRegister.addActionListener(e -> {
            username = txtUsername.getText();
            String password = new String(txtPassword.getPassword());
            if (channel != null) {
                channel.writeAndFlush("REGISTER:" + username + ":" + password);
            }
        });

        // thêm key listener để xử lý phím
        frame.addKeyListener(new KeyAdapter() {
            @Override
            public void keyPressed(KeyEvent e) {
                gameMap.handleKeyPress(e.getKeyCode());
            }
        });
        frame.setFocusable(true);

        frame.setVisible(true);
        cardLayout.show(frame.getContentPane(), "LOGIN");
    }

    public void showMessage(String message) {
        SwingUtilities.invokeLater(() -> {
            JOptionPane.showMessageDialog(frame, message);
        });
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public void loginSuccess() {
        SwingUtilities.invokeLater(() -> {
            cardLayout.show(frame.getContentPane(), "GAME");
            gameMap.setCurrentPlayer(username);
            frame.requestFocus();
        });
    }

    public void updatePlayerPosition(String username, int x, int y) {
        SwingUtilities.invokeLater(() -> {
            gameMap.movePlayer(username, x, y);
        });
    }

    public void playerJoined(String username) {
        SwingUtilities.invokeLater(() -> {
            gameMap.addPlayer(username);
        });
    }

    public void playerLeft(String username) {
        SwingUtilities.invokeLater(() -> {
            gameMap.removePlayer(username);
        });
    }

    public void start() throws InterruptedException {
        EventLoopGroup group = new NioEventLoopGroup();
        try {
            Bootstrap bootstrap = new Bootstrap();
            bootstrap.group(group)
                    .channel(NioSocketChannel.class)
                    .handler(new ChannelInitializer<SocketChannel>() {
                        @Override
                        protected void initChannel(SocketChannel ch) {
                            ch.pipeline().addLast(
                                new StringDecoder(),
                                new StringEncoder(),
                                new GameClientHandler(GameClient.this)
                            );
                        }
                    });

            channel = bootstrap.connect(host, port).sync().channel();
            logger.info("✅ da ket noi tới server {}:{}", host, port);
            channel.closeFuture().sync();
        } finally {
            group.shutdownGracefully();
        }
    }

    public void handleChat(String username, String message) {
        SwingUtilities.invokeLater(() -> {
            gameMap.handleChat(username, message);
        });
    }

    public void sendChat(String message) {
        if (channel != null) {
            channel.writeAndFlush("CHAT:" + message + "\n");
        }
    }

    public void sendMove(int x, int y) {
        if (channel != null) {
            channel.writeAndFlush("MOVE:" + x + ":" + y + "\n");
        }
    }

    public static void main(String[] args) throws InterruptedException {
        new GameClient("localhost", 8696).start();
    }
} 