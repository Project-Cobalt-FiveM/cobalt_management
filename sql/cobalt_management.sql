CREATE TABLE IF NOT EXISTS `management_orgs` (
  `name` VARCHAR(50) NOT NULL,
  `seq` INT UNSIGNED NOT NULL DEFAULT 0,
  `settings` JSON DEFAULT NULL,
  `gang` JSON DEFAULT NULL,
  `vault_balance` INT UNSIGNED NOT NULL DEFAULT 0,
  `vault_log` JSON DEFAULT NULL,
  `announcements` JSON DEFAULT NULL,
  `bonuses` JSON DEFAULT NULL,
  `requests` JSON DEFAULT NULL,
  `fleet` JSON DEFAULT NULL,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `management_members` (
  `citizenid` VARCHAR(50) NOT NULL,
  `job` JSON DEFAULT NULL,
  `gang` JSON DEFAULT NULL,
  `second_jobs` JSON DEFAULT NULL,
  `job_name` VARCHAR(50) AS (JSON_VALUE(`job`, '$.name')) STORED,
  `gang_name` VARCHAR(50) AS (JSON_VALUE(`gang`, '$.name')) STORED,
  `job_since` DATETIME DEFAULT NULL,
  `gang_since` DATETIME DEFAULT NULL,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`),
  KEY `job_name` (`job_name`),
  KEY `gang_name` (`gang_name`),
  CONSTRAINT `management_members_citizenid_fk` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `management_duty` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `job_name` VARCHAR(50) NOT NULL,
  `clock_in` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `clock_out` DATETIME DEFAULT NULL,
  `minutes` INT UNSIGNED DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid_job` (`citizenid`, `job_name`, `clock_out`),
  KEY `job_clock_in` (`job_name`, `clock_in`),
  CONSTRAINT `management_duty_citizenid_fk` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
