# REO Mail Changelog

## Unreleased — Player-to-Player Mail Development Checkpoint

### Added
- Player-to-player letter composition through `/sendmail`.
- Recipient resolution using persistent PO Box numbers.
- Persistent delivery into another character's mailbox.
- Sender delivery confirmation with REO tracking number.
- Physical envelope open callback and sealed/opened metadata handling.

### Verified
- `/mypobox` returns the player's persistent PO Box.
- Player A can send a letter to Player B's PO Box.
- Player B can retrieve the letter from `/mymail`.
- Received mail can be claimed as a physical envelope.
- The envelope can be inspected, opened, and read.
- Ownership and envelope state validation remain server-side.

### Development Notes
- `/sendmail` remains a development-stage interface and is expected to be replaced or supplemented by physical postal interactions.
- This checkpoint is intended for source control and continued development; it is not being promoted as the next formal release.
