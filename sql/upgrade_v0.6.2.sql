-- ============================================================
-- REO DEVELOPMENT - REO MAIL v0.6.2
-- PACKAGE RETRIEVAL / SIGNATURE SUPPORT SCHEMA
-- Safe to run on an existing v0.6.x database.
-- ============================================================
ALTER TABLE `reo_mail_packages`
    ADD COLUMN IF NOT EXISTS `recipient_notified` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `sender_notified` TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `signature_signed_at` DATETIME NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `refused_at` DATETIME NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `return_due_at` DATETIME NULL DEFAULT NULL;
