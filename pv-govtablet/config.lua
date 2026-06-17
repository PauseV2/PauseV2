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

-- Money "accounts" tracked on the QBCore player object (PlayerData.money)
Config.MoneyTypes = { 'cash', 'bank', 'crypto' }

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
}
