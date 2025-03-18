-- tạo database nếu chưa có
CREATE DATABASE IF NOT EXISTS mgo;
USE mgo;

-- tạo bảng users
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- thêm index cho username để tăng tốc độ truy vấn
CREATE INDEX idx_username ON users(username); 