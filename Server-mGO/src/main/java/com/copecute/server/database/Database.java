package com.copecute.server.database;

import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.Properties;

public class Database {
    private static Connection conn;

    public static void connect() {
        Properties props = new Properties();
        
        try (InputStream input = Database.class.getClassLoader().getResourceAsStream("config.properties")) {
            // đọc file config.properties
            if (input == null) {
                System.out.println("Không tìm thấy file config.properties");
                return;
            }
            
            props.load(input);
            
            // lấy thông tin kết nối từ file properties
            String host = props.getProperty("db.host");
            String port = props.getProperty("db.port");
            String dbName = props.getProperty("db.name");
            String user = props.getProperty("db.user");
            String pass = props.getProperty("db.password");
            
            // tạo url kết nối từ các thông tin đã đọc
            String url = "jdbc:mysql://" + host + ":" + port + "/" + dbName;
            
            conn = DriverManager.getConnection(url, user, pass);
            System.out.println("Connected to database!");
            
            // tạo bảng users nếu chưa tồn tại
            createTablesIfNotExist();
        } catch (IOException e) {
            System.out.println("Lỗi khi đọc file config.properties");
            e.printStackTrace();
        } catch (SQLException e) {
            System.out.println("Lỗi khi kết nối đến database");
            e.printStackTrace();
        }
    }

    private static void createTablesIfNotExist() throws SQLException {
        String createUsersTable = """
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(50) NOT NULL UNIQUE,
                password VARCHAR(64) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """;
        
        try (PreparedStatement stmt = conn.prepareStatement(createUsersTable)) {
            stmt.execute();
        }
    }

    public static Connection getConnection() {
        return conn;
    }
}
