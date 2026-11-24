# Database Architecture

## 1. Context

This is the database layer of a School Management System for a K-12 private school group in Jordan / the Middle East. It is bilingual (Arabic and English) and supports several branches.

- **Target:** Microsoft SQL Server 2022 (compatibility level 160), T-SQL only.
- **Shape:** one database (`SchoolManagement`) with **one schema per module**.

## 2. Modules and schemas

| Schema | Status | Responsibility | Tables |
|---|---|---|---|
| `organization` | Delivered | Schools, branches, buildings, rooms, departments, countries, document numbering | 8 |
| `iam` | Delivered | User accounts, roles, permissions, branch-scoped grants. This is the "identity" module, renamed because `IDENTITY` is a reserved keyword. | 5 |
| `people` | Delivered | Person supertype, Student/Guardian/Employee/Teacher subtypes, contacts, addresses, IDs, guardianship | 11 |
| `academic` | Delivered | Academic years, terms, holidays, grade levels, programs, subjects, curriculum, sections, teaching assignments | 9 |
| `enrollment` | Delivered | Applications, yearly enrollments, section placements, elective choices | 5 |
| `timetable` | Delivered | Bell schedules, periods, versioned timetables and entries | 4 |
| `attendance` | Delivered | Roll-call sessions and records | 3 |
| `assessment` | Delivered | Grading scales, weights, assessments, results, report cards | 8 |
| `finance` | Delivered | Currencies, fee structures, discounts, payers (category), invoices, credit notes, payments | 16 |
| `audit` | Delivered | Business-event log, security log, temporal history tables | 2 + 4 history |
| `hr`, `transport`, `library`, `inventory`, `communication` | Reserved | Empty schemas reserved for future expansion; see [FUTURE_EXPANSION.md](FUTURE_EXPANSION.md) | 0 |

Totals for the delivered schemas: **75 tables, 890 columns, 126 foreign keys, 63 UNIQUE constraints, 94 CHECK constraints, 356 DEFAULT constraints, 115 nonclustered and history indexes, 12 views, 18 procedures, 3 table types and 8 inline table-valued functions.** These counts come from the deployed catalog; see [VALIDATION_REPORT.md](VALIDATION_REPORT.md).

## 3. Dependency direction

```
organization ◀── academic ◀── enrollment ◀── attendance
     ▲   ▲          ▲   ▲          ▲   ▲        assessment
     │   └── people ┘   └ timetable┘   └──────── finance
     │        ▲                                       │
     └─ iam ──┘          audit (soft references only, depends on nothing)
```

- `people` depends only on `organization`.
- `academic` depends on `organization`, `people` (teachers) and `assessment.GradingScales`.
- Transactional modules (`enrollment`, `attendance`, `assessment`, `finance`) depend on `academic` and `people`.
- `audit` uses **soft references** (schema, table, key, user id). It never blocks archiving or deletes, and it can be moved to its own filegroup or database later.

The full matrix is in [DATABASE_RELATIONSHIPS.md](DATABASE_RELATIONSHIPS.md#cross-module-dependency-summary).

## 4. Key design decisions

| Decision | Choice | Reason |
|---|---|---|
| `identity` schema name | `iam` | `IDENTITY` is reserved; a bracketed name is fragile in every tool and script |
| Supertype/subtype | Class-table inheritance with shared PK | Supports **overlapping** roles. Subtypes keep NOT NULL role attributes, and a future `hr` module could extend Employee without changes. See [CATEGORICAL_MODEL.md](CATEGORICAL_MODEL.md). |
| Money | `DECIMAL(19,4)` everywhere | JOD, KWD, BHD and OMR have 3 minor digits; the 4th digit absorbs installment and percentage splits before rounding. Rounding to the currency's `MinorUnits` happens once, at invoice issue. |
| Percentages / scores | `DECIMAL(7,4)` / `DECIMAL(9,3)` | Exact arithmetic; no FLOAT anywhere |
| Collation | `Arabic_100_CI_AI_SC` (database default) | Arabic sort order, case-insensitive English, accent-insensitive Latin text, supplementary characters. **Correction to the plan:** testing showed that no SQL Server collation ignores Arabic tashkeel or alef/hamza variants, so `people.fn_SearchPersons` normalises Arabic explicitly. |
| Keys | INT IDENTITY; BIGINT IDENTITY for attendance, assessment results, report-card lines, finance transactions and audit logs | High-volume tables could approach the INT range over decades at tens of thousands of students; everything else stays small |
| Business numbers | `organization.DocumentNumberSeries`, incremented with UPDLOCK/HOLDLOCK inside the issuing transaction | No SEQUENCE objects (project rule). Numbers are per document type, branch and year, e.g. `INV-AMM-2026-000017`. |
| History | System-versioned temporal tables for Persons, Enrollments, AssessmentResults and FeeStructureItems, with history in `audit` | Grade changes, fee changes and identity corrections must be explainable. Invoices and payments are immutable instead (credit notes, reversal status), and attendance is logged through audit events because it is too high-volume to version. |
| Concurrency | READ_COMMITTED_SNAPSHOT ON; `RowVer ROWVERSION` on tables edited concurrently | Readers don't block writers; the application can use optimistic concurrency |
| Audit columns | CreatedAt/By and UpdatedAt/By; the *By* columns default from `SESSION_CONTEXT(N'UserAccountId')` | No FK to `iam` (soft reference), which avoids 140 extra FKs and indexes and a circular dependency |
| Deletes | ON DELETE NO ACTION by default. CASCADE only for role-permission links, contacts, addresses and timetable entries. | Financial, academic, attendance and enrollment history never cascades |
| Status values | CHECK constraints on short NVARCHAR codes | Procedures depend on exact values. User-extensible lists are lookup tables instead. |
| Capacity | Optional `Sections.Capacity` and `Rooms.SeatCapacity` only | **No system-wide student limit anywhere**. A section's capacity is checked by `usp_AssignSection`, and an authorised user can override it. |

## 5. Programming model

- **Writes go through procedures** for every multi-step business operation:
  - All procedures use `SET NOCOUNT ON`, `SET XACT_ABORT ON`, TRY/CATCH with THROW, and explicit transactions.
  - Error numbers are grouped by module: 50xxx common, 51xxx enrollment, 52xxx timetable, 53xxx attendance, 54xxx assessment, 55xxx finance.
- **Table-valued parameters** carry whole-section attendance, assessment results and payment allocations in one round trip.
- **Reads** use views (rosters, balances, statements, timetable, grade history) and inline TVFs (school days, attendance summary, weighted subject scores, fee schedule, payer balance, Arabic-aware person search).
- **Caller identity:** the application runs `EXEC sys.sp_set_session_context @key = N'UserAccountId', @value = @id;` after opening each connection. Defaults and procedures stamp CreatedBy/UpdatedBy and audit events from it.

## 6. Security model (database side)

- Application roles and permissions live in `iam`. Grants can be scoped to one branch.
- Recommended deployment:
  - The application connects with a login that is granted `EXECUTE` on the procedure schemas and `SELECT` on views. It gets no direct table DML.
  - DBAs use separate logins.
  - PII (`people.PersonIdentityDocuments`, medical notes) is restricted, with Dynamic Data Masking / Always Encrypted listed as possible extensions in [FUTURE_EXPANSION.md](FUTURE_EXPANSION.md).
- Passwords are never stored. The column holds an application-produced hash, or authentication is delegated to an external identity provider (`AuthProvider`, `ExternalSubjectId`).

## 7. Deployment

`sql/00_run_all.sql` runs scripts 01–12 in order (SQLCMD mode). Every script is idempotent, and a second run makes no changes (this was verified). See [SQL_SERVER_INSTALLATION_GUIDE.md](SQL_SERVER_INSTALLATION_GUIDE.md).
