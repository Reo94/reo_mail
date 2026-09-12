-- REO MAIL v0.7.0 - Prepared Mail, Express, Signature Receipts
ALTER TABLE `reo_mail_items`
    ADD COLUMN IF NOT EXISTS `shipping_service` VARCHAR(32) NULL AFTER `status`,
    ADD COLUMN IF NOT EXISTS `delivery_due_at` DATETIME NULL AFTER `shipping_service`,
    ADD COLUMN IF NOT EXISTS `signature_required` TINYINT(1) NOT NULL DEFAULT 0 AFTER `delivery_due_at`,
    ADD COLUMN IF NOT EXISTS `anonymous_sender` TINYINT(1) NOT NULL DEFAULT 0 AFTER `signature_required`,
    ADD COLUMN IF NOT EXISTS `signed_by_character_id` VARCHAR(100) NULL AFTER `anonymous_sender`,
    ADD COLUMN IF NOT EXISTS `signed_by_name` VARCHAR(150) NULL AFTER `signed_by_character_id`,
    ADD COLUMN IF NOT EXISTS `signed_at` DATETIME NULL AFTER `signed_by_name`;

ALTER TABLE `reo_mail_packages` ADD COLUMN IF NOT EXISTS `signature_signed_by` VARCHAR(150) NULL AFTER `signature_signed_at`;
