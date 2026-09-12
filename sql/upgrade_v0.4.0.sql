-- ============================================================
-- REO DEVELOPMENT - REO MAIL v0.4.0
-- Persistent Qbox directory + business mailboxes
-- ============================================================

ALTER TABLE `reo_mail_items`
    MODIFY COLUMN `recipient_character_id` VARCHAR(100) NULL,
    ADD COLUMN IF NOT EXISTS `recipient_business_id` VARCHAR(100) NULL AFTER `recipient_character_id`;

CREATE INDEX IF NOT EXISTS `idx_recipient_business`
    ON `reo_mail_items` (`recipient_business_id`);
