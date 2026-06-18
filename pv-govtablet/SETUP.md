# Setup Checklist (Start Here)

This is the short, plain-language version. Follow it top to bottom and the
tablet will work. `README.md` has the full details if you want to
understand *why* something works the way it does — this file is just the
"do this, then this" list.

---

## ☐ 1. Put the resource on your server

Copy the whole `pv-govtablet` folder into your server's `resources` folder
(wherever you keep `qb-core`, `qb-houses`, etc).

## ☐ 2. Create the database tables

Open `sql/install.sql` and run it against your server's database. Easiest
ways to do that:

- **phpMyAdmin / HeidiSQL**: open the file, paste it into a new query tab,
  click Run.
- **Command line**: `mysql -u youruser -p yourdatabase < sql/install.sql`

This only *adds* new tables (all named `gt_...`). It does not touch or
delete anything from qb-core, qb-houses, qb-garages, etc — completely safe
to run even on a live server.

## ☐ 3. Add it to your server.cfg

Open `server.cfg` and add this line **after** the lines for `qb-core` and
`oxmysql`:

```
ensure pv-govtablet
```

## ☐ 4. Open `config.lua` and fix the job names

This is the most important step. Open `pv-govtablet/config.lua` and find
`Config.Jobs`. The keys (`'mayor'`, `'tax'`, `'government'`, `'doj'`,
`'judge'`) must match the **exact** job names from your `qb-core/shared/jobs.lua`.

- If your tax job is actually called `'taxagency'` instead of `'tax'`,
  rename the key.
- If a job in the list doesn't exist on your server, you can delete that
  whole block.
- If you have a job that should have tablet access but isn't listed
  (e.g. a custom `'police'` job), copy one of the existing blocks and
  change the name/permissions.
- `minGrade` is the lowest grade level (rank) in that job allowed to use
  the tablet. `0` means everyone in that job.

## ☐ 5. Decide how staff open the tablet

Still in `config.lua`:

```lua
Config.Command  = 'govtablet'   -- typing /govtablet opens it
Config.UseItem  = true          -- set to false if you don't want an item
Config.Item     = 'gov_tablet'
```

If you want the item option, add it to `qb-core/shared/items.lua`:

```lua
['gov_tablet'] = { name = 'gov_tablet', label = 'Government Tablet', weight = 500, type = 'item', image = 'gov_tablet.png', unique = true, useable = true, shouldClose = true, description = 'Secure government access terminal' },
```

Then give it to staff (starting loadout, a shop, or `/giveitem yourname gov_tablet 1` for testing) and drop a `gov_tablet.png` into your inventory resource's image folder.

If you don't care about the item, just leave `Config.UseItem = false` and
use the `/govtablet` command instead — nothing else to do.

## ☐ 6. Check the Housing / Garage table names match your server

Most servers don't need to touch this — it already matches default
qb-houses and qb-garages. Only edit `Config.Bridge.Housing` /
`Config.Bridge.Garage` in `config.lua` if you run a **different** housing
or garage script with different table/column names.

## ☐ 7. Check the Businesses table name matches your server

```lua
Config.Bridge.Business = {
    FundsTable  = 'management_funds',  -- default qb-management table
    JobField    = 'job_name',
    AmountField = 'amount',
}
```

If you don't use qb-management for business money, find out what table
your boss-menu/society script stores balances in and put that table/column
names here instead. If you're not sure, leave it as-is — businesses will
just show $0 until you fix it, nothing will break.

## ☐ 8. List your businesses

```lua
Config.Businesses = {
    ['mechanic']   = { label = 'Bennys Motorworks' },
    ['realestate'] = { label = 'Dynasty 8 Real Estate' },
    ['tax']        = { label = 'Tax Agency' },
}
```

The key on the left must be the exact job name from `qb-core/shared/jobs.lua`
for that business. Add/remove/rename entries to match the businesses you
actually want on the tablet.

## ☐ 9. (Recommended) Hook up business deposits/withdrawals

By default the Businesses tab will show the live balance and staff roster
correctly, but the "money in/out" history will be empty until your
boss-menu/society script tells the tablet when money moves. Find wherever
your boss menu handles deposits/withdrawals and add:

```lua
exports['pv-govtablet']:RecordBusinessTransaction('mechanic', 'in', 2500, 'sale', 'Vehicle repair - John Smith')
exports['pv-govtablet']:RecordBusinessTransaction('mechanic', 'out', 1200, 'payroll', 'Weekly payroll run')
```

(`'mechanic'` → the job key, `'in'`/`'out'` → direction, then amount,
category, reason.) If you skip this, everything else still works — you
just won't see business transaction history.

## ☐ 10. Set the High Risk Payment thresholds (optional but recommended)

```lua
Config.HighRiskPayments = {
    Enabled          = true,
    DepositThreshold = 900000,  -- flag deposits this big or bigger
    VehicleThreshold = 400000,  -- flag vehicle purchases this big or bigger
    VehicleReasonKeywords = { 'vehicle', 'showroom', 'dealership' },
    IgnoreReasonKeywords  = { 'paycheck', 'salary', 'gov-tablet' },
}
```

This works automatically with no extra integration — just adjust the dollar
amounts to whatever counts as "suspicious" on your server. If your vehicle
shop resource uses a different word than "vehicle/showroom/dealership" when
it takes money, check with whoever made it and add that word to
`VehicleReasonKeywords`, otherwise vehicle purchases won't get tagged
correctly (they'll still get flagged as a generic large deposit instead,
just less precisely labeled).

## ☐ 11. (Optional) Turn on Discord logging

```lua
Config.Webhook       = 'https://discord.com/api/webhooks/...'
Config.WebhookName    = 'Government Tablet'
Config.WebhookAvatar  = 'https://i.imgur.com/3uSAuRD.png'
```

Leave `Config.Webhook` empty (`''`) if you don't want this — everything
still gets logged in-game either way, this just also mirrors it to Discord.

## ☐ 12. (Optional) Turn on automatic citizen photos

Requires the [screenshot-basic](https://github.com/citizenfx/screenshot-basic)
resource to be installed and running, plus a Discord webhook for it to
upload to:

```lua
Config.AutoPhoto = {
    Enabled  = true,
    Webhook  = 'https://discord.com/api/webhooks/...',  -- required for this feature
}
```

If you don't have `screenshot-basic` or don't want this, set
`Config.AutoPhoto.Enabled = false` — staff can still set photos by hand from
the tablet.

## ☐ 13. Restart and test

In your server console:

```
refresh
ensure pv-govtablet
```

Then in-game, as a character whose job is in `Config.Jobs`, type
`/govtablet` (or use the item). You should see the tablet open with a
sidebar matching that job's permissions.

---

## Quick troubleshooting

| Problem | Likely cause |
|---|---|
| "You are not authorized to use this device" | Your character's job isn't in `Config.Jobs`, or your grade is below `minGrade` |
| Tablet opens but a tab is missing | That job's `permissions` table has that feature set to `false` |
| Businesses all show $0 | `Config.Bridge.Business` table/column names don't match your money script |
| No vehicles/houses show up | `Config.Bridge.Garage` / `Config.Bridge.Housing` table/column names don't match your scripts |
| Business transaction history always empty | Nobody is calling `RecordBusinessTransaction` yet — see step 9 |
| High risk flags never appear | `Config.HighRiskPayments.Enabled` is `false`, or your thresholds are higher than any real transaction on your server |
