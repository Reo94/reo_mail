-- ============================================================
-- REO DEVELOPMENT
-- REO MAIL
-- Database Schema
-- Version 0.1.0
-- ============================================================

CREATE TABLE IF NOT EXISTS `reo_mail_profiles` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` VARCHAR(100) NOT NULL,
    `po_box` INT UNSIGNED NOT NULL,
    `preferred_address_type` VARCHAR(50) NOT NULL DEFAULT 'po_box',
    `preferred_address_id` VARCHAR(100) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_character_id` (`character_id`),
    UNIQUE KEY `unique_po_box` (`po_box`)
);

CREATE TABLE IF NOT EXISTS `reo_mail_items` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tracking_number` VARCHAR(50) NOT NULL,
    `sender_type` VARCHAR(50) NOT NULL,
    `sender_id` VARCHAR(100) DEFAULT NULL,
    `sender_name` VARCHAR(150) NOT NULL,
    `recipient_character_id` VARCHAR(100) NOT NULL,
    `recipient_name` VARCHAR(150) DEFAULT NULL,
    `mail_type` VARCHAR(50) NOT NULL DEFAULT 'letter',
    `subject` VARCHAR(100) DEFAULT NULL,
    `body` TEXT DEFAULT NULL,
    `status` VARCHAR(50) NOT NULL DEFAULT 'created',
    `destination_type` VARCHAR(50) NOT NULL,
    `destination_id` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `delivered_at` TIMESTAMP NULL DEFAULT NULL,
    `claimed_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_tracking_number` (`tracking_number`),
    INDEX `idx_recipient_character` (`recipient_character_id`),
    INDEX `idx_sender` (`sender_type`, `sender_id`),
    INDEX `idx_status` (`status`),
    INDEX `idx_destination` (`destination_type`, `destination_id`)
);
