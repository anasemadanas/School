# Future Expansion

## 1. Possible extensions using the reserved schemas

The project is complete as delivered. The schemas `hr`, `transport`, `library`, `inventory` and `communication` are created **empty** and reserved for future expansion. None of this is scheduled work; it describes how each schema *could* be used without changing any existing table.

| Reserved schema | Possible content | Would connect to the delivered design through |
|---|---|---|
| `hr` | Employee contracts, salary structures, payroll, leave, qualifications, performance reviews | 1:1 extension tables keyed by `people.Employees.PersonId` (the same shared-key pattern as Teachers); `organization.Departments`, `organization.Branches` |
| `transport` | Vehicles, routes, route stops, student transport subscriptions, driver assignments | Subscriptions → `enrollment.Enrollments` (year-scoped); drivers → `people.Employees`; billing through the existing `finance.FeeTypes('TRANSPORT')` and `finance.usp_IssueInvoice` |
| `library` | Catalog items, item copies, loans, reservations, fines | Borrower → `people.Persons` (any role can borrow); copies located in `organization.Rooms`; fines invoiced through finance |
| `inventory` | Item categories, items, suppliers, purchase orders, stock movements, assets | Assets → `organization.Rooms`; custodian → `people.Employees` |
| `communication` | Announcements, messages, recipients, bilingual notification templates, notification log | Recipients → `people.Persons` / `iam.UserAccounts`; audiences → `academic.Sections`, `academic.GradeLevels`, `organization.Branches`; triggered by events already in `audit.AuditEvents` |

Any such extension should follow the same naming and audit conventions, index every FK, use BIGINT for logs and transactions, and add new numbered scripts after `12_…` so the existing scripts stay unchanged.

### Known limitations (not implemented, by decision)

- **No database check that installment percentages total 100** per fee structure (BUSINESS_RULES F3 / L1). A possible extension is a fee-structure procedure that validates the total.
- **No payment reversal procedure** (BUSINESS_RULES L2). The `Reversed` payment status exists, but nothing sets it or undoes allocations. A possible extension is `finance.usp_ReversePayment`.
- **Single currency (JOD) only.** Multi-currency is out of scope.

## 2. Scalability

The design has no student limit. Sizing for planning only:

| Volume driver | 3,000 students | 30,000 students | 100,000 students |
|---|---|---|---|
| AttendanceRecords / year (daily mode, 180 days) | 0.54 M | 5.4 M | 18 M |
| AttendanceRecords / year (per-period mode, 7 periods) | 3.8 M | 38 M | 126 M |
| AssessmentResults / year (≈ 10 subjects × 20 assessments) | 0.6 M | 6 M | 20 M |
| Invoices + lines / year | ≈ 45 K | ≈ 450 K | ≈ 1.5 M |
| AuditEvents / year | ≈ 0.5 M | ≈ 5 M | ≈ 17 M |

- High-volume tables already use BIGINT keys and narrow covering indexes.
- INT keys elsewhere leave room for more than 2 billion rows, far above any realistic count of persons, enrollments or sections.
- Express edition (10 GB per database) is enough for roughly a few thousand students over several years. Move to **Standard** once the data file reaches about 6–7 GB or the buffer pool becomes a bottleneck.

## 3. Indexing roadmap

- Review **Query Store** (it is ON) monthly. Add indexes only for regressed or top-resource queries; drop unused ones (`sys.dm_db_index_usage_stats` shows zero seeks or scans over a full term).
- Person name search is currently a non-seekable scan with normalisation (`people.fn_SearchPersons`). When `people.Persons` exceeds about 200 K rows, or search p95 latency exceeds 300 ms, add persisted normalised name columns, maintained by `people.usp_CreatePerson` and an update procedure, with an index on them. Full-Text Search is an alternative.
- When AttendanceRecords exceeds about 50 M rows, consider a **nonclustered columnstore** index on (SessionDate, SectionId, AttendanceStatusId) for analytics, or move analytics to a reporting replica.
- Use `DATA_COMPRESSION = PAGE` on history and audit tables once they exceed about 5 GB.

## 4. Archiving and partitioning (not implemented)

**Approach:** partition by **date** (monthly, or by academic year) using a partition function on a `DATE` column, aligned indexes, and `SWITCH` to archive tables.

| Table | Partition key | Trigger threshold to implement | Retention online |
|---|---|---|---|
| attendance.AttendanceRecords (+ Sessions) | SessionDate (monthly) | > 50 M rows **or** > 20 GB **or** index maintenance > 30 min | current + 2 academic years; older → archive filegroup / read-only |
| assessment.AssessmentResults | via Assessments.AssessmentDate → add a persisted `AcademicYearId` or `AssessmentDate` column first | > 30 M rows or > 15 GB | current + 3 years (transcripts need history; archive, never delete) |
| audit.AuditEvents, audit.SecurityEvents | OccurredAt (monthly) | > 20 M rows or > 10 GB | 13 months hot; older switched to `audit_archive` (compressed, read-only) and kept 7 years |
| audit.*History (temporal) | Temporal history retention policy (`HISTORY_RETENTION_PERIOD`) or a partitioned history table | > 10 M rows | grades: keep forever (transcript disputes); fees: 7 years |
| finance.Invoices / Payments | InvoiceDate / PaymentDate (yearly) | > 10 M rows | 10 years (statutory); closed years read-only |

Pre-conditions before partitioning:
- Partitioning needs the partition column in the clustered key. That means changing the PK to `(SessionDate, AttendanceRecordId)` or making the PK nonclustered. It would be a separate migration if partitioning is ever adopted.
- Closed academic years (`YearStatus = 'Closed'`) are never edited by the procedures, which makes their partitions safe to mark read-only.

## 5. Backup and recovery

The database uses the FULL recovery model.

| Backup | Schedule | Notes |
|---|---|---|
| Full | Weekly, Friday 02:00 (outside the Sun–Thu school week) | `WITH CHECKSUM, COMPRESSION`; copy off-site / to cloud storage |
| Differential | Daily, 02:00 (Sat–Thu) | |
| Transaction log | Every **15 minutes**, 24×7 | Required in FULL recovery |
| Integrity | `DBCC CHECKDB` weekly, before the full backup | |
| Restore test | Monthly, to a scratch server (`SchoolManagement_RestoreTest`) | Then run `12_validation_queries.sql` against the restored copy |

| Objective | Target | How it is met |
|---|---|---|
| **RPO** (data loss) | ≤ 15 minutes | log backup interval |
| **RTO** (downtime) | ≤ 2 hours (single server) | full + latest diff + log chain; DB < 50 GB restores well within this |

Peak periods (enrollment, fee due dates, report-card publication): move log backups to every 5 minutes, and take a manual full backup before year-end rollover (`usp_PromoteStudents`).

## 6. High availability options

| Option | RPO / RTO | Edition | When |
|---|---|---|---|
| Backups + log shipping to a warm standby | ≈ 15 min / 30–60 min | Express can be a source only via manual jobs (no Agent); Standard+ | Single campus, budget-constrained |
| **Basic Availability Group** (2 replicas, synchronous) | 0 / < 1 min (automatic failover) | Standard | Recommended production baseline for multi-branch use |
| Always On AG with readable secondary | 0 / < 1 min, and reporting off-loaded | Enterprise | Large groups; reporting and analytics at scale |
| Failover Cluster Instance | 0 / minutes | Standard+ | When shared storage already exists |
| Azure SQL Managed Instance | Built-in HA, PITR 7–35 days | n/a | If moving to the cloud. Compatible: no cross-database or instance-level dependencies in this design. |

## 7. Security roadmap

- Dynamic Data Masking on national numbers, passport numbers and medical notes for non-privileged readers.
- Always Encrypted (or column encryption) for identity document numbers, if regulations require it.
- Row-level security keyed on `iam.UserRoles.BranchId` for branch-scoped staff.
- Move authentication fully to an external identity provider (the `AuthProvider` and `ExternalSubjectId` columns already exist).
