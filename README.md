# REO Mail v2.0.0 — Core Postal Framework

REO Mail is a server-wide physical postal framework for FiveM developed by **REO Development**. It provides a configurable core for physical letters, packages, PO Boxes, tracking, signatures, postal supplies, mailbox delivery, public post boxes, and postal service interactions.

## Core Features

- Persistent character postal profiles and permanent PO Boxes
- Character recipient search
- Physical letters, prepared letters, envelopes, and letter reading UI
- Postal supply purchasing
- Small, Medium, Large, and Extra Large shipping boxes
- Standard, Priority, Overnight, and Express services
- Persistent package delivery timers
- Package tracking and pickup flows
- Anonymous sender and signature-required options
- Refusal and return-to-sender lifecycle
- Configurable mailbox delivery eligibility by mail/package size
- Vanilla GTA V public post box support for eligible prepared mail
- Configurable postal counter/clerk location
- Optional configurable business mailboxes
- Qbox/QBX + ox_lib + ox_inventory + oxmysql integration

## Requirements

- qbx_core / Qbox
- ox_lib
- ox_inventory
- oxmysql

## Installation

1. Extract the resource folder as `reo_mail` into your FiveM server resources directory.
2. Import `sql/reo_mail.sql` for a fresh installation.
3. Add the item definitions from `install/ox_inventory_item.lua` to your ox_inventory item configuration.
4. Copy the matching PNG files from `install/images/` into the appropriate ox_inventory image directory for your inventory setup.
5. Review `config.lua`, including postal locations, pricing, package services, mailbox eligibility, and optional business mailboxes.
6. Ensure `qbx_core`, `ox_lib`, `ox_inventory`, and `oxmysql` start before REO Mail.
7. Add `ensure reo_mail` to `server.cfg`.
8. Restart the server and verify the postal systems before production use.

## Business Mailboxes

`Config.Businesses` is designed to be configurable by individual server owners. Add server-specific businesses through configuration rather than modifying the core postal logic.

## Resource Structure

- `client/` — client-side postal interactions and UI integration
- `server/` — server-side postal logic and persistence
- `bridges/` — framework integration
- `shared/` — shared constants and configuration support
- `web/` — REO Mail postal terminal interface and images
- `install/` — inventory item definitions and item images
- `sql/` — fresh-install schema and historical upgrade scripts

## License

Copyright © 2026 REO Development. All Rights Reserved.

REO Mail is distributed under the **REO Development Limited Use License** included in `LICENSE`. Use and modification are permitted for personal use and FiveM server use subject to that license. Sale, resale, paid repackaging, and false authorship are prohibited. Modified redistribution must retain REO Development attribution and identify modifications.

Third-party frameworks, dependencies, trademarks, names, and assets remain the property of their respective owners. REO Development is not affiliated with or endorsed by those third parties.
