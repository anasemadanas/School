/* =============================================================================
   00_run_all.sql — deploys the whole School Management database in order.

   SQLCMD MODE IS REQUIRED (uses :setvar, :r, :on error).

   Command line (run from the sql/ folder so the :r paths resolve):
       sqlcmd -S <server> -E -C -b -v DatabaseName=SchoolManagement -i 00_run_all.sql

   SSMS: Query > SQLCMD Mode, open this file from the sql/ folder, uncomment the
   :setvar line below, then Execute (F5).
       (:setvar overrides -v, which is why it is commented out by default.)

   Re-running is safe: every script is idempotent.
   For a production deployment remove the 11_sample_data.sql line.
   ============================================================================= */
-- :setvar DatabaseName SchoolManagement
:on error exit

:r 01_create_database.sql
:r 02_create_schemas.sql
:r 03_create_tables.sql
:r 04_primary_foreign_keys.sql
:r 05_constraints.sql
:r 06_indexes.sql
:r 07_reference_data.sql
:r 08_views.sql
:r 09_stored_procedures.sql
:r 10_functions.sql
:r 11_sample_data.sql
:r 12_validation_queries.sql
