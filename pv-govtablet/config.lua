Config = {}

Config.Debug = false

-- How the tablet is opened
Config.Command  = 'govtablet'      -- /govtablet
Config.UseItem  = true             -- also allow opening via item
Config.Item     = 'gov_tablet'

-- Discord webhook logging (leave empty to disable)
Config.Webhook       = ''
Config.WebhookName    = 'Government Tablet'
Config.WebhookAvatar  = 'https://i.imgur.com/3uSAuRD.png'

-- Anti-spam
Config.SearchCooldown   = 750      -- ms between searches per player
Config.SearchResultLimit = 25
Config.MaxActionsPerMinute = 20    -- generic write-action rate limit per player

-- Seizures of funds/vehicles/properties can require a judge's approval
-- unless the acting staff member already holds the `approveSeizure` permission.
Config.RequireJudgeApproval = true

-- Automatically captures a photo of each citizen's character (the model
-- they spawn in as) the first time they load in, so staff don't have to
-- manually set a photo URL. Requires the `screenshot-basic` resource
-- (https://github.com/citizenfx/screenshot-basic) and a Discord webhook
-- to upload the screenshot to - leave Webhook empty to disable and fall
-- back to the manual "Set Photo URL" button only. See README.md.
Config.AutoPhoto = {
    Enabled          = true,
    Resource         = 'screenshot-basic',
    Webhook          = '',     -- dedicated Discord webhook URL for photo uploads
    Delay            = 2500,   -- ms to wait after spawning before capturing, so the ped is fully streamed in
    RetakeEveryLogin = false,  -- if false, only auto-captures once per citizen (won't override a manually set photo)
}

-- Money "accounts" tracked on the QBCore player object (PlayerData.money).
-- Cash on hand is intentionally excluded - government staff have no
-- realistic way to know how much physical cash someone is carrying.
Config.MoneyTypes = { 'bank', 'crypto' }

-- High-risk payment detection. Every bank/crypto change on the QBCore
-- player object is recorded as a transaction (see Config.Bridge below and
-- bridge/sv_accounts.lua) and screened against these thresholds in real
-- time via the `QBCore:Server:OnMoneyChange` event - no polling involved,
-- so flags appear the instant the money moves and are pushed live to any
-- staff member with the `viewHighRisk` permission and the tablet open.
-- Other resources (drug systems, money laundering scripts, custom vehicle
-- shops, etc.) can also flag something explicitly regardless of amount via
-- exports['pv-govtablet']:FlagHighRiskTransaction(...) - see README.md.
Config.HighRiskPayments = {
    Enabled          = true,
    DepositThreshold = 900000,  -- single bank/crypto deposit >= this amount with no recognized source gets flagged
    VehicleThreshold = 400000,  -- single bank/crypto withdrawal >= this amount tagged as a vehicle purchase gets flagged
    -- Substrings (case-insensitive) of the `reason` argument QBCore passes
    -- to OnMoneyChange that identify a withdrawal as a vehicle purchase.
    -- Adjust to match whatever vehicle shop resource your server runs.
    VehicleReasonKeywords = { 'vehicle', 'showroom', 'dealership' },
    -- Substrings that are NEVER flagged even over threshold (legitimate,
    -- predictable income/expenses you don't want cluttering the queue).
    IgnoreReasonKeywords = { 'paycheck', 'salary', 'gov-tablet' },
}

-- Businesses tab. Each entry maps a QBCore.Shared.Jobs key to a
-- tablet-visible business profile. Staff roster, grades and pay are read
-- live from QBCore.Shared.Jobs and the `players` table - nothing here
-- needs to be duplicated. The linked bank account's live balance comes
-- from Config.Bridge.Business below; its deposit/withdrawal history only
-- populates once your boss-menu/society script calls the
-- `RecordBusinessTransaction` export - see README.md.
Config.Businesses = {
    ['mechanic']   = { label = 'Bennys Motorworks' },
    ['realestate'] = { label = 'Dynasty 8 Real Estate' },
    ['tax']        = { label = 'Tax Agency' },
}

-- Job / role permission matrix. `minGrade` is the minimum job grade level
-- required, `permissions` controls which actions that job is allowed to
-- perform. All of this is re-validated server side on every request.
Config.Jobs = {
    ['mayor'] = {
        label = 'Mayor',
        minGrade = 0,
        permissions = {
            search          = true,
            viewProfile     = true,
            viewFinance     = true,
            viewAssets      = true,
            viewCriminal    = true,
            editCriminal    = false,
            setPhoto        = true,
            freeze          = true,
            unfreeze        = true,
            hide            = true,
            reveal          = true,
            seizeFunds      = true,
            seizeVehicle    = true,
            releaseVehicle  = true,
            impoundVehicle  = true,
            seizeProperty   = true,
            restoreProperty = true,
            approveSeizure  = true,
            viewLogs        = true,
            viewHighRisk    = true,
            viewBusinesses  = true,
            viewAccountLookup = true,
        }
    },
    ['tax'] = {
        label = 'Tax Agency',
        minGrade = 0,
        permissions = {
            search          = true,
            viewProfile     = true,
            viewFinance     = true,
            viewAssets      = true,
            viewCriminal    = false,
            editCriminal    = false,
            setPhoto        = false,
            freeze          = true,
            unfreeze        = true,
            hide            = false,
            reveal          = false,
            seizeFunds      = true,
            seizeVehicle    = false,
            releaseVehicle  = false,
            impoundVehicle  = false,
            seizeProperty   = false,
            restoreProperty = false,
            approveSeizure  = false,
            viewLogs        = true,
            viewHighRisk    = true,
            viewBusinesses  = true,
            viewAccountLookup = true,
        }
    },
    ['government'] = {
        label = 'Government',
        minGrade = 0,
        permissions = {
            search          = true,
            viewProfile     = true,
            viewFinance     = true,
            viewAssets      = true,
            viewCriminal    = true,
            editCriminal    = false,
            setPhoto        = true,
            freeze          = false,
            unfreeze        = false,
            hide            = false,
            reveal          = false,
            seizeFunds      = false,
            seizeVehicle    = false,
            releaseVehicle  = false,
            impoundVehicle  = false,
            seizeProperty   = false,
            restoreProperty = false,
            approveSeizure  = false,
            viewLogs        = false,
            viewHighRisk    = false,
            viewBusinesses  = true,
            viewAccountLookup = false,
        }
    },
    ['doj'] = {
        label = 'Department of Justice',
        minGrade = 0,
        permissions = {
            search          = true,
            viewProfile     = true,
            viewFinance     = true,
            viewAssets      = true,
            viewCriminal    = true,
            editCriminal    = true,
            setPhoto        = false,
            freeze          = true,
            unfreeze        = true,
            hide            = false,
            reveal          = false,
            seizeFunds      = true,
            seizeVehicle    = true,
            releaseVehicle  = true,
            impoundVehicle  = true,
            seizeProperty   = true,
            restoreProperty = true,
            approveSeizure  = false,
            viewLogs        = true,
            viewHighRisk    = true,
            viewBusinesses  = false,
            viewAccountLookup = true,
        }
    },
    ['judge'] = {
        label = 'Judge',
        minGrade = 1,
        permissions = {
            search          = true,
            viewProfile     = true,
            viewFinance     = true,
            viewAssets      = true,
            viewCriminal    = true,
            editCriminal    = true,
            setPhoto        = false,
            freeze          = false,
            unfreeze        = false,
            hide            = false,
            reveal          = false,
            seizeFunds      = false,
            seizeVehicle    = false,
            releaseVehicle  = false,
            impoundVehicle  = false,
            seizeProperty   = false,
            restoreProperty = false,
            approveSeizure  = true,
            viewLogs        = true,
            viewHighRisk    = false,
            viewBusinesses  = false,
            viewAccountLookup = true,
        }
    },
}

-- Bridge configuration: adjust table/column names here if your housing or
-- garage resource uses a different schema. See README.md for details.
Config.Bridge = {
    Housing = {
        HousesTable   = 'player_houses',  -- qb-houses ownership table
        CitizenField  = 'citizenid',
        HouseField    = 'house',
        GarageField    = 'garage',
    },
    Garage = {
        VehicleTable  = 'player_vehicles', -- qb-core / qb-garages vehicle table
        CitizenField  = 'citizenid',
        PlateField    = 'plate',
        StateField    = 'state',           -- 0 = out, 1 = garage, 2 = impound
        ModelField    = 'vehicle',
    },
    -- Society/business balance table. qb-management's default schema is
    -- assumed here; adjust to match your society-money resource
    -- (qb-banking job accounts, qb-bossmenu, etc). If the table doesn't
    -- exist, businesses just show a $0 balance instead of erroring -
    -- deposit/withdrawal history still works via the RecordBusinessTransaction
    -- export regardless of whether this table is found.
    Business = {
        FundsTable  = 'management_funds',
        JobField    = 'job_name',
        AmountField = 'amount',
    },
}
