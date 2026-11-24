/* =============================================================================
   01_create_database.sql
   Purpose     : Create the School Management database with the project-wide
                 collation and database options.
   Dependencies: None. Requires SQLCMD mode (uses $(DatabaseName)).
   Run order   : 1 of 12 (see 00_run_all.sql)
   Idempotent  : Yes. CREATE runs only if the database does not exist; each
                 option is changed only when it differs from the target value.
   Notes       : No file paths are hard-coded; data/log files go to the
                 instance default locations.
                 Collation Arabic_100_CI_AI_SC: Arabic sort rules, case- and
                 accent-insensitive (also ignores Arabic diacritics/tashkeel),
                 supplementary-character aware.
   ============================================================================= */
USE master;
GO

IF DB_ID(N'$(DatabaseName)') IS NULL
BEGIN
    CREATE DATABASE [$(DatabaseName)] COLLATE Arabic_100_CI_AI_SC;
END;
GO

IF (SELECT compatibility_level FROM sys.databases WHERE name = N'$(DatabaseName)') <> 160
    ALTER DATABASE [$(DatabaseName)] SET COMPATIBILITY_LEVEL = 160;
GO

IF (SELECT recovery_model_desc FROM sys.databases WHERE name = N'$(DatabaseName)') <> N'FULL'
    ALTER DATABASE [$(DatabaseName)] SET RECOVERY FULL;
GO

-- READ_COMMITTED_SNAPSHOT needs exclusive access; only this project's database
-- is affected, and only when the option is not already on.
IF (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = N'$(DatabaseName)') = 0
    ALTER DATABASE [$(DatabaseName)] SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO

IF (SELECT is_query_store_on FROM sys.databases WHERE name = N'$(DatabaseName)') = 0
    ALTER DATABASE [$(DatabaseName)] SET QUERY_STORE = ON;
GO

ALTER DATABASE [$(DatabaseName)] SET QUERY_STORE (OPERATION_MODE = READ_WRITE);
GO

USE [$(DatabaseName)];
GO

SELECT name, collation_name, compatibility_level, recovery_model_desc,
       is_read_committed_snapshot_on, is_query_store_on
FROM   sys.databases
WHERE  name = DB_NAME();
GO
