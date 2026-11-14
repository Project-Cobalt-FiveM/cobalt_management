CREATE TABLE IF NOT EXISTS `jobs` (
  `name` VARCHAR(50) NOT NULL,
  `open` TINYINT(1) NOT NULL DEFAULT 1,
  `settings` JSON DEFAULT NULL,
  `seq` INT UNSIGNED NOT NULL DEFAULT 0,
  `requests` JSON DEFAULT NULL,
  `announcements` JSON DEFAULT NULL,
  `bonuses` JSON DEFAULT NULL,
  `fleet` JSON DEFAULT NULL,
  `duty` JSON DEFAULT NULL,
  `payout_date` DATE DEFAULT NULL,
  `payout_total` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gangs` (
  `name` VARCHAR(50) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `founder` VARCHAR(50) DEFAULT NULL,
  `founded_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `permissions` JSON DEFAULT NULL,
  `seq` INT UNSIGNED NOT NULL DEFAULT 0,
  `vault_balance` INT UNSIGNED NOT NULL DEFAULT 0,
  `vault_log` JSON DEFAULT NULL,
  PRIMARY KEY (`name`),
  UNIQUE KEY `label` (`label`),
  KEY `founder` (`founder`),
  CONSTRAINT `gangs_founder_fk` FOREIGN KEY (`founder`) REFERENCES `players` (`citizenid`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
