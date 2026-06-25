-- ============================================================
-- OVI - Onderworld Connection Interface
-- Full database schema. Import this once via phpMyAdmin / HeidiSQL /
-- mysql cli on your server's database before starting the resource.
--
-- Everything is keyed by phone IMEI, never by citizenid - the phone
-- itself is the criminal identity, not the player.
-- ============================================================

CREATE TABLE IF NOT EXISTS `ovi_phones` (
    `imei`            VARCHAR(20)  NOT NULL,
    `phone_number`    VARCHAR(20)  NOT NULL,
    `pin`             VARCHAR(10)  DEFAULT NULL,
    `alias`           VARCHAR(50)  DEFAULT NULL,
    `phone_type`      VARCHAR(30)  NOT NULL,
    `ovi_installed`   TINYINT(1)   NOT NULL DEFAULT 0,
    `owner_citizenid` VARCHAR(50)  DEFAULT NULL,
    `reputation`      INT          NOT NULL DEFAULT 0,
    `heat`            INT          NOT NULL DEFAULT 0,
    `pin_attempts`    INT          NOT NULL DEFAULT 0,
    `locked_until`    INT          NOT NULL DEFAULT 0,
    `wiped`           TINYINT(1)   NOT NULL DEFAULT 0,
    `created_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`imei`),
    UNIQUE KEY `uniq_phone_number` (`phone_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ovi_clients_global` (
    `contact_id`      VARCHAR(20)  NOT NULL,
    `full_name`       VARCHAR(60)  NOT NULL,
    `number`          VARCHAR(20)  NOT NULL,
    `personality`     VARCHAR(30)  NOT NULL,
    `preferred_drug`  VARCHAR(30)  NOT NULL,
    `quantity_min`    INT          NOT NULL DEFAULT 1,
    `quantity_max`    INT          NOT NULL DEFAULT 5,
    `risk_level`      VARCHAR(20)  NOT NULL DEFAULT 'low',
    `shared`          TINYINT(1)   NOT NULL DEFAULT 0,
    `status`          VARCHAR(20)  NOT NULL DEFAULT 'active',
    `ghost_until`     INT          NOT NULL DEFAULT 0,
    `referral_count`  INT          NOT NULL DEFAULT 0,
    `created_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`contact_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Per-phone relationship to a global client (trust/loyalty are per
-- phone<->contact pair, not global, so stealing a phone steals the relationship).
CREATE TABLE IF NOT EXISTS `ovi_contacts` (
    `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `phone_imei`      VARCHAR(20)  NOT NULL,
    `contact_id`      VARCHAR(20)  NOT NULL,
    `trust`           INT          NOT NULL DEFAULT 0,
    `loyalty`         INT          NOT NULL DEFAULT 0,
    `deliveries_done` INT          NOT NULL DEFAULT 0,
    `blacklisted`     TINYINT(1)   NOT NULL DEFAULT 0,
    `burned`          TINYINT(1)   NOT NULL DEFAULT 0,
    `last_interaction` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_phone_contact` (`phone_imei`, `contact_id`),
    KEY `idx_phone_imei` (`phone_imei`),
    KEY `idx_contact_id` (`contact_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ovi_messages` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `phone_imei` VARCHAR(20)  NOT NULL,
    `contact_id` VARCHAR(20)  NOT NULL,
    `sender`     VARCHAR(10)  NOT NULL DEFAULT 'client', -- 'client' | 'player'
    `message`    TEXT         NOT NULL,
    `hidden`     TINYINT(1)   NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_phone_imei` (`phone_imei`),
    KEY `idx_phone_contact` (`phone_imei`, `contact_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ovi_deliveries` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `phone_imei`  VARCHAR(20)  NOT NULL,
    `contact_id`  VARCHAR(20)  NOT NULL,
    `drug`        VARCHAR(30)  NOT NULL,
    `quantity`    INT          NOT NULL,
    `price`       INT          NOT NULL,
    `status`      VARCHAR(20)  NOT NULL DEFAULT 'pending', -- pending|success|failed|timeout|trap|robbed
    `location`    VARCHAR(120) DEFAULT NULL,
    `dead_drop`   TINYINT(1)   NOT NULL DEFAULT 0,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_phone_imei` (`phone_imei`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ovi_gps_logs` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `phone_imei` VARCHAR(20)  NOT NULL,
    `x`          FLOAT        NOT NULL,
    `y`          FLOAT        NOT NULL,
    `z`          FLOAT        NOT NULL,
    `label`      VARCHAR(60)  DEFAULT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_phone_imei` (`phone_imei`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ovi_notes` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `phone_imei` VARCHAR(20)  NOT NULL,
    `text`       TEXT         NOT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_phone_imei` (`phone_imei`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ovi_complaints` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `phone_imei`  VARCHAR(20)  NOT NULL,
    `contact_id`  VARCHAR(20)  NOT NULL,
    `severity`    VARCHAR(10)  NOT NULL DEFAULT 'minor',
    `expires_at`  INT          NOT NULL DEFAULT 0,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_phone_imei` (`phone_imei`),
    KEY `idx_contact_id` (`contact_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ovi_referrals` (
    `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `parent_contact_id` VARCHAR(20)  NOT NULL,
    `new_contact_id`    VARCHAR(20)  NOT NULL,
    `phone_imei`        VARCHAR(20)  NOT NULL,
    `created_at`        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_parent` (`parent_contact_id`),
    KEY `idx_phone_imei` (`phone_imei`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ovi_traps` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(50)  NOT NULL,
    `phone_imei`  VARCHAR(20)  DEFAULT NULL,
    `result`      VARCHAR(20)  NOT NULL, -- won|lost|fled
    `loot`        TEXT         DEFAULT NULL,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ovi_clones` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `source_imei`  VARCHAR(20)  NOT NULL,
    `backup_data`  LONGTEXT     NOT NULL,
    `citizenid`    VARCHAR(50)  NOT NULL,
    `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_source_imei` (`source_imei`),
    KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ovi_heat_log` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `phone_imei` VARCHAR(20)  NOT NULL,
    `amount`     INT          NOT NULL,
    `reason`     VARCHAR(50)  NOT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_phone_imei` (`phone_imei`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ovi_suppliers` (
    `drug`              VARCHAR(30)  NOT NULL,
    `citizenid`         VARCHAR(50)  NOT NULL,
    `stock`              INT          NOT NULL DEFAULT 0,
    `unlocked`           TINYINT(1)   NOT NULL DEFAULT 0,
    `last_restock`       INT          NOT NULL DEFAULT 0,
    `cooldown_until`     INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (`drug`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
