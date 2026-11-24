# School Management System — Database (SQL Server 2022)

This is the database layer of a bilingual (Arabic / English), multi-branch K-12 school management system, written in T-SQL for Microsoft SQL Server 2022. It uses one database with one schema per module.

**Status:** complete as delivered. It covers `organization`, `iam` (the identity module), `people`, `academic`, `enrollment`, `timetable`, `attendance`, `assessment`, `finance` and `audit`. Five further schemas (`hr`, `transport`, `library`, `inventory`, `communication`) are created empty and reserved for future expansion. Validation results are in [docs/VALIDATION_REPORT.md](docs/VALIDATION_REPORT.md).

**No student limit:** nothing in the design caps the number of students. Only per-section and per-room capacity exist, as optional, configurable data.

## Quick start

```bash
cd sql
```
```bash
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -b -v DatabaseName=SchoolManagement -i 00_run_all.sql
```

To use SSMS instead, open `sql/00_run_all.sql`, enable **Query → SQLCMD Mode**, uncomment the `:setvar` line and press F5. Full instructions: [docs/SQL_SERVER_INSTALLATION_GUIDE.md](docs/SQL_SERVER_INSTALLATION_GUIDE.md).

## Repository layout

| Path | Content |
|---|---|
| [PROJECT_PLAN.md](PROJECT_PLAN.md) | Phase 0 requirements, assumptions, decisions, file plan |
| [sql/](sql) | **Source of truth.** `00_run_all.sql` plus scripts `01`–`12` (database, schemas, tables, keys, constraints, indexes, reference data, views, procedures, functions, sample data, validation) |
| [diagrams/](diagrams) | PlantUML at four levels: conceptual, logical, physical, categorical (EER). See [diagrams/README.md](diagrams/README.md). |
| [docs/](docs) | Architecture, models, table catalog, relationships, business rules, install guide, future expansion, validation report |
| [tools/](tools) | `deploy.ps1`, diagram and doc generators, the physical-ERD verifier. See [tools/README.md](tools/README.md). |

## Documentation

| Document | What it covers |
|---|---|
| [DATABASE_ARCHITECTURE.md](docs/DATABASE_ARCHITECTURE.md) | Modules, dependencies, key decisions, programming and security model |
| [CONCEPTUAL_MODEL.md](docs/CONCEPTUAL_MODEL.md) · [LOGICAL_MODEL.md](docs/LOGICAL_MODEL.md) · [PHYSICAL_MODEL.md](docs/PHYSICAL_MODEL.md) · [CATEGORICAL_MODEL.md](docs/CATEGORICAL_MODEL.md) | The four modelling levels |
| [TABLE_CATALOG.md](docs/TABLE_CATALOG.md) | Every table: purpose, columns, keys, indexes, expected growth (generated) |
| [DATABASE_RELATIONSHIPS.md](docs/DATABASE_RELATIONSHIPS.md) | All 126 foreign keys with cardinality and delete rule (generated) |
| [BUSINESS_RULES.md](docs/BUSINESS_RULES.md) | Each rule mapped to the constraint, procedure or application layer that enforces it |
| [SQL_SERVER_INSTALLATION_GUIDE.md](docs/SQL_SERVER_INSTALLATION_GUIDE.md) | Installing SQL Server 2022 and SSMS, deploying with SSMS or sqlcmd |
| [FUTURE_EXPANSION.md](docs/FUTURE_EXPANSION.md) | Possible extensions (reserved schemas), known limitations, scalability, archiving and partitioning thresholds, backup/RPO/RTO, HA |
| [VALIDATION_REPORT.md](docs/VALIDATION_REPORT.md) | What was run, with which commands, and the actual results |

## Main stored procedures

| Process | Procedure |
|---|---|
| Admission | `enrollment.usp_SubmitApplication`, `enrollment.usp_DecideApplication` |
| Enrollment / placement / withdrawal / rollover | `enrollment.usp_EnrollStudent`, `usp_AssignSection`, `usp_WithdrawStudent`, `usp_PromoteStudents` |
| Timetable | `timetable.usp_PublishTimetable` (teacher and room clash checks) |
| Attendance for a whole section (TVP) | `attendance.usp_RecordSectionAttendance` |
| Results (TVP), report cards | `assessment.usp_RecordResults`, `usp_GenerateReportCards`, `usp_PublishReportCards` |
| Invoicing, payments, corrections | `finance.usp_IssueInvoice`, `usp_RecordPayment` (TVP allocations or FIFO), `usp_IssueCreditNote`, `usp_CancelInvoice` |
