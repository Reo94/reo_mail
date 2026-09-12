-- ============================================================
-- REO DEVELOPMENT - REO MAIL v0.5.0
-- PACKAGE SYSTEM
-- ============================================================

CREATE TABLE IF NOT EXISTS `reo_mail_packages` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `package_uuid` VARCHAR(64) NOT NULL,
    `tracking_number` VARCHAR(64) DEFAULT NULL,
    `stash_id` VARCHAR(100) NOT NULL,
    `box_size` VARCHAR(20) NOT NULL,
    `sender_character_id` VARCHAR(100) NOT NULL,
    `sender_name` VARCHAR(150) DEFAULT NULL,
    `recipient_character_id` VARCHAR(100) DEFAULT NULL,
    `recipient_business_id` VARCHAR(100) DEFAULT NULL,
    `recipient_name` VARCHAR(150) DEFAULT NULL,
    `destination_type` VARCHAR(50) DEFAULT NULL,
    `destination_id` VARCHAR(100) DEFAULT NULL,
    `shipping_service` VARCHAR(30) DEFAULT NULL,
    `shipping_cost` INT UNSIGNED DEFAULT NULL,
    `status` VARCHAR(30) NOT NULL DEFAULT 'packing',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `sealed_at` TIMESTAMP NULL DEFAULT NULL,
    `dropped_off_at` TIMESTAMP NULL DEFAULT NULL,
    `delivery_due_at` TIMESTAMP NULL DEFAULT NULL,
    `delivered_at` TIMESTAMP NULL DEFAULT NULL,
    `picked_up_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_reo_package_uuid` (`package_uuid`),
    UNIQUE KEY `uq_reo_package_tracking` (`tracking_number`),
    KEY `idx_reo_package_recipient` (`recipient_character_id`, `status`),
    KEY `idx_reo_package_business` (`recipient_business_id`, `status`),
    KEY `idx_reo_package_due` (`status`, `delivery_due_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
