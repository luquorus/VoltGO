-- Script để xóa tất cả dữ liệu trong các bảng
-- Thứ tự xóa phải tuân theo foreign key constraints

-- Xóa dữ liệu từ các bảng con trước
DELETE FROM charging_port;
DELETE FROM station_service;
DELETE FROM change_request;
DELETE FROM audit_log;
DELETE FROM station_version;
DELETE FROM station;
DELETE FROM user_account;

-- Reset sequences nếu có (PostgreSQL tự động quản lý UUID, không cần reset)
-- Nhưng có thể cần reset nếu có sequences khác

-- Xác nhận đã xóa hết
SELECT 
    'charging_port' as table_name, COUNT(*) as remaining_rows FROM charging_port
UNION ALL
SELECT 'station_service', COUNT(*) FROM station_service
UNION ALL
SELECT 'change_request', COUNT(*) FROM change_request
UNION ALL
SELECT 'audit_log', COUNT(*) FROM audit_log
UNION ALL
SELECT 'station_version', COUNT(*) FROM station_version
UNION ALL
SELECT 'station', COUNT(*) FROM station
UNION ALL
SELECT 'user_account', COUNT(*) FROM user_account;

