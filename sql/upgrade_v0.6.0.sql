-- ============================================================
-- REO DEVELOPMENT - REO MAIL v0.6.0
-- PACKAGE DELIVERY EXPANSION
-- Run once after v0.5.0/v0.5.1.
-- ============================================================

ALTER TABLE `reo_mail_packages`
    ADD COLUMN IF NOT EXISTS `anonymous_sender` TINYINT(1) NOT NULL DEFAULT 0 AFTER `shipping_cost`,
    ADD COLUMN IF NOT EXISTS `signature_required` TINYINT(1) NOT NULL DEFAULT 0 AFTER `anonymous_sender`,
    ADD COLUMN IF NOT EXISTS `scheduled_delivery_at` DATETIME NULL DEFAULT NULL AFTER `signature_required`,
    ADD COLUMN IF NOT EXISTS `recipient_notified` TINYINT(1) NOT NULL DEFAULT 0 AFTER `scheduled_delivery_at`,
    ADD COLUMN IF NOT EXISTS `sender_notified` TINYINT(1) NOT NULL DEFAULT 0 AFTER `recipient_notified`,
    ADD COLUMN IF NOT EXISTS `signature_signed_at` DATETIME NULL DEFAULT NULL AFTER `picked_up_at`,
    ADD COLUMN IF NOT EXISTS `refused_at` DATETIME NULL DEFAULT NULL AFTER `signature_signed_at`,
    ADD COLUMN IF NOT EXISTS `return_due_at` DATETIME NULL DEFAULT NULL AFTER `refused_at`,
    ADD COLUMN IF NOT EXISTS `returned_at` DATETIME NULL DEFAULT NULL AFTER `return_due_at`;

CREATE INDEX IF NOT EXISTS `idx_reo_package_signature`
    ON `reo_mail_packages` (`recipient_character_id`, `status`, `signature_required`);

CREATE INDEX IF NOT EXISTS `idx_reo_package_sender_status`
    ON `reo_mail_packages` (`sender_character_id`, `status`);
