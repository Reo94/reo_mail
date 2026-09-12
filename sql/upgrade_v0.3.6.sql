-- REO Mail v0.3.6 - Lost Mail Recovery
ALTER TABLE reo_mail_items
    ADD COLUMN IF NOT EXISTS reissue_count INT NOT NULL DEFAULT 0;
