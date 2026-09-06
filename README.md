# REO Mail

**Server-Wide Physical Mail & Postal Framework for FiveM**

REO Mail is an REO Development project focused on creating a persistent physical postal system that can connect players, residences, businesses, inventories, documents, and other server resources.

## Current Development Status

The current development checkpoint has a tested end-to-end player mail lifecycle:

**Player A → Compose Letter → Recipient PO Box → Persistent Mailbox → Physical Envelope → Open → Read**

### Working Features

- Persistent character postal profiles and PO Boxes
- `/mypobox` to view the current character's PO Box
- `/mymail` persistent mailbox interface
- `/sendmail` player-to-player letter composition interface
- Recipient lookup by PO Box
- Persistent player-to-player delivery
- Unique REO tracking numbers
- Physical `reo_envelope` inventory items with metadata
- Claim/take-envelope flow with duplicate-claim protection
- Physical envelope inspection
- Sealed/opened envelope state
- Server-side ownership and mail validation
- Physical letter reading after opening
- Delivery to characters who can retrieve the mail later

## Requirements

- Qbox / QBX
- ox_lib
- oxmysql
- ox_inventory

## Installation

1. Place `reo_mail` in your server resources directory.
2. Import `sql/reo_mail.sql` into your database.
3. Add the item definition from `install/ox_inventory_item.lua` to your ox_inventory items.
4. Ensure the required dependencies start before REO Mail.
5. Add `ensure reo_mail` to your server configuration.
6. Restart the server/resource and test with a valid character.

## Development Commands

- `/mypobox` — Display the current character's PO Box.
- `/mymail` — Open the current character's persistent mailbox.
- `/sendmail` — Compose and send a development-stage player-to-player letter by PO Box.

`/sendmail` is currently a development interface. Future versions are intended to move letter composition and mailing into physical postal interactions.

## Current Milestone

The persistent player-to-player delivery pipeline has been tested successfully from sender composition through recipient retrieval and physical letter reading.

The next development phase will focus on physical postal interaction points and reducing reliance on development commands.

## License

Copyright © 2026 REO Development. All Rights Reserved.

This project may not be redistributed, resold, repackaged, or claimed as another developer's work without explicit permission from REO Development.
