# OVI — Onderworld Connection Interface

A persistent, phone-based criminal relationship network for QBCore. OVI is not a
drug-selling menu — it's a standalone phone app that lives on a physical burner
item. Contacts, messages, deliveries, trust, heat, GPS logs and notes are all
stored against the phone's IMEI, never against the player. Drop the phone, lose
the phone, get robbed — whoever ends up holding it (and knows the PIN) inherits
everything on it.

## Dependencies

- [qb-core](https://github.com/qbcore-framework/qb-core)
- [oxmysql](https://github.com/overextended/oxmysql)
- [qb-target](https://github.com/qbcore-framework/qb-target)
- [qb-input](https://github.com/qbcore-framework/qb-input)
- [qb-menu](https://github.com/qbcore-framework/qb-menu)
- [qb-inventory](https://github.com/qbcore-framework/qb-inventory) (or any fork
  that supports `useableitem` callbacks and item metadata)

OVI does not require qb-phone. It ships its own NUI app and is opened either by
using the physical phone item or with the `/ovi` command (configurable) while
holding one.

## Installation

1. Copy the `ovi` folder into your server's `resources` directory.
2. Import `sql/install.sql` into your database (phpMyAdmin, HeidiSQL, or the
   `mysql` CLI). This creates all `ovi_*` tables — nothing else in your
   database is touched.
3. Add `ensure ovi` to your `server.cfg`, after `qb-core`, `oxmysql`,
   `qb-target`, `qb-input` and `qb-menu`.
4. Drop item images into your inventory resource's image folder (e.g.
   `qb-inventory/html/images/`). File names matching the `image` field in
   `shared/items.lua`:
   - `ovi_burner.png`, `ovi_midburner.png`, `ovi_ghostphone.png`,
     `ovi_installkey.png`, `ovi_cryptowallet.png`, `ovi_fakeid.png`,
     `ovi_stashkey.png`
5. Items are injected into `QBCore.Shared.Items` automatically on resource
   start (`server/main.lua`). If your inventory fork snapshots its own item
   list instead of reading `QBCore.Shared.Items` live, copy the entries from
   `shared/items.lua` into `qb-core/shared/items.lua` (or your fork's item
   list) by hand.
6. Restart your server (or `refresh` + `ensure ovi`).

Give yourself a phone to test with:

```
/giveitem [id] ovi_burner 1
```

Then place an installer NPC config close to you (see below) or temporarily set
its `coords` to your location, use the phone, find the NPC, pay for the
install, set a PIN/alias, and you're in.

## Configuration

Every system is config-driven and individually toggleable from
`config/main.lua`'s `Config.Toggle` table. Setting any of these to `false`
disables that file's server logic entirely (each `server/*.lua` file starts
with `if not Config.Toggle.X then return end`) — no other code needs touching.

| Toggle | Config file | Disables |
|---|---|---|
| `Phones` | `config/phones.lua` | the phone item tiers (required for everything else) |
| `OVIInstaller` | `config/installers.lua` | NPCs that install OVI onto a phone |
| `Security` | `config/security.lua` | PIN lockouts, self-wipe, GPS beacon, police ping |
| `StreetSales` | `config/street_sales.lua` | selling to random street NPCs |
| `Negotiation` | `config/negotiation.lua` | free-type price/quantity negotiation parser |
| `Trust` | `config/trust.lua` | trust/loyalty tracking per contact |
| `Timers` | `config/timers.lua` | delivery patience timeouts |
| `Complaints` | `config/complaints.lua` | complaint propagation network |
| `Referrals` | `config/referrals.lua` | clients referring new clients |
| `SharedClients` | `config/shared_clients.lua` | one contact owned by multiple players |
| `ClientReplacement` | `config/replacement.lua` | auto-replacing a contact who churns |
| `Heat` | `config/heat.lua` | hidden per-phone suspicion meter |
| `DeadDrops` | `config/deaddrops.lua` | qb-target prop-based blind drop-offs |
| `RandomContacts` | `config/random_contacts.lua` | unsolicited "wrong number" texts |
| `Traps` | `config/traps.lua` | ambush deliveries |
| `Suppliers` | `config/suppliers.lua` | unlockable drug supplier NPCs |
| `Ghosting` | `config/ghosting.lua` | contacts going offline/arrested/dead |
| `PoliceEvidence` | `config/police.lua` | exports for police scripts reading seized phones |
| `Cloning` | `config/cloning.lua` | phone backup/clone/migrate NPC |
| `CodeLanguage` | `config/codes.lua` | coded slang substitution in client messages |

Other notable configs:

- `config/ui.lua` — app name, subtitle, theme colors, boot sequence text,
  which dashboard tabs are shown.
- `config/clients.lua` — NPC contact personalities, trust/patience/risk
  ranges, name pools.
- `config/drugs.lua` — drug catalog, base prices, item links.
- `config/phones.lua` — burner tiers, prices, PIN length per tier.

`Config.OpenCommand` (in `config/main.lua`) sets the chat command fallback
(default `/ovi`) for opening the dashboard on the last phone you used.

## Database

All tables are prefixed `ovi_` and keyed by `phone_imei` (or `contact_id` for
the global client pool), never by `citizenid`. See `sql/install.sql` for the
full schema. `server/db.lua` is the only file that talks to MySQL — every
other server file goes through the `OVI.DB.*` namespace.

## Police integration

If `Config.Toggle.PoliceEvidence` is enabled, `server/police.lua` exposes
exports for reading a seized phone's contacts/messages/deliveries so a
separate police/MDT resource can pull evidence without touching OVI's
internals directly.

## Notes for server owners

- Everything is event-driven; there are no polling loops on the server.
  Active deliveries, owned contacts and online phone holders are cached in
  `OVI.Cache` and only hit the database on writes or on dashboard load.
- PIN verification, trap outcomes and street-sale outcomes are resolved
  server-side only — the client never sees the logic that decides them.
- Comments in each config file explain every field; none of them need to be
  read alongside another config to make sense — each system's settings live
  in exactly one file.
