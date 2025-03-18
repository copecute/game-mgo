# Game Online RPG MMO

Một game online RPG MMO đơn giản sử dụng Java, Netty và MySQL.

## Yêu cầu hệ thống

- Java 22
- MySQL Server
- Maven

## Cài đặt

1. Clone repository này về máy
2. Import file SQL trong `mgo-server/src/main/resources/database.sql` vào MySQL
3. Cấu hình kết nối database trong file `mgo-server/src/main/java/com/copecute/mgo/server/DatabaseManager.java`

## Chạy ứng dụng

1. Chạy server:
```bash
cd mgo-server
mvn clean install
mvn exec:java -Dexec.mainClass="com.copecute.mgo.server.GameServer"
```

2. Chạy client:
```bash
cd mgo-client
mvn clean install
mvn exec:java -Dexec.mainClass="com.copecute.mgo.client.GameClient"
```

## Chức năng

- Đăng ký tài khoản mới
- Đăng nhập
- Chat với người chơi khác

## Lưu ý

- Server chạy trên port 8696
- Database mặc định:
  - Host: localhost
  - Database: mgo
  - Username: root
  - Password: (để trống) 