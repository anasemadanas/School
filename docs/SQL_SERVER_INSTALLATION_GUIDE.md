# SQL Server 2022 Installation & Deployment Guide

## 1. Install SQL Server 2022

| Edition | Use | Limits |
|---|---|---|
| **Developer** | Development and testing (free; all features) | Not licensed for production |
| **Express** | Small deployments, validation (free) | 10 GB per database, about 1.4 GB buffer pool, 4 cores. This is fine for a few thousand students; move to Standard as volume grows (see FUTURE_EXPANSION.md). |
| **Standard / Enterprise** | Production | Licensed |

Everything this project uses (temporal tables, Query Store, filtered indexes, RCSI, inline TVFs, JSON functions) is available in **every** edition, Express included.

### Option A: installer (GUI)
1. Download SQL Server 2022 (Developer or Express) from Microsoft.
2. Choose **Basic** or **Custom**. Enable *Database Engine Services*.
3. Authentication: Windows authentication, or Mixed mode with a strong `sa` password if non-Windows clients need it. Add your Windows account as administrator.
4. Server collation: any value works. The database sets its own collation (`Arabic_100_CI_AI_SC`). Procedures use table variables, which take the database collation, and the scripts' `#temp` tables declare `COLLATE DATABASE_DEFAULT`, so the tempdb collation never causes a conflict.
5. Apply the latest Cumulative Update.

### Option B: winget (used for this project's validation)
```bash
winget install --id Microsoft.SQLServer.2022.Express --exact --silent --accept-package-agreements
```
```bash
winget install --id Microsoft.Sqlcmd --exact --silent
```
This creates the named instance `.\SQLEXPRESS`. Accept the UAC prompt when it appears.

## 2. Install the tools

- **SSMS** (SQL Server Management Studio 20 or later): `winget install --id Microsoft.SQLServerManagementStudio.21` or the Microsoft download page.
- **sqlcmd**: the Go-based `sqlcmd` (winget `Microsoft.Sqlcmd`, shown above) or the classic ODBC sqlcmd. Both support `:r`, `:setvar` and `:on error`.
- *(Optional, for `tools/*.py`)*: Python 3.10+, `pip install pyodbc`, and *ODBC Driver 17 or 18 for SQL Server*.

## 3. Deploy with sqlcmd (command line)

`00_run_all.sql` uses relative `:r` paths, so **run it from the `sql/` folder**:

```bash
cd sql
```
```bash
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -b -v DatabaseName=SchoolManagement -i 00_run_all.sql
```

Flags:
- `-E` Windows authentication (use `-U login -P ...` for SQL authentication).
- `-C` trust the server certificate (local instance).
- `-b` stop with a non-zero exit code on error.
- `-v DatabaseName=...` sets the target database. Use `SchoolManagement_<suffix>` for a scratch copy.

> The Go sqlcmd sometimes can't reach `.\SQLEXPRESS` through the default shared-memory pipe. The `lpc:` (shared memory) or `np:\\.\pipe\MSSQL$SQLEXPRESS\sql\query` (named pipes) prefixes connect reliably. On a remote or TCP-enabled server use `-S host,port`.

PowerShell wrapper (refuses any database name other than `SchoolManagement[_suffix]`; `-Clean` drops and recreates that database):

```bash
pwsh ./tools/deploy.ps1 -Server "lpc:.\SQLEXPRESS" -DatabaseName SchoolManagement_Validation -Clean -LogFile deploy.log
```

## 4. Deploy with SSMS

1. Connect to the instance.
2. **File → Open** `sql/00_run_all.sql`. Open it from the `sql/` folder so the relative `:r` paths resolve. If SSMS resolves them against another directory, replace `:r 01_…` with full paths.
3. **Query → SQLCMD Mode** (this is required).
4. Uncomment the line `-- :setvar DatabaseName SchoolManagement` (`:setvar` overrides `-v`, which is why it is commented out by default).
5. Press **F5**. The output ends with the validation **SUMMARY** and `All mandatory validation checks passed.`

To run one script on its own, keep SQLCMD mode on and add `:setvar DatabaseName SchoolManagement` at the top of the query window.

## 5. Production notes

- Remove the `:r 11_sample_data.sql` line, or keep it only for demos. Script 11 skips itself if the sample school already exists.
- Create an application login and user with `EXECUTE` on the module schemas and `SELECT` on the views only. Don't grant direct DML on tables. Grant no write access on the `audit` schema to anyone except the procedures (ownership chaining).
- The application must run this after opening each connection:
  ```sql
  EXEC sys.sp_set_session_context @key = N'UserAccountId', @value = @CurrentUserId;
  ```
- Configure backups before go-live (see the schedule in FUTURE_EXPANSION.md §5). The database is created in the FULL recovery model, so **log backups are required** or the log will grow without limit.

## 6. Re-running and upgrading

- Every script is idempotent. Running `00_run_all.sql` again on an existing database changes nothing; this was verified with a before/after catalog fingerprint.
- Schema changes go in the numbered scripts (an `IF NOT EXISTS` / `CREATE OR ALTER` pattern). For changes that alter existing columns, add a migration script; don't edit a deployed `CREATE TABLE`.

## 7. Verify a deployment

```bash
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -v DatabaseName=SchoolManagement -i 12_validation_queries.sql
```
```bash
python tools/verify_physical_erd.py --catalog "DRIVER={ODBC Driver 17 for SQL Server};SERVER=.\SQLEXPRESS;DATABASE=SchoolManagement;Trusted_Connection=yes;"
```
