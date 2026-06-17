-- ============================================================
-- pv-govtablet :: database schema
-- Run this once against your QBCore database (e.g. via HeidiSQL,
-- phpMyAdmin or `mysql < install.sql`).
-- All tables are additive - nothing here touches qb-core/qb-houses/
-- qb-garages tables, so it is safe to install alongside any fork
-- of those resources.
-- ============================================================

CREATE TABLE IF NOT EXISTS `gt_logs` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `staff_citizenid` VARCHAR(50) NOT NULL,
    `staff_name` VARCHAR(100) NOT NULL,
    `staff_job` VARCHAR(50) NOT NULL,
    `action` VARCHAR(50) NOT NULL,
    `target_citizenid` VARCHAR(50) DEFAULT NULL,
    `details` TEXT DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_target` (`target_citizenid`),
    KEY `idx_staff` (`staff_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gt_citizen_photos` (
    `citizenid` VARCHAR(50) NOT NULL,
    `photo_url` TEXT DEFAULT NULL,
    `updated_by` VARCHAR(100) DEFAULT NULL,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Canonical criminal record store. Other MDT / police resources can push
-- records into this table via the `pv-govtablet:server:addCriminalRecord`
-- event or the `AddCriminalRecord` export - see README.md.
CREATE TABLE IF NOT EXISTS `gt_criminal_records` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `officer_name` VARCHAR(100) NOT NULL,
    `officer_citizenid` VARCHAR(50) DEFAULT NULL,
    `charges` TEXT NOT NULL,
    `fine` INT UNSIGNED NOT NULL DEFAULT 0,
    `sentence_months` INT UNSIGNED NOT NULL DEFAULT 0,
    `status` ENUM('active','served','warrant','fined','dismissed') NOT NULL DEFAULT 'active',
    `notes` TEXT DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tracks frozen / hidden state of a citizen's money "accounts"
-- (cash / bank / crypto). Read by the banking bridge and exported
-- for other resources (e.g. qb-banking) to check before allowing
-- a transaction.
CREATE TABLE IF NOT EXISTS `gt_account_freezes` (
    `citizenid` VARCHAR(50) NOT NULL,
    `account_type` ENUM('cash','bank','crypto') NOT NULL,
    `frozen` TINYINT(1) NOT NULL DEFAULT 0,
    `hidden` TINYINT(1) NOT NULL DEFAULT 0,
    `reason` TEXT DEFAULT NULL,
    `updated_by` VARCHAR(100) DEFAULT NULL,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `account_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Funds seizure audit history (separate from the freeze table so a
-- citizen can be frozen many times / have many seizures over time).
CREATE TABLE IF NOT EXISTS `gt_fund_seizures` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `account_type` ENUM('cash','bank','crypto') NOT NULL,
    `amount` INT UNSIGNED NOT NULL,
    `reason` TEXT NOT NULL,
    `seized_by` VARCHAR(100) NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Vehicle seizure / impound overlay. We never delete rows from your
-- garage resource's vehicle table - this is purely a status overlay
-- so the action is 100% reversible.
CREATE TABLE IF NOT EXISTS `gt_vehicle_seizures` (
    `plate` VARCHAR(15) NOT NULL,
    `citizenid` VARCHAR(50) DEFAULT NULL,
    `seized` TINYINT(1) NOT NULL DEFAULT 0,
    `impounded` TINYINT(1) NOT NULL DEFAULT 0,
    `reason` TEXT DEFAULT NULL,
    `updated_by` VARCHAR(100) DEFAULT NULL,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Property catalogue. qb-houses (and most forks) only store an
-- ownership row, not a label/location/price, so we keep a small
-- catalogue here that the housing bridge will fall back to. Populate
-- this with your server's house/apartment names - it is safe to leave
-- empty, the tablet will just show the raw house key as the label.
CREATE TABLE IF NOT EXISTS `gt_properties` (
    `house` VARCHAR(100) NOT NULL,
    `type` ENUM('house','apartment') NOT NULL DEFAULT 'house',
    `label` VARCHAR(150) DEFAULT NULL,
    `location` VARCHAR(150) DEFAULT NULL,
    `price` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`house`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Property seizure overlay, mirrors the vehicle seizure table. When a
-- property is seized we snapshot the original ownership row here so it
-- can be fully restored later, then remove the ownership row from the
-- housing resource's table.
CREATE TABLE IF NOT EXISTS `gt_property_seizures` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `house` VARCHAR(100) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `snapshot` TEXT DEFAULT NULL,
    `seized` TINYINT(1) NOT NULL DEFAULT 1,
    `reason` TEXT DEFAULT NULL,
    `seized_by` VARCHAR(100) NOT NULL,
    `resolved_by` VARCHAR(100) DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `restored_at` DATETIME DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_house` (`house`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Pending judge-approval queue for seizure actions when
-- Config.RequireJudgeApproval is enabled.
CREATE TABLE IF NOT EXISTS `gt_seizure_requests` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `type` ENUM('funds','vehicle','property') NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `payload` TEXT NOT NULL,
    `reason` TEXT NOT NULL,
    `requested_by` VARCHAR(50) NOT NULL,
    `requested_by_name` VARCHAR(100) NOT NULL,
    `status` ENUM('pending','approved','denied') NOT NULL DEFAULT 'pending',
    `resolved_by` VARCHAR(100) DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `resolved_at` DATETIME DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
