-- ============================================================
-- REO DEVELOPMENT - REO MAIL v0.4.9
-- Current Schema Compatibility Upgrade
--
-- Safe upgrade for existing REO Mail installations.
-- Adds the columns required by the current compose/template and
-- business-routing systems without deleting existing mail.
-- ============================================================

ALTER TABLE `reo_mail_items`
    ADD COLUMN IF NOT EXISTS `recipient_name` VARCHAR(150) DEFAULT NULL AFTER `recipient_character_id`,
    ADD COLUMN IF NOT EXISTS `recipient_business_id` VARCHAR(100) DEFAULT NULL AFTER `recipient_character_id`,
    ADD COLUMN IF NOT EXISTS `letter_template` VARCHAR(50) NOT NULL DEFAULT 'basic' AFTER `mail_type`,
    ADD COLUMN IF NOT EXISTS `destination_type` VARCHAR(50) DEFAULT NULL AFTER `status`,
    ADD COLUMN IF NOT EXISTS `destination_id` VARCHAR(100) DEFAULT NULL AFTER `destination_type`,
    ADD COLUMN IF NOT EXISTS `reissue_count` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `claimed_at`;

-- Existing personal mail predates destination routing. Backfill it so
-- current code can treat older records as PO-box mail where possible.
UPDATE `reo_mail_items` AS m
LEFT JOIN `reo_mail_profiles` AS p
    ON p.`character_id` = m.`recipient_character_id`
SET
    m.`destination_type` = COALESCE(m.`destination_type`, 'po_box'),
    m.`destination_id` = COALESCE(m.`destination_id`, CAST(p.`po_box` AS CHAR))
WHERE m.`recipient_character_id` IS NOT NULL
  AND (m.`destination_type` IS NULL OR m.`destination_id` IS NULL);

-- Business mail requires personal recipient IDs to be nullable.
ALTER TABLE `reo_mail_items`
    MODIFY COLUMN `recipient_character_id` VARCHAR(100) NULL;
