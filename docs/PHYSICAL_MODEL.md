# Physical Model (SQL Server 2022)

**Source of truth:** `sql/03_create_tables.sql` through `sql/06_indexes.sql`.

- **Diagrams:** [diagrams/physical/modules/*.puml](../diagrams/physical/modules) contain every column, type, NULL/NOT NULL, IDENTITY, PK, FK, UQ, CK, DF and index. [master_physical.puml](../diagrams/physical/master_physical.puml) is an **overview** showing only key columns and relationships.
- **Per-table detail:** [TABLE_CATALOG.md](TABLE_CATALOG.md).
- **Verification:** the diagrams are generated from the scripts and checked against the deployed catalog by `tools/verify_physical_erd.py`, which passed with 0 mismatches. See [VALIDATION_REPORT.md](VALIDATION_REPORT.md).

## Database options (`01_create_database.sql`)

| Option | Value |
|---|---|
| Collation | `Arabic_100_CI_AI_SC` |
| Compatibility level | 160 (SQL Server 2022) |
| Recovery model | FULL |
| READ_COMMITTED_SNAPSHOT | ON |
| Query Store | ON (READ_WRITE) |
| File paths | none hard-coded; instance defaults are used |

## Type conventions

| Use | Type |
|---|---|
| Surrogate keys | `INT IDENTITY(1,1)`; `BIGINT IDENTITY(1,1)` for AttendanceSessions, AttendanceRecords, AssessmentResults, ReportCardLines, Invoices, InvoiceLines, CreditNotes, Payments, PaymentAllocations, AuditEvents, SecurityEvents |
| Text | `NVARCHAR(n)` with explicit lengths. `NVARCHAR(MAX)` is used only for `audit.AuditEvents.OldValues/NewValues` (JSON row images of arbitrary width, validated with ISJSON). |
| Codes (ISO, status) | `NVARCHAR(2/3/20)` with CHECK constraints |
| Money | `DECIMAL(19,4)` |
| Percent / score | `DECIMAL(7,4)` / `DECIMAL(9,3)` |
| Dates | `DATE` for date-only values; `DATETIME2(3)` for audit timestamps (UTC, `SYSUTCDATETIME()`); `DATETIME2(7)` for temporal period columns; `TIME(0)` for periods |
| Flags | `BIT` |
| Concurrency | `RowVer ROWVERSION` on 13 tables |

## Naming (all names explicit, none system-generated, as verified)

| Object | Pattern | Example |
|---|---|---|
| Primary key | `PK_<Schema>_<Table>` | `PK_people_Persons` |
| Foreign key | `FK_<Child>_<Parent>[_<Column>]` | `FK_Sections_Teachers_HomeroomTeacherId` |
| Unique | `UQ_<Table>_<Columns>` | `UQ_Enrollments_StudentId_AcademicYearId` |
| Check | `CK_<Table>_<Rule>` | `CK_Payers_ExactlyOne` |
| Default | `DF_<Table>_<Column>` | `DF_Invoices_InvoiceStatus` |
| Index | `IX_<Table>_<Purpose or Columns>` | `IX_AttendanceRecords_Enrollment_Date` |
| History-table clustered index | Renamed by `06` from the auto-generated `ix_<Name>` | `IX_PersonsHistory_Period` |

## Script layering

| Script | Content |
|---|---|
| 03 | Tables, columns, types, nullability, IDENTITY, ROWVERSION, PERIOD columns. No constraints. |
| 04 | PKs (clustered), then the UNIQUE keys that composite FKs reference, then all FKs |
| 05 | UNIQUE, CHECK and DEFAULT constraints, then `SYSTEM_VERSIONING = ON` (which needs the PK) |
| 06 | Nonclustered and filtered indexes; renames the history tables' clustered indexes |

## Indexing strategy

1. **Every FK has a supporting index whose leading key column is the FK's first column.** This is either a PK/UQ index or a dedicated `IX_`. The validation query reports 0 FKs without one.
2. **Access-path (composite / covering) indexes:**

   | Access path | Index |
   |---|---|
   | Attendance by student + date | `IX_AttendanceRecords_Enrollment_Date (EnrollmentId, SessionDate) INCLUDE (AttendanceStatusId, MinutesLate)` |
   | Attendance by section + date | `IX_AttendanceRecords_Section_Date (SectionId, SessionDate) INCLUDE (EnrollmentId, AttendanceStatusId)` |
   | Results by assessment | `UQ_AssessmentResults_AssessmentId_EnrollmentId` |
   | Results by student | `IX_AssessmentResults_EnrollmentId INCLUDE (AssessmentId, Score, IsAbsent, IsExempt)` |
   | Payments by payer + date | `IX_Payments_Payer_PaymentDate INCLUDE (Amount, PaymentStatus)` |
   | Payments by branch + date | `IX_Payments_Branch_PaymentDate` |
   | Payments by student | `IX_PaymentAllocations_InvoiceId` → `IX_Invoices_Enrollment_InvoiceDate` |
   | Invoices by payer / enrollment / branch + date | covering `IX_Invoices_*` |
   | Section roster | `IX_SectionAssignments_Section_Year INCLUDE (EnrollmentId, StartDate, EndDate)` |
   | Room clash check | `IX_TimetableEntries_Room_Day_Period` |
   | Audit by entity / user / time | `IX_AuditEvents_*` |
   | Name search | `IX_Persons_NameEn`, `IX_Persons_NameAr` |

3. **Filtered indexes:**
   - **Business rules** (filtered UNIQUE): one open section assignment per enrollment; one active year per school; one published timetable per section/term; one published report card per enrollment/term; one primary-contact guardian per student; one primary contact per person and type; one payer row per guardian / sponsor; no duplicate live invoice per enrollment + installment + payer; no double-posted bank or eFAWATEERcom reference.
   - **Performance:** `IX_Invoices_Open_DueDate` covers only `Issued`/`PartiallyPaid` invoices (the receivables worklist stays small however much history accumulates).

## Composite foreign keys used for integrity

| FK | Guarantees |
|---|---|
| `FK_SectionAssignments_Enrollments (EnrollmentId, AcademicYearId)` and `FK_SectionAssignments_Sections (SectionId, AcademicYearId)` | A student can only be placed in a section of the same academic year |
| `FK_AttendanceRecords_AttendanceSessions (AttendanceSessionId, SessionDate, SectionId)` | The denormalised date and section on a record always match its session |

During development this composite FK caught a real procedure bug: a stale OUTPUT-parameter value was reused as a session id. See [VALIDATION_REPORT.md](VALIDATION_REPORT.md).

## Temporal tables

| Current table | History table | Columns |
|---|---|---|
| people.Persons | audit.PersonsHistory | `SysStartTime` / `SysEndTime` DATETIME2(7), GENERATED ALWAYS, **HIDDEN** (excluded from `SELECT *`) |
| enrollment.Enrollments | audit.EnrollmentsHistory | same |
| assessment.AssessmentResults | audit.AssessmentResultsHistory (+ `IX_AssessmentResultsHistory_AssessmentResultId`) | same |
| finance.FeeStructureItems | audit.FeeStructureItemsHistory | same |

`audit.vw_GradeChangeHistory` uses `FOR SYSTEM_TIME ALL` to list every version of every result.
