-- ============================================================
-- REO DEVELOPMENT
-- REO MAIL
-- Shared Constants
-- Version 0.1.0
-- ============================================================

REO_MAIL = REO_MAIL or {}

REO_MAIL.Types = {
    LETTER = 'letter',
    DOCUMENT = 'document',
    PACKAGE = 'package',
    CERTIFIED = 'certified'
}

REO_MAIL.Status = {
    CREATED = 'created',
    PROCESSING = 'processing',
    IN_TRANSIT = 'in_transit',
    OUT_FOR_DELIVERY = 'out_for_delivery',
    DELIVERED = 'delivered',
    RETURNED = 'returned'
}

REO_MAIL.AddressTypes = {
    PO_BOX = 'po_box',
    RESIDENCE = 'residence',
    APARTMENT = 'apartment',
    BUSINESS = 'business'
}

REO_MAIL.SenderTypes = {
    CHARACTER = 'character',
    BUSINESS = 'business',
    GOVERNMENT = 'government',
    COURT = 'court',
    LAW_ENFORCEMENT = 'law_enforcement',
    SYSTEM = 'system'
}

REO_MAIL.DeliveryMethods = {
    AUTOMATED = 'automated',
    POSTAL_WORKER = 'postal_worker'
}
