-- ============================================================
-- REO DEVELOPMENT - REO MAIL v0.3.8
-- Recipient Directory + Basic Letter Templates
-- ============================================================

ALTER TABLE `reo_mail_profiles`
    ADD COLUMN IF NOT EXISTS `display_name` VARCHAR(150) DEFAULT NULL AFTER `character_id`;

ALTER TABLE `reo_mail_items`
    ADD COLUMN IF NOT EXISTS `letter_template` VARCHAR(50) NOT NULL DEFAULT 'basic' AFTER `mail_type`;
