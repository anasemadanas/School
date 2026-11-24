/* =============================================================================
   02_create_schemas.sql
   Purpose     : Create all 15 module schemas (10 delivered, 5 reserved).
   Dependencies: 01_create_database.sql
   Run order   : 2 of 12
   Idempotent  : Yes (IF SCHEMA_ID(...) IS NULL).
   Notes       : The "identity" module is implemented as schema [iam] because
                 IDENTITY is a reserved T-SQL keyword (decision approved in
                 PROJECT_PLAN.md section 3).
                 The schemas hr, transport, library, inventory and
                 communication are created empty and reserved for future
                 expansion (see docs/FUTURE_EXPANSION.md).
   ============================================================================= */
USE [$(DatabaseName)];
GO

-- Delivered modules
IF SCHEMA_ID(N'organization') IS NULL EXEC (N'CREATE SCHEMA organization AUTHORIZATION dbo;');
IF SCHEMA_ID(N'iam')          IS NULL EXEC (N'CREATE SCHEMA iam AUTHORIZATION dbo;');
IF SCHEMA_ID(N'people')       IS NULL EXEC (N'CREATE SCHEMA people AUTHORIZATION dbo;');
IF SCHEMA_ID(N'academic')     IS NULL EXEC (N'CREATE SCHEMA academic AUTHORIZATION dbo;');
IF SCHEMA_ID(N'enrollment')   IS NULL EXEC (N'CREATE SCHEMA enrollment AUTHORIZATION dbo;');
IF SCHEMA_ID(N'timetable')    IS NULL EXEC (N'CREATE SCHEMA timetable AUTHORIZATION dbo;');
IF SCHEMA_ID(N'attendance')   IS NULL EXEC (N'CREATE SCHEMA attendance AUTHORIZATION dbo;');
IF SCHEMA_ID(N'assessment')   IS NULL EXEC (N'CREATE SCHEMA assessment AUTHORIZATION dbo;');
IF SCHEMA_ID(N'finance')      IS NULL EXEC (N'CREATE SCHEMA finance AUTHORIZATION dbo;');
IF SCHEMA_ID(N'audit')        IS NULL EXEC (N'CREATE SCHEMA audit AUTHORIZATION dbo;');
GO

-- Reserved for future expansion (empty schemas, no tables)
IF SCHEMA_ID(N'hr')            IS NULL EXEC (N'CREATE SCHEMA hr AUTHORIZATION dbo;');
IF SCHEMA_ID(N'transport')     IS NULL EXEC (N'CREATE SCHEMA transport AUTHORIZATION dbo;');
IF SCHEMA_ID(N'library')       IS NULL EXEC (N'CREATE SCHEMA library AUTHORIZATION dbo;');
IF SCHEMA_ID(N'inventory')     IS NULL EXEC (N'CREATE SCHEMA inventory AUTHORIZATION dbo;');
IF SCHEMA_ID(N'communication') IS NULL EXEC (N'CREATE SCHEMA communication AUTHORIZATION dbo;');
GO

SELECT s.name AS SchemaName
FROM   sys.schemas AS s
WHERE  s.name IN (N'organization', N'iam', N'people', N'academic', N'enrollment',
                  N'timetable', N'attendance', N'assessment', N'finance', N'audit',
                  N'hr', N'transport', N'library', N'inventory', N'communication')
ORDER BY s.name;
GO
