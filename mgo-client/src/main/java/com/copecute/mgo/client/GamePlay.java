package com.copecute.mgo.client;

import javax.imageio.ImageIO;
import javax.swing.*;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.KeyEvent;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.util.*;
import java.util.List;

// quản lý map game
public class GamePlay extends JPanel {
    private static final int TILE_SIZE = 32;
    private static final int MAP_WIDTH = 50;
    private static final int MAP_HEIGHT = 50;
    private static final int VIEWPORT_WIDTH = 20; // số ô hiển thị theo chiều ngang
    private static final int VIEWPORT_HEIGHT = 15; // số ô hiển thị theo chiều dọc
    private static final int MOVE_SPEED = 4; // số pixel di chuyển mỗi frame
    private static final float CAMERA_SMOOTH = 0.1f; // độ mượt của camera (0-1)
    private static final int SPRITE_WIDTH = 32; // chiều rộng sprite nhân vật
    private static final int SPRITE_HEIGHT = 32; // chiều cao sprite nhân vật
    private static final int MAX_CHAT_LENGTH = 100; // giới hạn độ dài chat
    private static final int CHAT_DISPLAY_TIME = 5000; // hiển thị chat trong 5 giây
    private static final int CHAT_DELAY = 1000; // delay 1 giây sau khi đăng nhập mới cho chat
    
    private final int[][] mapData; // 0: cỏ, 1: tường
    private final Map<String, PlayerInfo> players; // lưu thông tin người chơi
    private String currentPlayer; // người chơi hiện tại
    private BufferedImage mapBuffer; // buffer để vẽ map
    private final javax.swing.Timer moveTimer; // timer để update di chuyển
    private final Set<Integer> pressedKeys; // các phím đang được nhấn
    private Point targetPosition; // vị trí đích khi click chuột
    private Point cameraPosition; // vị trí camera hiện tại
    private BufferedImage playerSprite; // sprite sheet nhân vật
    private JTextField chatInput; // ô nhập chat
    private boolean isChatting = false; // đang chat hay không
    private final GameClient gameClient;
    private boolean canChat = false; // biến để kiểm tra có thể chat hay không
    private int lastSentTileX = -1; // vị trí ô cuối cùng đã gửi lên server (X)
    private int lastSentTileY = -1; // vị trí ô cuối cùng đã gửi lên server (Y)
    private BufferedImage grassImage; // hình ảnh cho ô cỏ
    private BufferedImage obstacleImage; // hình ảnh cho chướng ngại vật
    
    // lưu thông tin người chơi
    private static class PlayerInfo {
        Point position; // vị trí theo ô (tile)
        Point pixelPosition; // vị trí theo pixel
        List<Point> path; // đường đi tới đích
        boolean isMoving; // trạng thái di chuyển
        int frameIndex; // frame hiện tại của animation
        long lastFrameTime; // thời điểm frame cuối
        boolean facingRight; // hướng nhân vật (true: phải, false: trái)
        String chatMessage; // nội dung chat
        long chatTime; // thời điểm chat
        
        // Thêm điểm đích để di chuyển mượt
        Point targetPosition;
        
        PlayerInfo(Point position) {
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

    public GamePlay(GameClient gameClient) {
        this.gameClient = gameClient;
        players = new HashMap<>();
        mapData = new int[MAP_HEIGHT][MAP_WIDTH];
        pressedKeys = new HashSet<>();
        cameraPosition = new Point(0, 0);
        
        // thiết lập layout để có thể thêm chat input
        setLayout(null);
        
        // tạo ô nhập chat
        chatInput = new JTextField(MAX_CHAT_LENGTH);
        chatInput.setVisible(false);
        chatInput.addActionListener(e -> {
            String message = chatInput.getText().trim();
            if (!message.isEmpty()) {
                sendChatMessage(message);
            }
            closeChatInput();
        });
        add(chatInput);
        
        // load sprite sheet từ resources
        try {
            playerSprite = ImageIO.read(getClass().getResourceAsStream("/nhanvat.png"));
            if (playerSprite == null) {
                System.err.println("❌ không tìm thấy file nhanvat.png trong resources");
                // tạo sprite mặc định
                playerSprite = createDefaultSprite();
            }
        } catch (IOException e) {
            System.err.println("❌ lỗi load ảnh nhân vật: " + e.getMessage());
            // tạo sprite mặc định
            playerSprite = createDefaultSprite();
        }
        
        // load hình ảnh cho ô cỏ và chướng ngại vật
        try {
            grassImage = ImageIO.read(getClass().getResourceAsStream("/co.png"));
            obstacleImage = ImageIO.read(getClass().getResourceAsStream("/cay.png"));
        } catch (IOException e) {
            System.err.println("❌ lỗi load hình ảnh: " + e.getMessage());
        }
        
        // tạo map đơn giản
        for (int y = 0; y < MAP_HEIGHT; y++) {
            for (int x = 0; x < MAP_WIDTH; x++) {
                // tạo tường ở viền map
                if (x == 0 || y == 0 || x == MAP_WIDTH-1 || y == MAP_HEIGHT-1) {
                    mapData[y][x] = 1;
                }
                // tạo một số chướng ngại vật
                else if ((x % 10 == 0 && y % 10 == 0) || (x % 15 == 0 && y % 8 == 0)) {
                    mapData[y][x] = 1;
                }
                // phần còn lại là cỏ
                else {
                    mapData[y][x] = 0;
                }
            }
        }
        
        // tạo buffer cho map
        mapBuffer = new BufferedImage(MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE, BufferedImage.TYPE_INT_RGB);
        renderMapToBuffer();
        
        // thiết lập panel
        setPreferredSize(new Dimension(VIEWPORT_WIDTH * TILE_SIZE, VIEWPORT_HEIGHT * TILE_SIZE));
        setBackground(Color.BLACK);
        
        // thêm mouse listener để xử lý click
        addMouseListener(new java.awt.event.MouseAdapter() {
            @Override
            public void mouseClicked(java.awt.event.MouseEvent evt) {
                if (currentPlayer != null) {
                    PlayerInfo player = players.get(currentPlayer);
                    if (player != null) {
                        // chuyển từ tọa độ màn hình sang tọa độ map
                        int mapX = (evt.getX() + cameraPosition.x) / TILE_SIZE;
                        int mapY = (evt.getY() + cameraPosition.y) / TILE_SIZE;
                        
                        // tìm đường đi tới điểm click
                        targetPosition = new Point(mapX, mapY);
                        player.path = findPath(player.position, targetPosition);
                    }
                }
            }
        });

        // thêm key listener để bắt phím chat
        KeyboardFocusManager.getCurrentKeyboardFocusManager().addKeyEventDispatcher(e -> {
            if (e.getID() == KeyEvent.KEY_PRESSED) {
                if (!isChatting && canChat) {
                    // chỉ mở chat khi nhấn các phím chữ, số hoặc enter
                    int code = e.getKeyCode();
                    char keyChar = e.getKeyChar();
                    
                    boolean isAlphaNumeric = (keyChar >= 'a' && keyChar <= 'z') ||
                                           (keyChar >= 'A' && keyChar <= 'Z') ||
                                           (keyChar >= '0' && keyChar <= '9');
                                           
                    boolean isVietnamese = (keyChar >= 'à' && keyChar <= 'ỹ') ||
                                         (keyChar >= 'À' && keyChar <= 'Ỹ');
                                         
                    boolean isEnter = code == KeyEvent.VK_ENTER;
                    
                    if (isAlphaNumeric || isVietnamese || isEnter) {
                        openChatInput();
                        if (!isEnter && e.getKeyChar() != KeyEvent.CHAR_UNDEFINED) {
                            chatInput.setText(String.valueOf(e.getKeyChar()));
                        }
                        return true;
                    }
                    pressedKeys.add(code);
                } else if (e.getKeyCode() == KeyEvent.VK_ESCAPE) {
                    closeChatInput();
                    return true;
                }
            } else if (e.getID() == KeyEvent.KEY_RELEASED && !isChatting) {
                pressedKeys.remove(e.getKeyCode());
            }
            return false;
        });
        setFocusable(true);

        // tạo timer để update di chuyển
        moveTimer = new javax.swing.Timer(16, new ActionListener() { // 60 FPS
            @Override
            public void actionPerformed(ActionEvent e) {
                updateMovement();
                updateCamera();
                repaint();
            }
        });
        moveTimer.start();
    }

    private void updateCamera() {
        if (currentPlayer == null) return;
        PlayerInfo player = players.get(currentPlayer);
        if (player == null) return;

        // tính vị trí camera mục tiêu (giữ player ở giữa màn hình)
        int targetX = player.pixelPosition.x - (VIEWPORT_WIDTH * TILE_SIZE / 2);
        int targetY = player.pixelPosition.y - (VIEWPORT_HEIGHT * TILE_SIZE / 2);
        
        // giới hạn camera trong phạm vi map
        targetX = Math.max(0, Math.min(targetX, MAP_WIDTH * TILE_SIZE - VIEWPORT_WIDTH * TILE_SIZE));
        targetY = Math.max(0, Math.min(targetY, MAP_HEIGHT * TILE_SIZE - VIEWPORT_HEIGHT * TILE_SIZE));
        
        // nội suy tuyến tính để di chuyển camera mượt
        cameraPosition.x += (targetX - cameraPosition.x) * CAMERA_SMOOTH;
        cameraPosition.y += (targetY - cameraPosition.y) * CAMERA_SMOOTH;
    }

    private void updateMovement() {
        if (currentPlayer == null) return;
        PlayerInfo player = players.get(currentPlayer);
        if (player == null) return;

        // lưu vị trí cũ để kiểm tra có di chuyển không
        Point oldPosition = new Point(player.position);
        Point oldPixelPosition = new Point(player.pixelPosition);

        // xử lý di chuyển theo phím
        int dx = 0, dy = 0;
        
        // kiểm tra xem có phím di chuyển nào được nhấn không
        boolean movementKeyPressed = pressedKeys.contains(KeyEvent.VK_LEFT) || 
                                    pressedKeys.contains(KeyEvent.VK_RIGHT) || 
                                    pressedKeys.contains(KeyEvent.VK_UP) || 
                                    pressedKeys.contains(KeyEvent.VK_DOWN);
        
        // nếu có phím di chuyển được nhấn, hủy di chuyển theo path
        if (movementKeyPressed && player.path != null && !player.path.isEmpty()) {
            player.path.clear(); // xóa path nếu có phím di chuyển được nhấn
        }
        
        if (pressedKeys.contains(KeyEvent.VK_LEFT)) {
            dx -= MOVE_SPEED;
            player.facingRight = false;
        }
        if (pressedKeys.contains(KeyEvent.VK_RIGHT)) {
            dx += MOVE_SPEED;
            player.facingRight = true;
        }
        if (pressedKeys.contains(KeyEvent.VK_UP)) dy -= MOVE_SPEED;
        if (pressedKeys.contains(KeyEvent.VK_DOWN)) dy += MOVE_SPEED;

        // chuẩn hóa vector di chuyển chéo
        if (dx != 0 && dy != 0) {
            dx = (int)(dx / Math.sqrt(2));
            dy = (int)(dy / Math.sqrt(2));
        }

        // xử lý di chuyển theo path (chỉ khi không có phím di chuyển được nhấn)
        if (player.path != null && !player.path.isEmpty()) {
            Point next = player.path.get(0);
            Point target = new Point(next.x * TILE_SIZE, next.y * TILE_SIZE);
            
            // tính hướng di chuyển
            if (player.pixelPosition.x < target.x) {
                dx = MOVE_SPEED;
                player.facingRight = true;
            }
            else if (player.pixelPosition.x > target.x) {
                dx = -MOVE_SPEED;
                player.facingRight = false;
            }
            if (player.pixelPosition.y < target.y) dy = MOVE_SPEED;
            else if (player.pixelPosition.y > target.y) dy = -MOVE_SPEED;
            
            // chuẩn hóa vector di chuyển chéo
            if (dx != 0 && dy != 0) {
                dx = (int)(dx / Math.sqrt(2));
                dy = (int)(dy / Math.sqrt(2));
            }
            
            // kiểm tra đã tới ô tiếp theo chưa
            if (Math.abs(player.pixelPosition.x - target.x) <= MOVE_SPEED && 
                Math.abs(player.pixelPosition.y - target.y) <= MOVE_SPEED) {
                player.pixelPosition.setLocation(target.x, target.y);
                player.position.setLocation(next);
                player.path.remove(0);
                
                // cập nhật vị trí đích
                player.targetPosition.setLocation(next);
                
                // gửi vị trí mới lên server khi đến ô mới
                if (canMoveTo(next.x, next.y)) {
                    sendPositionIfChanged(next.x, next.y);
                }
            }
        }

        // cập nhật trạng thái di chuyển
        player.isMoving = (dx != 0 || dy != 0);
        
        // cập nhật frame animation
        if (player.isMoving) {
            long currentTime = System.currentTimeMillis();
            if (currentTime - player.lastFrameTime > 200) { // đổi frame mỗi 200ms
                player.frameIndex = (player.frameIndex + 1) % 2; // 2 frame cho mỗi trạng thái
                player.lastFrameTime = currentTime;
            }
        } else {
            player.frameIndex = 0;
        }

        // di chuyển theo pixel
        if (dx != 0 || dy != 0) {
            int newX = player.pixelPosition.x + dx;
            int newY = player.pixelPosition.y + dy;
            
            // kiểm tra va chạm theo pixel
            int tileX1 = newX / TILE_SIZE;
            int tileY1 = newY / TILE_SIZE;
            int tileX2 = (newX + SPRITE_WIDTH - 1) / TILE_SIZE;
            int tileY2 = (newY + SPRITE_HEIGHT - 1) / TILE_SIZE;
            
            // Kiểm tra di chuyển theo trục X
            boolean canMoveX = true;
            if (dx != 0) {
                // Kiểm tra va chạm cho toàn bộ chiều cao của nhân vật
                for (int checkY = tileY1; checkY <= tileY2; checkY++) {
                    if (dx > 0) {
                        // Đang di chuyển sang phải, kiểm tra cạnh phải
                        if (!canMoveTo(tileX2, checkY)) {
                            canMoveX = false;
                            break;
                        }
                    } else {
                        // Đang di chuyển sang trái, kiểm tra cạnh trái
                        if (!canMoveTo(tileX1, checkY)) {
                            canMoveX = false;
                            break;
                        }
                    }
                }
            }
            
            // Kiểm tra di chuyển theo trục Y
            boolean canMoveY = true;
            if (dy != 0) {
                // Kiểm tra va chạm cho toàn bộ chiều rộng của nhân vật
                for (int checkX = tileX1; checkX <= tileX2; checkX++) {
                    if (dy > 0) {
                        // Đang di chuyển xuống dưới, kiểm tra cạnh dưới
                        if (!canMoveTo(checkX, tileY2)) {
                            canMoveY = false;
                            break;
                        }
                    } else {
                        // Đang di chuyển lên trên, kiểm tra cạnh trên
                        if (!canMoveTo(checkX, tileY1)) {
                            canMoveY = false;
                            break;
                        }
                    }
                }
            }
            
            // Di chuyển theo trục X nếu có thể
            if (canMoveX) {
                player.pixelPosition.x = newX;
                int newTileX = player.pixelPosition.x / TILE_SIZE;
                if (newTileX != player.position.x) {
                    // cập nhật vị trí ô khi di chuyển
                    player.position.x = newTileX;
                    player.targetPosition.x = newTileX;
                    // gửi vị trí mới lên server khi di chuyển sang ô khác
                    if (canMoveTo(player.position.x, player.position.y)) {
                        sendPositionIfChanged(player.position.x, player.position.y);
                    }
                }
            }
            
            // Di chuyển theo trục Y nếu có thể
            if (canMoveY) {
                player.pixelPosition.y = newY;
                int newTileY = player.pixelPosition.y / TILE_SIZE;
                if (newTileY != player.position.y) {
                    // cập nhật vị trí ô khi di chuyển
                    player.position.y = newTileY;
                    player.targetPosition.y = newTileY;
                    // gửi vị trí mới lên server khi di chuyển sang ô khác
                    if (canMoveTo(player.position.x, player.position.y)) {
                        sendPositionIfChanged(player.position.x, player.position.y);
                    }
                }
            }
            
            // nếu không thể di chuyển thì quay lại vị trí cũ
            if (!canMoveX && !canMoveY) {
                player.position.setLocation(oldPosition);
                player.pixelPosition.setLocation(oldPixelPosition);
            }
        }
        
        // Cập nhật di chuyển cho tất cả người chơi khác
        updateOtherPlayersMovement();
    }

    // Gửi vị trí nếu có thay đổi so với lần gửi trước
    private void sendPositionIfChanged(int tileX, int tileY) {
        // Kiểm tra thêm một lần nữa xem có thể di chuyển tới vị trí đích không
        if (!canMoveTo(tileX, tileY)) {
            return; // Không gửi nếu không thể di chuyển tới
        }
        
        // Kiểm tra xem vị trí có thay đổi so với lần gửi trước không
        if (tileX != lastSentTileX || tileY != lastSentTileY) {
            // Tránh gửi quá nhiều request trong thời gian ngắn
            lastSentTileX = tileX;
            lastSentTileY = tileY;
            
            // Gửi vị trí mới lên server
            gameClient.sendMove(tileX, tileY);
        }
    }

    // Hàm mới để cập nhật vị trí của các người chơi khác mượt mà
    private void updateOtherPlayersMovement() {
        for (Map.Entry<String, PlayerInfo> entry : players.entrySet()) {
            String username = entry.getKey();
            PlayerInfo player = entry.getValue();
            
            // Bỏ qua người chơi hiện tại (đã update ở trên)
            if (username.equals(currentPlayer)) continue;
            
            // Di chuyển mượt mà tới vị trí đích
            int targetPixelX = player.targetPosition.x * TILE_SIZE;
            int targetPixelY = player.targetPosition.y * TILE_SIZE;
            
            // Nếu chưa tới vị trí đích, di chuyển mượt mà
            if (player.pixelPosition.x != targetPixelX || player.pixelPosition.y != targetPixelY) {
                // Tính khoảng cách còn lại để di chuyển
                int remainingX = targetPixelX - player.pixelPosition.x;
                int remainingY = targetPixelY - player.pixelPosition.y;
                
                // Xác định hướng
                boolean movingRight = remainingX > 0;
                boolean movingDown = remainingY > 0;
                
                // Xác định tốc độ di chuyển theo mỗi trục, luôn sử dụng MOVE_SPEED hằng số
                int dx = 0, dy = 0;
                
                // Di chuyển theo trục X
                if (remainingX != 0) {
                    dx = movingRight ? Math.min(MOVE_SPEED, Math.abs(remainingX)) : -Math.min(MOVE_SPEED, Math.abs(remainingX));
                    // Cập nhật hướng nhìn dựa trên hướng di chuyển
                    player.facingRight = movingRight;
                }
                
                // Di chuyển theo trục Y
                if (remainingY != 0) {
                    dy = movingDown ? Math.min(MOVE_SPEED, Math.abs(remainingY)) : -Math.min(MOVE_SPEED, Math.abs(remainingY));
                }
                
                // Nếu di chuyển chéo, điều chỉnh tốc độ
                if (dx != 0 && dy != 0) {
                    dx = (int)(dx / Math.sqrt(2));
                    dy = (int)(dy / Math.sqrt(2));
                }
                
                // Tính toán vị trí mới
                int newX = player.pixelPosition.x + dx;
                int newY = player.pixelPosition.y + dy;
                
                // Kiểm tra va chạm
                // Không cần kiểm tra va chạm quá kỹ cho người chơi khác vì server đã kiểm tra
                // Chủ yếu là kiểm tra va chạm với tường để đảm bảo hiển thị chính xác
                
                // Đảm bảo không vượt quá vị trí đích
                if ((dx > 0 && newX > targetPixelX) || (dx < 0 && newX < targetPixelX)) {
                    newX = targetPixelX;
                }
                
                if ((dy > 0 && newY > targetPixelY) || (dy < 0 && newY < targetPixelY)) {
                    newY = targetPixelY;
                }
                
                // Cập nhật vị trí pixel
                player.pixelPosition.x = newX;
                player.pixelPosition.y = newY;
                
                // Cập nhật vị trí theo ô
                player.position.x = player.pixelPosition.x / TILE_SIZE;
                player.position.y = player.pixelPosition.y / TILE_SIZE;
                
                // Cập nhật trạng thái di chuyển
                player.isMoving = (dx != 0 || dy != 0);
                
                // Cập nhật frame animation
                if (player.isMoving) {
                    long currentTime = System.currentTimeMillis();
                    if (currentTime - player.lastFrameTime > 200) {
                        player.frameIndex = (player.frameIndex + 1) % 2;
                        player.lastFrameTime = currentTime;
                    }
                } else {
                    player.frameIndex = 0;
                }
            } else {
                // Đã tới vị trí đích, dừng di chuyển
                player.isMoving = false;
                player.frameIndex = 0;
            }
        }
    }

    private List<Point> findPath(Point start, Point end) {
        // Nếu điểm đích không thể di chuyển tới, trả về danh sách trống
        if (!canMoveTo(end.x, end.y)) return new ArrayList<>();
        
        // Nếu điểm đích trùng với điểm xuất phát, không cần di chuyển
        if (start.equals(end)) return new ArrayList<>();
        
        // Thuật toán A* để tìm đường đi
        PriorityQueue<Node> openSet = new PriorityQueue<>();
        Set<Point> closedSet = new HashSet<>();
        Map<Point, Point> cameFrom = new HashMap<>();
        Map<Point, Integer> gScore = new HashMap<>();
        
        Node startNode = new Node(start, 0 + heuristic(start, end));
        openSet.add(startNode);
        gScore.put(start, 0);
        
        // Giới hạn số bước tìm kiếm để tránh tìm quá lâu
        int maxIterations = 1000;
        int iterations = 0;
        
        while (!openSet.isEmpty() && iterations < maxIterations) {
            iterations++;
            Node current = openSet.poll();
            
            // Nếu đã đến đích, tái tạo và trả về đường đi
            if (current.pos.equals(end)) {
                List<Point> path = reconstructPath(cameFrom, current.pos);
                return path;
            }
            
            closedSet.add(current.pos);
            
            // Xét 4 hướng di chuyển (lên, xuống, trái, phải)
            int[][] dirs = {{0,1}, {1,0}, {0,-1}, {-1,0}};
            for (int[] dir : dirs) {
                Point next = new Point(current.pos.x + dir[0], current.pos.y + dir[1]);
                
                // Bỏ qua nếu vị trí kế tiếp đã xét rồi
                if (closedSet.contains(next)) continue;
                
                // Bỏ qua nếu vị trí kế tiếp không thể di chuyển tới (tường hoặc ngoài map)
                if (!canMoveTo(next.x, next.y)) continue;
                
                // Tính điểm G (khoảng cách từ điểm xuất phát)
                int tentativeG = gScore.get(current.pos) + 1;
                
                // Cập nhật đường đi tốt hơn nếu tìm thấy
                if (!gScore.containsKey(next) || tentativeG < gScore.get(next)) {
                    cameFrom.put(next, current.pos);
                    gScore.put(next, tentativeG);
                    
                    // Tính điểm F = G + H (khoảng cách từ xuất phát + dự đoán khoảng cách tới đích)
                    int f = tentativeG + heuristic(next, end);
                    openSet.add(new Node(next, f));
                }
            }
        }
        
        // Nếu không tìm thấy đường đi, trả về danh sách trống
        return new ArrayList<>();
    }

    private int heuristic(Point a, Point b) {
        return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
    }

    private List<Point> reconstructPath(Map<Point, Point> cameFrom, Point current) {
        List<Point> path = new ArrayList<>();
        path.add(current);
        while (cameFrom.containsKey(current)) {
            current = cameFrom.get(current);
            path.add(0, current);
        }
        path.remove(0); // bỏ vị trí hiện tại
        return path;
    }

    private static class Node implements Comparable<Node> {
        Point pos;
        int f;
        
        Node(Point pos, int f) {
            this.pos = pos;
            this.f = f;
        }
        
        @Override
        public int compareTo(Node other) {
            return Integer.compare(f, other.f);
        }
    }

    private void renderMapToBuffer() {
        Graphics2D g = mapBuffer.createGraphics();
        
        // vẽ từng ô map
        for (int y = 0; y < MAP_HEIGHT; y++) {
            for (int x = 0; x < MAP_WIDTH; x++) {
                if (mapData[y][x] == 0) {
                    // vẽ ô cỏ
                    g.drawImage(grassImage, x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE, this);
                } else {
                    // vẽ chướng ngại vật với kích thước lớn hơn
                    int obstacleWidth = 70; // chiều rộng của chướng ngại vật
                    int obstacleHeight = 71; // chiều cao của chướng ngại vật
                    g.drawImage(obstacleImage, x * TILE_SIZE - (obstacleWidth - TILE_SIZE) / 2, 
                                y * TILE_SIZE - (obstacleHeight - TILE_SIZE), 
                                obstacleWidth, obstacleHeight, this);
                }
                // vẽ viền ô
                g.setColor(new Color(0, 0, 0, 50));
                g.drawRect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE);
            }
        }
        
        g.dispose();
    }

    @Override
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);
        
        if (currentPlayer == null) return;
        PlayerInfo currentPlayerInfo = players.get(currentPlayer);
        if (currentPlayerInfo == null) return;

        // vẽ phần map trong viewport
        g.drawImage(mapBuffer, 
            -cameraPosition.x, -cameraPosition.y, 
            MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE, 
            this);
        
        // vẽ người chơi và chat
        for (Map.Entry<String, PlayerInfo> entry : players.entrySet()) {
            String username = entry.getKey();
            PlayerInfo player = entry.getValue();
            
            int x = player.pixelPosition.x - cameraPosition.x;
            int y = player.pixelPosition.y - cameraPosition.y;
            
            // chỉ vẽ người chơi trong viewport
            if (x >= -TILE_SIZE && x <= VIEWPORT_WIDTH * TILE_SIZE &&
                y >= -TILE_SIZE && y <= VIEWPORT_HEIGHT * TILE_SIZE) {
                
                // vẽ sprite nhân vật
                int spriteX = player.frameIndex * SPRITE_WIDTH;
                int spriteY = player.isMoving ? 0 : SPRITE_HEIGHT;
                
                if (player.facingRight) {
                    g.drawImage(playerSprite,
                        x, y, x + SPRITE_WIDTH, y + SPRITE_HEIGHT,
                        spriteX, spriteY, spriteX + SPRITE_WIDTH, spriteY + SPRITE_HEIGHT,
                        this);
                } else {
                    g.drawImage(playerSprite,
                        x + SPRITE_WIDTH, y, x, y + SPRITE_HEIGHT,
                        spriteX, spriteY, spriteX + SPRITE_WIDTH, spriteY + SPRITE_HEIGHT,
                        this);
                }
                
                // vẽ tên người chơi
                FontMetrics fm = g.getFontMetrics();
                int nameWidth = fm.stringWidth(username);
                int nameX = x + (SPRITE_WIDTH - nameWidth) / 2;
                
                // vẽ nền cho tên
                g.setColor(new Color(0, 0, 0, 180));
                g.fillRoundRect(nameX - 2, y - 20, nameWidth + 4, 15, 5, 5);
                
                // vẽ tên người chơi
                g.setColor(Color.WHITE);
                g.drawString(username, nameX, y - 8);

                // vẽ chat message nếu có (di chuyển lên trên tên)
                if (player.chatMessage != null) {
                    long currentTime = System.currentTimeMillis();
                    if (currentTime - player.chatTime < CHAT_DISPLAY_TIME) {
                        // vẽ nền chat
                        int messageWidth = fm.stringWidth(player.chatMessage);
                        int messageX = x + (SPRITE_WIDTH - messageWidth) / 2;
                        
                        // vẽ nền chat với viền
                        g.setColor(new Color(0, 0, 0, 180));
                        g.fillRoundRect(messageX - 5, y - 45, messageWidth + 10, 20, 10, 10);
                        g.setColor(new Color(255, 255, 255, 100));
                        g.drawRoundRect(messageX - 5, y - 45, messageWidth + 10, 20, 10, 10);
                        
                        // vẽ text chat
                        g.setColor(Color.WHITE);
                        g.drawString(player.chatMessage, messageX, y - 30);
                    } else {
                        player.chatMessage = null;
                    }
                }
            }
        }
    }

    public void setCurrentPlayer(String username) {
        this.currentPlayer = username;
        // không tự tạo vị trí ngẫu nhiên nữa, đợi server gửi vị trí
        
        // delay 1 giây mới cho chat
        canChat = false;
        javax.swing.Timer chatTimer = new javax.swing.Timer(CHAT_DELAY, e -> {
            canChat = true;
            ((javax.swing.Timer)e.getSource()).stop();
        });
        chatTimer.start();
    }

    public void addPlayer(String username) {
        // không tự tạo vị trí ngẫu nhiên nữa, đợi server gửi vị trí
        if (!players.containsKey(username)) {
            players.put(username, new PlayerInfo(new Point(0, 0)));
            repaint();
        }
    }

    public void removePlayer(String username) {
        players.remove(username);
        repaint();
    }

    public void movePlayer(String username, int x, int y) {
        PlayerInfo player = players.get(username);
        if (player == null) {
            // nếu chưa có thông tin người chơi thì thêm mới
            player = new PlayerInfo(new Point(x, y));
            player.pixelPosition.setLocation(x * TILE_SIZE, y * TILE_SIZE);
            player.targetPosition.setLocation(x, y);
            players.put(username, player);
        } else {
            // Cập nhật vị trí đích
            player.targetPosition.setLocation(x, y);
            
            // Đối với người chơi hiện tại, cập nhật position luôn
            // nhưng không cập nhật pixelPosition để di chuyển vẫn mượt mà
            if (username.equals(currentPlayer)) {
                // Cập nhật vị trí ô cho đúng với server, nhưng giữ nguyên pixel position
                player.position.setLocation(x, y);
                
                // Cập nhật biến theo dõi vị trí đã gửi
                lastSentTileX = x;
                lastSentTileY = y;
            } else {
                // Đối với người chơi khác, cập nhật hướng nhìn dựa trên thay đổi vị trí
                if (x > player.position.x) {
                    player.facingRight = true;
                } else if (x < player.position.x) {
                    player.facingRight = false;
                }
                
                // Bắt đầu di chuyển 
                player.isMoving = true;
            }
        }
        
        repaint();
    }

    private boolean canMoveTo(int x, int y) {
        return x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT && mapData[y][x] == 0;
    }

    public void handleKeyPress(int keyCode) {
        pressedKeys.add(keyCode);
    }

    public Point getPlayerPosition(String username) {
        PlayerInfo player = players.get(username);
        return player != null ? player.position : null;
    }

    private BufferedImage createDefaultSprite() {
        BufferedImage sprite = new BufferedImage(SPRITE_WIDTH * 2, SPRITE_HEIGHT * 2, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = sprite.createGraphics();
        
        // vẽ sprite mặc định
        g.setColor(Color.BLUE);
        
        // frame di chuyển
        // frame 1: hình tròn
        g.fillOval(4, 4, SPRITE_WIDTH - 8, SPRITE_HEIGHT - 8);
        g.setColor(Color.WHITE);
        g.drawOval(4, 4, SPRITE_WIDTH - 8, SPRITE_HEIGHT - 8);
        
        // frame 2: hình tròn nhỏ hơn
        g.setColor(Color.BLUE);
        g.fillOval(SPRITE_WIDTH + 6, 6, SPRITE_WIDTH - 12, SPRITE_HEIGHT - 12);
        g.setColor(Color.WHITE);
        g.drawOval(SPRITE_WIDTH + 6, 6, SPRITE_WIDTH - 12, SPRITE_HEIGHT - 12);
        
        // frame đứng yên
        // frame 1: hình vuông
        g.setColor(Color.RED);
        g.fillRect(4, SPRITE_HEIGHT + 4, SPRITE_WIDTH - 8, SPRITE_HEIGHT - 8);
        g.setColor(Color.WHITE);
        g.drawRect(4, SPRITE_HEIGHT + 4, SPRITE_WIDTH - 8, SPRITE_HEIGHT - 8);
        
        // frame 2: hình vuông nhỏ hơn
        g.setColor(Color.RED);
        g.fillRect(SPRITE_WIDTH + 6, SPRITE_HEIGHT + 6, SPRITE_WIDTH - 12, SPRITE_HEIGHT - 12);
        g.setColor(Color.WHITE);
        g.drawRect(SPRITE_WIDTH + 6, SPRITE_HEIGHT + 6, SPRITE_WIDTH - 12, SPRITE_HEIGHT - 12);
        
        g.dispose();
        return sprite;
    }

    private void openChatInput() {
        if (!isChatting) {
            isChatting = true;
            chatInput.setBounds(10, getHeight() - 40, getWidth() - 20, 30);
            chatInput.setVisible(true);
            chatInput.requestFocus();
            revalidate();
            repaint();
        }
    }

    private void closeChatInput() {
        if (isChatting) {
            isChatting = false;
            chatInput.setVisible(false);
            chatInput.setText("");
            requestFocus();
            revalidate();
            repaint();
        }
    }

    private void sendChatMessage(String message) {
        if (message.length() > MAX_CHAT_LENGTH) {
            message = message.substring(0, MAX_CHAT_LENGTH);
        }
        // gửi tin nhắn tới server
        gameClient.sendChat(message);
    }

    public void handleChat(String username, String message) {
        PlayerInfo player = players.get(username);
        if (player != null) {
            player.chatMessage = message;
            player.chatTime = System.currentTimeMillis();
            repaint();
        }
    }
} 