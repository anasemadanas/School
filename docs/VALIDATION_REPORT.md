# Validation Report (Phase 5)

Every result below comes from commands actually run on 2026-11-18 against the committed scripts. Nothing is estimated.

## Environment

| Item | Value |
|---|---|
| OS | Windows 11 Home 10.0.26200 |
| SQL Server | **Microsoft SQL Server 2022 (RTM) 16.0.1000.6, Express Edition (64-bit)**, instance `.\SQLEXPRESS`. Installed for this project with winget, with your approval. |
| sqlcmd | go-sqlcmd 1.10.0 (`C:\Program Files\SqlCmd\sqlcmd.exe`), connected through `lpc:.\SQLEXPRESS` (shared memory) |
| ODBC / Python | ODBC Driver 17 for SQL Server; Python 3.11, pyodbc 5.5.0 |
| PlantUML | 1.2024.7 on Java 25.0.2 (`%USERPROFILE%\tools\plantuml\plantuml.jar`) |
| Scratch database | `SchoolManagement_Validation`. This is the only database the project created or dropped; no other database was touched. |

## 1. SQL deployment from clean, twice, plus validation queries

Commands:

```bash
pwsh tools/deploy.ps1 -DatabaseName SchoolManagement_Validation -Clean -LogFile final1.log
```
```bash
pwsh tools/deploy.ps1 -DatabaseName SchoolManagement_Validation -LogFile final2.log
```
```bash
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -b -v DatabaseName=SchoolManagement_Validation -i sql/12_validation_queries.sql
```

`deploy.ps1` runs `sqlcmd -b -v DatabaseName=… -i 00_run_all.sql` from `sql/`.

| Run | Result |
|---|---|
| 1 (clean: database dropped, then scripts 01–12) | Succeeded in about 5 s, **0 errors (`Msg`), 0 warnings**. All mandatory validation checks passed. |
| 2 (re-run on the existing database) | Succeeded, **0 errors, 0 warnings**. Script 11 printed `Sample data already present (school ANIS) - skipping`. All mandatory checks passed. |
| Idempotency fingerprint after run 1 vs. run 2 | **Identical**: 823 user objects, 890 table columns, 249 indexes, object checksum 892425858, 1,975 rows, 288 audit events, reference-data `UpdatedAt` unchanged (the MERGE did not touch unchanged rows) |
| `12_validation_queries.sql` standalone | Exit code 0 |

Deployed objects (from the catalog): 75 tables (71 business + 4 temporal history), 890 columns, 71 PKs, 63 UNIQUE constraints, 126 FKs, 94 CHECK constraints, 356 DEFAULT constraints, 115 other indexes, 12 views, 18 procedures, 3 table types, 8 inline TVFs, 15 schemas.

Validation summary (`12_validation_queries.sql`; mandatory checks must be 0):

| # | Check | Violations | Result |
|---|---|---|---|
| 1–3 | System-named constraints; constraint and index prefixes | 0 / 0 / 0 | PASS |
| 4–5 | Untrusted or disabled FKs / CHECKs | 0 / 0 | PASS |
| 6 | FKs without a supporting index | 0 | PASS |
| 7 | `DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS` violations | 0 | PASS |
| 8 | Soft user references (CreatedBy etc.) not in `iam.UserAccounts` | 0 | PASS |
| 9 | Persons with no role (the waitlisted applicant; allowed) | 1 | INFO |
| 10–13 | Weights total 100; scores ≤ MaxScore; results only for students in the section; one published report card | 0 | PASS |
| 14–15 | Placement branch/grade match; no overlapping placements | 0 | PASS |
| 16–17 | Enrolled without a section; sections over capacity | 0 / 0 | INFO |
| 18 | Attendance only inside a student's placement | 0 | PASS |
| 19 | Teacher/room clashes between published timetables | 0 | PASS |
| 20–26 | Payer shares = 100; header = Σ lines; paid = Σ allocations; credited = Σ credit notes; status consistent; no over-allocation; no cross-payer allocation | 0 | PASS |
| 27 | CHECK constraints resembling a global student cap | 0 | PASS |

The sample data was loaded through the procedures. Results:
- **Records:** 25 persons (10 students, 9 guardians, 8 employees, 6 teachers; 3 people hold overlapping roles), 17 enrollments over 2 years, 76 attendance records, 247 assessment results, 21 report cards (18 Published, 3 Superseded after a re-mark), 48 invoices (35 Paid, 1 PartiallyPaid, 11 Issued, 1 Cancelled), 14 payments, 288 audit events.
- **Temporal history:** 1 grade-change version and 17 enrollment versions (from promotion).
- **Negative test (expected and observed):** publishing a clashing timetable was rejected with error 52004, "1 teacher clash(es), 0 room clash(es)".
- **Arabic search:** `people.fn_SearchPersons(N'ادم')` returned آدم خالد محمود المصري.

### Defects found by validation and fixed

1. **`attendance.usp_RecordSectionAttendance` reused a stale OUTPUT value.**
   - The caller's `@AttendanceSessionId` value survived a `SELECT @x = …` that found no rows, so records were attached to the previous session.
   - The composite FK `FK_AttendanceRecords_AttendanceSessions` rejected the rows (Msg 547) and stopped the first clean deployment.
   - Fix: the procedure now resets the OUTPUT parameter on entry.
2. **`finance.vw_PayerDirectory` showed blank sponsor names.** `CONCAT_WS` returns `''`, not NULL, so `COALESCE` never fell back to the sponsor name. Fixed by branching on `PayerType`.
3. **"Null value is eliminated by an aggregate" warnings** (49 in one run) came from the discount aggregate in `usp_IssueInvoice` and from the sample data. They were removed at the source; both runs now show 0 warnings.
4. **The Arabic collation claim in the plan was wrong.** Testing showed that no SQL Server collation ignores Arabic tashkeel or alef variants. The plan is corrected, and `people.fn_NormalizeArabicText` / `fn_SearchPersons` were added.

## 2. Physical ERD vs. deployed catalog

```bash
python tools/verify_physical_erd.py --catalog "DRIVER={ODBC Driver 17 for SQL Server};SERVER=.\SQLEXPRESS;DATABASE=SchoolManagement_Validation;Trusted_Connection=yes;"
```

```
Compared 75 diagram tables in 11 module files + master against the deployed database catalog:
  75 tables, 890 columns, 71 PKs, 63 UQs, 126 FKs, 94 CKs, 356 DFs, 115 other indexes
RESULT: PASS - physical diagrams match exactly.
```

**What is compared:**
- Table set; each column's name, order, type, nullability, IDENTITY seed and increment, GENERATED ALWAYS and HIDDEN flags; PK/FK markers.
- PK and UQ names and columns; FK names, columns, target and delete rule.
- CHECK constraint names (SQL Server rewrites CHECK expressions, so only names are compared).
- DEFAULT names, columns and normalised expressions.
- Index names, key columns, included columns, uniqueness, clustering and filter.
- Temporal links; relationship edges in each module diagram and in the master.

**The verifier itself was tested:** three deliberate errors injected into `people.puml` (a column type, an index name, a deleted FK line) produced 4 mismatch lines and exit code 1. After regeneration it passed again. The `--ddl` fallback mode also passes, but it wasn't needed, because the database could be deployed.

## 3. PlantUML rendering

```bash
java -DPLANTUML_LIMIT_SIZE=32768 -jar plantuml.jar -charset UTF-8 -tsvg <all 39 .puml files>
```

Exit code 0. 39 `.puml` files produced 39 SVGs, and 0 SVGs contain a syntax-error marker. That is 12 conceptual, 12 logical, 12 physical and 3 categorical diagrams.

Issues fixed during rendering:
- The font has no ∪/⊂ glyphs, so the EER symbols were replaced with `U` and "subset".
- "Branches" was singularised as "Branche"; the singularizer was fixed.

The masters are large overviews (the physical master renders about 10,800 × 1,350 px). That is by design, and the module diagrams are the readable views.

## 4. Grep checks (`.env*`, `.git`, rendered images excluded)

| Search | Result |
|---|---|
| Oracle syntax in `sql/`, `tools/`, `diagrams/` (`VARCHAR2`, `NVARCHAR2`, `CLOB`, `SYSDATE`, `DUAL`, `NVL`, `ROWNUM`, `CONNECT BY`, `CREATE OR REPLACE`, `TO_DATE`, `EXECUTE IMMEDIATE`, `PL/SQL`, `NUMBER(`, `CREATE SEQUENCE`, `NEXTVAL`), whole words, case-insensitive | **0 hits** |
| The word "sequence" anywhere | 8 hits, all stating that **no** SEQUENCE objects are used (docs, notes, a comment) |
| Student limits (`1500`, `1,500`, `3000`, `3,000`, `MaxStudents`, `StudentLimit`, `SchoolCapacity`, …) | 3 hits, none a limit: the sizing-example column in FUTURE_EXPANSION.md, the rule statement in PROJECT_PLAN.md, and validation check 27, which *detects* such caps |

## 5. Not verified

- **SSMS:** not installed, and not needed to validate the scripts. The GUI SSMS steps in the installation guide have not been executed. sqlcmd runs the same `00_run_all.sql` in SQLCMD mode.
- **Classic (ODBC) sqlcmd:** only the go-sqlcmd was used.
- **Other editions** (Developer/Standard/Enterprise): not tested. The design uses only features available in every edition.
- **Performance at scale:** no volume or load test was run. The sizing figures in FUTURE_EXPANSION.md are planning estimates.
- **Concurrency behaviour** (UPDLOCK/HOLDLOCK on numbering, capacity checks under parallel load): reasoned about, not stress-tested.
- **Backup/restore and HA:** documented only.

## Deviations from the Phase 0 plan

| Plan | Built | Reason |
|---|---|---|
| `finance.DocumentNumberSeries` | `organization.DocumentNumberSeries` | Application numbers (enrollment) use it as well as finance |
| `CurrencyCode CHAR(3)` columns | `finance.Currencies` lookup plus `CurrencyId` FKs, with `MinorUnits` | Follows the NVARCHAR and surrogate-key conventions; rounding needs minor units |
| `finance.fn_EffectiveFees`, `usp_PublishReportCard` | `finance.fn_EnrollmentFeeSchedule`, `assessment.usp_PublishReportCards` (whole section) | Naming / set-based scope |
| Collation claim: AI ignores tashkeel | Corrected; explicit Arabic normalisation function | Test result (see above) |
| — | Added `organization.Countries`, `finance.Currencies`, Application status `Enrolled`, procedures `usp_WithdrawStudent`, `usp_IssueCreditNote`, `usp_CancelInvoice`, `people.usp_CreatePerson` | Needed to complete the end-to-end process |
