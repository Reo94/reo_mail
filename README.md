# REO Mail

**Version:** v0.1.0 — Core Mail Proof of Concept  
**Developer:** REO Development  
**Status:** Early Development / Proof of Concept

REO Mail is a server-wide physical mail and postal framework for FiveM. The v0.1.0 release establishes the basic lifecycle required for persistent character mail and physical inventory-based letters.

> **Development release:** v0.1.0 is a proof of concept. It is not feature complete or intended to represent the final REO Mail system.

## Proof-of-Concept Flow

**Create Mail → Store Mail → View Mailbox → Claim Envelope → Inspect Envelope → Open Envelope → Read Letter**

## Current Functionality

- Persistent character postal profiles
- Permanent PO Box assignment
- Qbox/QBX character integration
- Persistent mail records through oxmysql
- Unique REO tracking numbers
- `/mypobox` and `/mymail` functionality
- Physical `reo_envelope` ox_inventory item
- Envelope metadata for sender, recipient, subject, tracking and mail type
- Claim/take-envelope flow
- Sealed/opened envelope state
- Physical envelope inspection
- Open-envelope and read-letter interactions
- Server-side ownership and mail-record validation
- Duplicate claim protection
- Inventory-space handling

## Requirements

- Qbox / QBX
- ox_lib
- oxmysql
- ox_inventory

## Installation

1. Place the `reo_mail` resource in your server resources folder.
2. Import `sql/reo_mail.sql` into your database.
3. Add the item definition from `install/ox_inventory_item.lua` inside the main return table in `ox_inventory/data/items.lua`.
4. Ensure dependencies start before REO Mail.
5. Add `ensure reo_mail` to your server configuration.
6. Restart the server and test on a development environment first.

Example start order:

```cfg
ensure ox_lib
ensure oxmysql
ensure ox_inventory
ensure qbx_core
ensure reo_mail
```

## Development/Test Features

`Config.Development.enabled` is currently enabled because this release is intended for proof-of-concept and development testing. Review development commands/settings before using the resource outside a test environment.

## Planned Direction

Future development is intended to expand REO Mail with property and business addresses, physical world mailboxes, player-composed mail, packages, certified mail, automated mail from other resources, document/government integrations, postal sorting, delivery routes, and a playable postal worker role.

## License

Copyright © 2026 REO Development. All rights reserved. See `LICENSE`.
