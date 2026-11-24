# School Management System — Database Project Plan

Target: **Microsoft SQL Server 2022**, T-SQL, managed with SSMS / sqlcmd.
Status: **Complete as delivered.** This plan was approved in Phase 0 and has been updated to match the final scope. Deviations made during the build are listed in [docs/VALIDATION_REPORT.md](docs/VALIDATION_REPORT.md).

---

## 1. Scope

| Schemas | Status | What is delivered |
|---|---|---|
| `organization`, `iam` (identity), `people`, `academic`, `enrollment`, `timetable`, `attendance`, `assessment`, `finance`, `audit` | **Delivered (final scope)** | Full design: conceptual, logical, physical, and categorical models; T-SQL DDL; reference data; views; procedures; functions; sample data; validation; docs |
| `hr`, `transport`, `library`, `inventory`, `communication` | **Reserved for future expansion** | The schemas are created empty and shown as empty reserved schemas on the conceptual master diagram. They contain no tables. Possible extensions are described only in [docs/FUTURE_EXPANSION.md](docs/FUTURE_EXPANSION.md). |

All 15 schemas live in **one database** (`SchoolManagement`).

### No fixed student limit
No table, constraint, trigger, procedure, function, view, or document will impose a system-wide student count. Figures like "1,500–3,000 students" are only used as sizing examples. The design targets thousands of students at first and tens of thousands or more later, over many academic years, without a redesign. The only capacities stored are **configurable business data** such as `academic.Sections.Capacity` and `organization.Rooms.SeatCapacity`. These are nullable, have no upper bound, and are checked only by procedures (a soft warning or an override), not by a hard global rule.

---

## 2. Assumptions (confirmed)

**Organization**
- A1. The school is a K-12 private school in Jordan / the Middle East. One legal school entity (`organization.Schools`) with **one or more branches/campuses** (`organization.Branches`). The model also allows several schools (a school group) at no extra cost.
- A2. Academic years are defined **per school** and shared by all of its branches. Each year has 1–n terms (Jordan usually uses 2 semesters; 3 terms is also supported).
- A3. Grade levels are **KG1, KG2, Grade 1–12**, held as reference data (they can be extended, e.g. Pre-KG).
- A4. Programs/tracks are reference data: e.g. *Jordanian National*, *International (IGCSE/IB)*, and for Grades 11–12 the *Scientific / Literary / Tawjihi* streams. A section belongs to one program.
- A5. The school week is **Sunday–Thursday**. Days are stored as ISO day numbers (1=Mon … 7=Sun) and the working days are configurable per branch, so another week pattern needs no schema change.

**People**
- A6. Names are stored in **Arabic and English**, using the Arab 4-part structure: First, Father, Grandfather, Family. Father and Grandfather names are optional. Full display names are computed columns.
- A7. One person can hold **several roles at once** (e.g. a teacher who is also a guardian of an enrolled student, or a graduate who is now an employee). Roles are **overlapping**.
- A8. A student can have several guardians, and a guardian can have several students (M:N), with relationship type, custody, pickup permission, primary-contact flag, and emergency-contact flag.
- A9. Identity documents (national number, passport, residency) are stored as PII in a separate table so access can be restricted. Neither encryption (Always Encrypted) nor masking is applied; both are listed as possible extensions in FUTURE_EXPANSION.md.
- A10. Dates are **Gregorian** only. Hijri dates, where needed, are converted in the application.

**Academic / assessment**
- A11. Grading is **percentage-based (0–100)**, with a configurable grading scale (letter bands, pass mark e.g. 50). Each year/grade/subject can use a different scale.
- A12. Subject final grades are weighted combinations of assessment types (e.g. Quizzes 20%, Midterm 30%, Final 50%), configured per academic year + grade level + subject.
- A13. Report cards are a **snapshot**. Once published they do not change, even if an underlying result is corrected later. Corrections require re-issuing a new version.

**Finance**
- A14. **Single currency: JOD (3 decimal places).** Multi-currency is out of scope. The `finance.Currencies` lookup holds the currency's minor units, used for rounding; there is no exchange-rate logic.
- A15. **Project assumption, not legal fact:** tuition is tax-exempt, and uniforms are taxed at 16%. `TaxAmount` exists on invoice lines (default 0).
- A16. Fees are paid by a **payer**, which is either a **Guardian** or a **sponsoring Organization** (an employer, NGO, or scholarship fund). This is a true EER category (union type).
- A17. Issued invoices are never edited or deleted. Corrections are made with **credit notes**. Payments can be partial and can be split across several invoices (payment allocations).
- A18. Payment methods include Cash, Cheque, Bank Transfer, Card, and **eFAWATEERcom** (Jordan's e-billing network), held as reference data.
- A19. Document numbers (invoice, receipt, and credit-note numbers) are gap-tolerant and generated from an `organization.DocumentNumberSeries` table (implemented in `organization`, not `finance`, because application numbers use it too) under an `UPDLOCK` inside the issuing procedure. A sequence object is not used (project rule 6).

**Identity / audit**
- A20. Authentication is handled by the application or an external IdP. The database stores user accounts, roles, permissions, and branch-scoped role grants. Passwords are never stored in plain text. If local login is used, only an application-produced hash (`VARBINARY`) is stored.
- A21. The application sets `SESSION_CONTEXT(N'UserAccountId')` on each connection. Procedures and the `CreatedBy` / `UpdatedBy` defaults read it.

---

## 3. Decision needed: `identity` schema name

`IDENTITY` is a reserved T-SQL keyword.

| Option | Pros | Cons |
|---|---|---|
| A — keep `[identity]` | Matches the original module name | Every reference needs brackets; one missed bracket is a parse error; tooling (ORMs, generators, PlantUML scripts, the verifier) becomes fragile; easy to confuse with the `IDENTITY` column property |
| **B — rename to `iam`** | No quoting; clear meaning (identity and access management); safe in every tool | Module name differs from the original list |

**Recommendation: Option B (`iam`).** The docs will say that `iam` *is* the "identity" module. The rest of this plan uses `iam`.

---

## 4. Entity list per schema

Legend: PK/FK details come in the logical model. "→" means "references".

### 4.1 `organization` — the school and its physical structure
| Entity | Purpose | Key relationships |
|---|---|---|
| Schools | Legal school entity (name Ar/En, licence no.) | 1:N Branches, 1:N academic.AcademicYears |
| Branches | Campus / branch (address, phone, working days) | → Schools; 1:N Buildings, Sections, Enrollments, FeeStructures |
| Buildings | Building on a campus | → Branches; 1:N Rooms |
| Rooms | Classroom, lab, or hall, with optional seat capacity and room type | → Buildings, → RoomTypes; used by timetable entries |
| RoomTypes | Lookup: Classroom, Lab, Gym, Hall, Library… | 1:N Rooms |
| Departments | Academic or administrative department (Math, Science, Admin) | → Schools; 1:N people.Employees, academic.Subjects |
| Countries | Lookup (ISO-3166 alpha-2/3, names Ar/En) | Used for nationality and addresses |

### 4.2 `iam` — identity and access management
| Entity | Purpose | Key relationships |
|---|---|---|
| UserAccounts | Login account (username, email, hash or external subject id, status, lockout) | → people.Persons (0..1, unique): a person has at most one account |
| Roles | Role (Admin, Registrar, Teacher, Accountant, Guardian, Student) | M:N Permissions |
| Permissions | Fine-grained permission code (e.g. `finance.invoice.issue`) | M:N Roles |
| RolePermissions | Role ↔ Permission | → Roles, → Permissions |
| UserRoles | Grants a role to a user, **optionally scoped to a branch**, with validity dates | → UserAccounts, → Roles, → organization.Branches (nullable) |

### 4.3 `people` — persons and their roles (supertype/subtype)
| Entity | Purpose | Key relationships |
|---|---|---|
| **Persons** (supertype) | Every human: 4-part names Ar/En, gender, DOB, nationality | → organization.Countries; 1:0..1 with each subtype |
| PersonContacts | Phones and emails (type, value, primary flag) | → Persons |
| PersonAddresses | Addresses (type, city, area, street) | → Persons, → Countries |
| PersonIdentityDocuments | National no., passport, residency (PII) | → Persons, → IdentityDocumentTypes |
| IdentityDocumentTypes | Lookup | 1:N PersonIdentityDocuments |
| **Students** (subtype) | Student number, admission date, current status, medical notes | PK = FK → Persons |
| **Guardians** (subtype) | Occupation, employer, preferred language | PK = FK → Persons |
| **Employees** (subtype) | Employee number, hire date, department, primary branch, job title | PK = FK → Persons; a future `hr` module could extend this by shared key |
| **Teachers** (sub-subtype of Employees) | Teaching licence, specialisation | PK = FK → **Employees** (not Persons) |
| StudentGuardians | M:N student ↔ guardian with relationship, custody, pickup, emergency, and primary flags | → Students, → Guardians, → RelationshipTypes |
| RelationshipTypes | Lookup: Father, Mother, Uncle, Legal guardian… | |

### 4.4 `academic` — academic structure and calendar
| Entity | Purpose | Key relationships |
|---|---|---|
| **AcademicYears** | First-class year (e.g. 2025/2026) with start/end dates and status (Planned/Active/Closed) | → organization.Schools; scopes sections, enrollments, fee structures, timetables, assessments |
| Terms | Semesters/terms within a year | → AcademicYears |
| Holidays | Non-school days per year (optionally per branch) | → AcademicYears, → Branches (nullable) |
| GradeLevels | KG1…Grade 12 with display order | |
| Programs | National / International / streams | |
| Subjects | Subject catalogue (code, names Ar/En, department) | → organization.Departments |
| CurriculumSubjects | Subjects taught per year + grade level + program, with weekly periods, core/elective flag, and grading scale | → AcademicYears, GradeLevels, Programs, Subjects, assessment.GradingScales |
| Sections | Class section per year + branch + grade level + program (e.g. "Grade 5-A"), with optional capacity, homeroom teacher, and home room | → AcademicYears, Branches, GradeLevels, Programs, people.Teachers, organization.Rooms |
| TeachingAssignments | Teacher teaches subject X to section Y in year/term Z | → Sections, CurriculumSubjects, people.Teachers, Terms (nullable = whole year) |

### 4.5 `enrollment` — admission through yearly enrollment
| Entity | Purpose | Key relationships |
|---|---|---|
| Applications | Admission application for a target year, grade, and branch, with status workflow (Submitted → Accepted/Rejected/Waitlisted) | → people.Persons (applicant), → AcademicYears, GradeLevels, Branches |
| ApplicationStatusHistory | Every status change of an application | → Applications |
| **Enrollments** | A student's enrollment **per academic year** (branch, grade, program, status, dates, promotion outcome); UQ(Student, Year) | → people.Students, AcademicYears, Branches, GradeLevels, Programs, Applications (nullable) |
| SectionAssignments | Assigns an enrollment to a section with effective dates (supports mid-year transfers); at most one open assignment per enrollment | → Enrollments, academic.Sections |
| EnrollmentSubjects | Elective or stream subject choices per enrollment | → Enrollments, academic.CurriculumSubjects |

### 4.6 `timetable` — weekly schedule
| Entity | Purpose | Key relationships |
|---|---|---|
| BellSchedules | Named period pattern per branch per year (e.g. "Primary 7-period day") | → Branches, AcademicYears |
| Periods | Period number, start time, end time, and IsBreak flag | → BellSchedules |
| Timetables | Versioned timetable per section per term (Draft/Published/Archived, effective from/to) | → academic.Sections, academic.Terms, BellSchedules |
| TimetableEntries | Day-of-week + period → teaching assignment + room | → Timetables, Periods, academic.TeachingAssignments, organization.Rooms |

Teacher and room clashes across sections are checked by the publish procedure and by a validation query. They cannot be expressed as a plain constraint because of versioning.

### 4.7 `attendance`
| Entity | Purpose | Key relationships |
|---|---|---|
| AttendanceStatuses | Lookup: Present, Absent, Late, Excused, Sick, Early Leave (with a "counts as present" flag) | |
| AttendanceSessions | One roll-call per section per date (daily mode) or per period (period mode); records who took it | → academic.Sections, timetable.Periods (nullable), people.Employees |
| AttendanceRecords | One row per student per session (status, minutes late, remark) — **BIGINT** | → AttendanceSessions, enrollment.Enrollments, AttendanceStatuses |

### 4.8 `assessment`
| Entity | Purpose | Key relationships |
|---|---|---|
| GradingScales / GradingScaleBands | Percentage bands → letter/descriptor (Ar/En), pass mark | |
| AssessmentTypes | Lookup: Quiz, Homework, Project, Midterm, Final, Participation | |
| AssessmentWeights | Weight of each assessment type per curriculum subject per term (sums to 100) | → academic.CurriculumSubjects, Terms, AssessmentTypes |
| Assessments | A concrete assessment given to a teaching assignment (date, max score, type) | → academic.TeachingAssignments, Terms, AssessmentTypes |
| AssessmentResults | Student score per assessment (score, absent/exempt flags, comment) — **BIGINT, system-versioned** | → Assessments, enrollment.Enrollments |
| ReportCards | Published snapshot per enrollment per term (version, status, attendance summary, homeroom comment) | → enrollment.Enrollments, academic.Terms |
| ReportCardLines | Per-subject computed percentage, letter, and teacher comment | → ReportCards, academic.CurriculumSubjects |

### 4.9 `finance`
| Entity | Purpose | Key relationships |
|---|---|---|
| FeeTypes | Lookup: Tuition, Registration, Books, Uniform, Activities, Transport | |
| FeeStructures | Fee schedule per **year + branch + grade level (+ program)** | → AcademicYears, Branches, GradeLevels, Programs |
| FeeStructureItems | Fee type + amount within a structure | → FeeStructures, FeeTypes |
| FeeInstallments | Due-date schedule (installment no., due date, percentage) | → FeeStructures |
| DiscountTypes | Lookup: Sibling, Staff child, Merit, Early payment (default % or amount) | |
| StudentDiscounts | Discount granted to an enrollment (approved by, reason) | → enrollment.Enrollments, DiscountTypes |
| Sponsors | Sponsoring organization (employer, NGO, scholarship fund) | |
| **Payers** (EER category / union) | Payer = Guardian **or** Sponsor (exactly one, enforced by CHECK) | → people.Guardians (nullable), → Sponsors (nullable) |
| StudentPayers | Who pays for which enrollment, with responsibility % | → Enrollments, Payers |
| DocumentNumberSeries | Next number per document type, branch, and year | |
| Invoices | Issued invoice header (number, payer, enrollment, dates, status, totals) — **BIGINT** | → Payers, enrollment.Enrollments, FeeInstallments (nullable) |
| InvoiceLines | Lines (fee type, qty, unit amount, discount, tax) — **BIGINT** | → Invoices, FeeTypes |
| CreditNotes | Correction or credit against an invoice — **BIGINT** | → Invoices |
| PaymentMethods | Lookup (Cash, Cheque, Transfer, Card, eFAWATEERcom) | |
| Payments | Money received (receipt no., payer, method, amount, reference) — **BIGINT** | → Payers, PaymentMethods |
| PaymentAllocations | Allocation of a payment to invoices (partial or split) — **BIGINT** | → Payments, Invoices |

### 4.10 `audit`
| Entity | Purpose | Key relationships |
|---|---|---|
| AuditEvents | Business-event log written by procedures (enrolled, section changed, invoice issued/voided, payment recorded, report card published), with JSON before/after — **BIGINT** | Soft references (table name + key) so it never blocks deletes or archiving |
| SecurityEvents | Login success/failure, role grant/revoke — **BIGINT** | Soft ref to iam.UserAccounts |
| *History tables* | System-versioned history tables for the temporal tables (section 6.5), placed in the `audit` schema | |

### 4.11 Reserved schemas (empty)
`hr`, `transport`, `library`, `inventory` and `communication` are created empty and reserved for future expansion. They contain no tables. How they could connect to the delivered design is described only in [docs/FUTURE_EXPANSION.md](docs/FUTURE_EXPANSION.md), as possible extensions.

---

## 5. Core business processes the design supports

| # | Process | Main tables | Implemented by |
|---|---|---|---|
| 1 | Admission | enrollment.Applications, ApplicationStatusHistory, people.Persons | `enrollment.usp_SubmitApplication`, `usp_DecideApplication` |
| 2 | Enrollment per academic year | people.Students (created on acceptance), enrollment.Enrollments | `enrollment.usp_EnrollStudent` (single transaction: subtype row, enrollment, guardians, payers, audit event) |
| 3 | Section assignment / transfer | enrollment.SectionAssignments | `enrollment.usp_AssignSection` (closes the open assignment, opens a new one, warns on capacity) |
| 4 | Timetable | timetable.* | `timetable.usp_PublishTimetable` (clash checks) |
| 5 | Daily attendance | attendance.Sessions/Records | `attendance.usp_RecordSectionAttendance` (**table-valued parameter** for the whole section) |
| 6 | Assessments and grading | assessment.Assessments/Results | `assessment.usp_RecordResults` (TVP) |
| 7 | Report cards | assessment.ReportCards/Lines | `assessment.usp_GenerateReportCards`, `usp_PublishReportCards` |
| 8 | Fee structures | finance.FeeStructures/Items/Installments | reference + sample data; `finance.fn_EnrollmentFeeSchedule` (inline TVF) |
| 9 | Invoices | finance.Invoices/Lines | `finance.usp_IssueInvoice` (applies discounts, numbers the document, writes an audit event) |
| 10 | Payments | finance.Payments/Allocations | `finance.usp_RecordPayment` (allocates to the oldest open invoices or to explicit ones; updates invoice status) |
| 11 | Audit trail | audit.*, temporal history | Every procedure above writes `audit.AuditEvents`; row history comes from temporal tables |

Year rollover (promotion to the next grade) is handled by `enrollment.usp_PromoteStudents`. It creates new enrollments for the next year and never overwrites the old ones.

---

## 6. Key design decisions

### 6.1 Supertype/subtype pattern — *Class Table Inheritance with shared primary key*
- `people.Persons(PersonId INT IDENTITY)` is the supertype. `Students`, `Guardians`, and `Employees` each have `PersonId` as **PK and FK → Persons**. `Teachers.PersonId` is **PK and FK → Employees.PersonId**, which makes Teacher a specialisation of Employee.
- **Overlapping, partial specialisation.** There is no discriminator column, because one person can be in several subtype tables at once, and a person can also be in none (e.g. an applicant not yet accepted, or an emergency contact). A person's roles are derived from which subtype rows exist (`people.vw_PersonRoles`).
- Why not single-table inheritance: it would give a wide sparse table, no NOT NULL on role-specific columns, and a future `hr` module could not extend Employees cleanly.
- Why not separate unrelated tables: a person who is both employee and guardian would be duplicated, and contact/ID data would be repeated.
- Subtype deletes use **NO ACTION**. Removing a role means deleting a row deliberately, after its dependants are handled.

### 6.2 Money precision — `DECIMAL(19,4)` everywhere
- JOD, KWD, BHD, and OMR use **3** minor digits. A 4th digit gives headroom for percentage discounts and installment splits before rounding, and 19 digits of precision stays in the 9-byte storage class.
- The same type is used for every monetary column. Percentages use `DECIMAL(7,4)`, and scores use `DECIMAL(9,3)`.
- Rounding to the currency's minor unit (3 for JOD) happens in procedures at the moment an invoice is issued.

### 6.3 Collation — `Arabic_100_CI_AI_SC` (database default)
- Arabic sorting rules, while Latin text still sorts and compares correctly, so English names work too.
- **CI** is case-insensitive (English). **AI** is accent-insensitive for Latin text. **SC** gives correct handling of supplementary characters (surrogate pairs, e.g. emoji in messages).
- **Correction (found while building Phase 2):** an earlier version of this plan said AI also ignores Arabic diacritics. Testing on SQL Server 2022 showed it does **not**. No collation tested (Arabic_CI_AI, Arabic_100_CI_AI[_SC][_UTF8], Latin1_General_100_CI_AI) treats "محمد" = "مُحَمَّد" or "احمد" = "أحمد". Arabic-insensitive search is therefore done explicitly by `people.fn_NormalizeArabicText` / `people.fn_SearchPersons`.
- All text is `NVARCHAR`, so a UTF-8 collation brings no benefit.
- Caveat: tempdb uses the server collation. Procedures use table variables (which take the database collation), and the scripts' `#temp` tables declare `COLLATE DATABASE_DEFAULT`.
- Alternative (if you prefer accent-sensitive matching): `Arabic_100_CI_AS_SC`.

### 6.4 BIGINT vs INT keys
| BIGINT (high volume, grows every school day or with every transaction) | INT (everything else) |
|---|---|
| attendance.AttendanceSessions, attendance.AttendanceRecords | All lookups and reference tables |
| assessment.AssessmentResults, assessment.ReportCardLines | organization.*, iam.*, people.*, academic.* |
| finance.Invoices, InvoiceLines, CreditNotes, Payments, PaymentAllocations | enrollment.* (one row per student per year) |
| audit.AuditEvents, audit.SecurityEvents | timetable.*, assessment.Assessments, ReportCards, finance setup tables |

Sizing illustration at 30,000 students: period-mode attendance is about 38M rows/year, and assessment results about 7M rows/year. INT would last decades for the "INT" tables, even with tens of thousands of students.

### 6.5 System-versioned temporal tables
| Table | Why | History table |
|---|---|---|
| assessment.AssessmentResults | Grade changes must be traceable (who changed which score and when) | `audit.AssessmentResultsHistory` |
| finance.FeeStructureItems | Fee amounts change; old invoices must be explainable | `audit.FeeStructureItemsHistory` |
| enrollment.Enrollments | Status, grade, or branch corrections over the year | `audit.EnrollmentsHistory` |
| people.Persons | Name and identity corrections (legal or audit need) | `audit.PersonsHistory` |

Not temporal: invoices and payments (they are immutable, and corrections go through credit notes) and attendance records (too high-volume; changes are captured in `audit.AuditEvents` by the procedure). Because PKs are added in `04_*.sql`, the period columns are created in `03`, and `SYSTEM_VERSIONING = ON` is switched on in `05` after the PK exists.

### 6.6 Other conventions
- **Audit columns**: `CreatedAt`/`UpdatedAt DATETIME2(3)` default `SYSUTCDATETIME()`. `CreatedBy`/`UpdatedBy INT` default `TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))`. These are **soft references to `iam.UserAccounts` (no FK)**, because otherwise every table would carry two extra FKs and indexes and would create circular dependencies with `iam`. `UpdatedAt`/`UpdatedBy` are set by procedures. Direct DML must set them; this is documented as an application-layer rule.
- **ROWVERSION** on concurrently edited tables: Persons, Students, Enrollments, SectionAssignments, Sections, Timetables, TimetableEntries, AssessmentResults, ReportCards, Invoices, Payments, StudentDiscounts, UserAccounts.
- **Lookup table vs CHECK**: user-extensible lists (fee types, attendance statuses, relationship types, payment methods) are lookup tables. Fixed workflow states (invoice status, enrollment status, application status) use `CHECK` constraints on a short `NVARCHAR(20)` code, because the procedures depend on exact values.
- **Deliberate denormalisation**:
  1. `attendance.AttendanceRecords` carries `SessionDate` and `SectionId` copied from its session. A **composite FK** `(AttendanceSessionId, SessionDate, SectionId)` → a UNIQUE key on `AttendanceSessions` guarantees they cannot drift. This allows the student+date and section+date indexes.
  2. Invoice header totals are stored and maintained by procedures for fast statements.
  3. Report-card lines are snapshots by design (A13).
- **ON DELETE**: `NO ACTION` everywhere by default. `CASCADE` only for pure child rows of a parent that is itself never business history: `iam.RolePermissions`, `people.PersonContacts`, `people.PersonAddresses`, `timetable.TimetableEntries` (of a *Draft* timetable, guarded by the procedure). **Never** for finance, assessment, attendance, or enrollment history.
- **Soft delete**: `IsActive BIT` on master/reference data. History is never deleted.
- **Filtered indexes**: e.g. one open section assignment per enrollment (`WHERE EndDate IS NULL`), open invoices (`WHERE Status IN ('Issued','PartiallyPaid')`), one primary contact per person, and active users.
- **No partitioning.** The strategy and thresholds are in `FUTURE_EXPANSION.md`.
- **No `SEQUENCE` objects** (rule 6). Surrogate keys use `IDENTITY`, and business numbers use `organization.DocumentNumberSeries`.

---

## 7. File plan

```
/
├── README.md
├── PROJECT_PLAN.md                      (this file)
├── .gitignore                           (ignores .env*, render output, __pycache__)
├── sql/
│   ├── 00_run_all.sql                   (SQLCMD mode, :r includes, :setvar DatabaseName)
│   ├── 01_create_database.sql
│   ├── 02_create_schemas.sql
│   ├── 03_create_tables.sql
│   ├── 04_primary_foreign_keys.sql
│   ├── 05_constraints.sql               (UQ, CK, DF, then SYSTEM_VERSIONING ON)
│   ├── 06_indexes.sql
│   ├── 07_reference_data.sql
│   ├── 08_views.sql
│   ├── 09_stored_procedures.sql         (incl. table types for TVPs)
│   ├── 10_functions.sql
│   ├── 11_sample_data.sql               (bilingual, 2 academic years: 2025/2026 closed, 2026/2027 current)
│   └── 12_validation_queries.sql
├── diagrams/
│   ├── README.md
│   ├── _style.iuml                      (shared PlantUML style include)
│   ├── conceptual/  master_conceptual.puml + modules/{organization,iam,people,academic,enrollment,timetable,attendance,assessment,finance,audit}.puml
│   ├── logical/     master_logical.puml    + modules/<same 10>.puml
│   ├── physical/    master_physical.puml   + modules/<same 10>.puml  (finance may be split into setup/billing)
│   └── categorical/ master_categorical.puml + modules/{people_roles,finance_payer}.puml
│                                          (only modules with real specialisation)
├── docs/
│   ├── DATABASE_ARCHITECTURE.md
│   ├── CONCEPTUAL_MODEL.md
│   ├── LOGICAL_MODEL.md
│   ├── PHYSICAL_MODEL.md
│   ├── CATEGORICAL_MODEL.md
│   ├── TABLE_CATALOG.md
│   ├── DATABASE_RELATIONSHIPS.md
│   ├── BUSINESS_RULES.md
│   ├── SQL_SERVER_INSTALLATION_GUIDE.md
│   └── FUTURE_EXPANSION.md
└── tools/
    ├── verify_physical_erd.py           (live-catalog mode via ODBC, or DDL-parse fallback)
    └── README.md
```

Commits: one per phase (`Phase 0: plan`, `Phase 1: conceptual and logical models`, `Phase 2: T-SQL scripts`, `Phase 3: physical and categorical diagrams`, `Phase 4: documentation`, `Phase 5: validation`). Never pushed.

---

## 8. Validation

The SQL was deployed and validated on SQL Server 2022 Express. The commands and actual results are in [docs/VALIDATION_REPORT.md](docs/VALIDATION_REPORT.md).

---

## 9. Resolved decisions

| # | Question | Decision |
|---|---|---|
| 1 | Schema name for the identity module | `iam` (Option B) |
| 2 | Collation | `Arabic_100_CI_AI_SC`, with explicit Arabic normalisation for search (see 6.3) |
| 3 | Validation tooling | SQL Server 2022 Express, sqlcmd, pyodbc and plantuml.jar installed with approval |
| 4 | Tax | Project assumption: tuition exempt, uniforms 16% (A15) |
| 5 | Currency | Single currency, JOD only (A14) |
| 6 | Installment-percent check, payment reversal | Not implemented; listed as known limitations in BUSINESS_RULES.md and FUTURE_EXPANSION.md |
