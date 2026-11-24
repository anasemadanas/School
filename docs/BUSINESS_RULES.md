# Business Rules

Each rule is listed with **where it is enforced**:
- **DB** = declarative constraint (PK / UQ / FK / CK / DF / filtered unique index),
- **SP** = stored procedure (error number given),
- **VQ** = validation query in `12_validation_queries.sql` (detects violations made by direct DML),
- **APP** = application layer.

## General / design

| # | Rule | Enforced by |
|---|---|---|
| G1 | There is **no maximum number of students** anywhere | By design. VQ check 27 confirms that no CHECK constraint looks like a global cap; the grep in VALIDATION_REPORT confirms the same for the code. |
| G2 | Every table has a surrogate PK; every constraint and index is explicitly named | DB; VQ checks 1–3 |
| G3 | Created/updated timestamps are UTC and stamped automatically | DB `DF_*_CreatedAt/UpdatedAt` = `SYSUTCDATETIME()`. UpdatedAt is set by SPs; APP must set it on direct updates. |
| G4 | The acting user is recorded on every change | DB `DF_*_CreatedBy/UpdatedBy` from `SESSION_CONTEXT('UserAccountId')`; SP; APP must call `sp_set_session_context`. VQ check 8 (no orphan user ids). |
| G5 | Business history is never cascade-deleted | DB: FKs are NO ACTION, with CASCADE only on the four child tables listed in 04 |
| G6 | Every business operation leaves an audit event | SP: every procedure calls `audit.usp_LogEvent` inside its transaction |
| G7 | Business document numbers are unique and never re-used | DB `UQ_*Number`; SP `organization.usp_GetNextDocumentNumber` (UPDLOCK/HOLDLOCK) |

## Organization & IAM

| # | Rule | Enforced by |
|---|---|---|
| O1 | Branch, building, room and department codes are unique within their parent | DB `UQ_Branches_SchoolId_BranchCode`, `UQ_Buildings_*`, `UQ_Rooms_*`, `UQ_Departments_*` |
| O2 | Working days form a valid weekday set (Sun–Thu = 79 by default) | DB `CK_Branches_WorkingDaysMask`, `DF_Branches_WorkingDaysMask` |
| O3 | Room seat capacity, when given, is positive | DB `CK_Rooms_SeatCapacity` |
| I1 | User names are unique; e-mails and external subject ids are unique where present | DB `UQ_UserAccounts_UserName`, `IX_UserAccounts_Email`, `IX_UserAccounts_ExternalSubjectId` |
| I2 | A person has at most one user account | DB `IX_UserAccounts_PersonId` (filtered UNIQUE) |
| I3 | A local account has a password hash; an external account has an external subject id | DB `CK_UserAccounts_Credential` |
| I4 | Role grants have a valid date range and may be scoped to one branch | DB `CK_UserRoles_ValidDates`, `FK_UserRoles_Branches` |
| I5 | Permission checks (who may call which procedure) | APP, using `iam.RolePermissions`. The database grants EXECUTE to the application login only. |

## People

| # | Rule | Enforced by |
|---|---|---|
| P1 | A student, guardian or employee is always a person; a teacher is always an employee | DB shared-PK FKs `FK_Students_Persons`, `FK_Guardians_Persons`, `FK_Employees_Persons`, `FK_Teachers_Employees` |
| P2 | One person may hold several roles at once | DB (no discriminator; independent subtype tables) |
| P3 | Gender is M or F; date of birth is plausible | DB `CK_Persons_Gender`, `CK_Persons_DateOfBirth` |
| P4 | A student cannot be their own guardian; each student/guardian pair is recorded once | DB `CK_StudentGuardians_NotSelf`, `UQ_StudentGuardians_StudentId_GuardianId` |
| P5 | At most one primary-contact guardian per student | DB `IX_StudentGuardians_PrimaryContact` (filtered UNIQUE) |
| P6 | At most one primary contact per person and contact type | DB `IX_PersonContacts_PrimaryPerType` |
| P7 | An identity document number is unique per type and issuing country | DB `UQ_PersonIdentityDocuments_Type_Country_Number` |
| P8 | Student and employee numbers are unique; a student number is generated when not supplied | DB `UQ_Students_StudentNumber`; SP `usp_EnrollStudent` |
| P9 | Name changes keep full history | DB: `people.Persons` is system-versioned |
| P10 | Arabic name search ignores tashkeel and hamza/alef variants | Function `people.fn_SearchPersons` / `fn_NormalizeArabicText` (collations can't do this) |

## Academic

| # | Rule | Enforced by |
|---|---|---|
| A1 | Year code has the form `YYYY-YYYY`; the end date is after the start date | DB `CK_AcademicYears_YearCode`, `CK_AcademicYears_Dates` |
| A2 | At most one Active academic year per school | DB `IX_AcademicYears_ActivePerSchool` |
| A3 | Term numbers are unique per year; terms and holidays have valid date ranges | DB `UQ_Terms_*`, `CK_Terms_Dates`, `CK_Holidays_Dates` |
| A4 | Each subject is offered at most once per year/grade/program, with positive weekly periods | DB `UQ_CurriculumSubjects_*`, `CK_CurriculumSubjects_WeeklyPeriods` |
| A5 | Section code is unique per year/branch/grade; capacity, when set, is positive | DB `UQ_Sections_Year_Branch_Grade_Code`, `CK_Sections_Capacity` |
| A6 | A grade's promotion target is a different grade | DB `CK_GradeLevels_NextGradeLevel`, `FK_GradeLevels_GradeLevels_NextGradeLevelId` |

## Enrollment

| # | Rule | Enforced by |
|---|---|---|
| E1 | Applications move only through valid transitions (Submitted → UnderReview / Accepted / Rejected / Waitlisted / Withdrawn …, Accepted → Enrolled) | DB `CK_Applications_ApplicationStatus`; SP `usp_DecideApplication` (51005), `usp_EnrollStudent` (51016) |
| E2 | Every application status change is kept | SP writes `ApplicationStatusHistory` |
| E3 | No second open application for the same applicant and year | SP `usp_SubmitApplication` (51003) |
| E4 | One enrollment per student per academic year | DB `UQ_Enrollments_StudentId_AcademicYearId`; SP (51017) |
| E5 | No enrollment into a Closed year or after the year ends | SP `usp_EnrollStudent` (51014, 51015) |
| E6 | Withdrawn/Transferred enrollments have a withdrawal date that is not before enrollment | DB `CK_Enrollments_WithdrawnHasDate`, `CK_Enrollments_WithdrawalDate`; SP (51020) |
| E7 | A section placement is in the same academic year as the enrollment | DB composite FKs on `SectionAssignments` |
| E8 | …and in the same branch and grade | SP `usp_AssignSection` (51010); VQ check 14 |
| E9 | At most one open section placement per enrollment; placements don't overlap | DB `IX_SectionAssignments_OpenPerEnrollment`; SP closes the previous placement; VQ check 15 |
| E10 | A section's configurable capacity can't be exceeded without an explicit override | SP `usp_AssignSection` (51012, `@AllowOverCapacity`); VQ info check 17 |
| E11 | Year rollover creates new enrollments (next grade or the same grade) and never overwrites the old year | SP `usp_PromoteStudents` |

## Timetable

| # | Rule | Enforced by |
|---|---|---|
| T1 | Period end time is after its start time; one period per number per bell schedule | DB `CK_Periods_Times`, `UQ_Periods_*` |
| T2 | One subject per day and period in a timetable; the day is 1–7 (ISO) | DB `UQ_TimetableEntries_Timetable_Day_Period`, `CK_TimetableEntries_DayOfWeek` |
| T3 | One Published timetable per section and term; published ones have a publish time | DB `IX_Timetables_PublishedPerSectionTerm`, `CK_Timetables_PublishedAt` |
| T4 | No teacher or room double-booked across published timetables of the same term (overlapping times) | SP `usp_PublishTimetable` (52004); VQ check 19 |
| T5 | Only Draft timetables can be published; publishing archives the previous version (it is not deleted) | SP `usp_PublishTimetable` (52002). Deleting a timetable (only Draft ones; its entries cascade) is APP, because the delivered design has no delete procedure. |

## Attendance

| # | Rule | Enforced by |
|---|---|---|
| AT1 | One roll-call per section, date and period (or per day) | DB `UQ_AttendanceSessions_Section_Date_Period` |
| AT2 | One mark per student per roll-call | DB `UQ_AttendanceRecords_SessionId_EnrollmentId` |
| AT3 | A record's date and section equal its session's | DB composite FK `FK_AttendanceRecords_AttendanceSessions` |
| AT4 | Attendance only on working days, inside the academic year, not on holidays | SP `usp_RecordSectionAttendance` (53002–53004) |
| AT5 | Only students placed in the section on that date can be marked | SP (53009); VQ check 18 |
| AT6 | Status codes come from the active lookup; minutes late is not negative | SP (53008); DB `CK_AttendanceRecords_MinutesLate` |

## Assessment

| # | Rule | Enforced by |
|---|---|---|
| S1 | Assessment type weights per subject and term total 100 | DB `CK_AssessmentWeights_WeightPercent` (each 0–100); VQ check 10 (sum) |
| S2 | A score is between 0 and the assessment's MaxScore | DB `CK_AssessmentResults_Score` (≥ 0); SP `usp_RecordResults` (54004); VQ check 11 |
| S3 | A result has a score unless the student is absent or exempt | DB `CK_AssessmentResults_ScoreOrFlag`; SP (54005) |
| S4 | Only students in the section on the assessment date get results | SP (54006); VQ check 12 |
| S5 | Every grade change is kept with its time and user | DB system-versioned `AssessmentResults` + `UpdatedBy`; view `audit.vw_GradeChangeHistory` |
| S6 | Subject % = Σ(type average × weight) / Σ weight; absent = 0; exempt ignored | Function `assessment.fn_SubjectTermScores` |
| S7 | Letter grade = the highest band whose MinPercent ≤ percentage; pass ≥ the scale's PassPercent | `fn_LetterGrade`; SP `usp_GenerateReportCards` |
| S8 | Published report cards never change; re-issue creates a new version and supersedes the old one | SP `usp_GenerateReportCards` / `usp_PublishReportCards`; DB `IX_ReportCards_PublishedPerEnrollmentTerm`; VQ check 13 |

## Finance

| # | Rule | Enforced by |
|---|---|---|
| F1 | One fee structure per year/branch/grade/program; one item per fee type; installment numbers unique | DB `UQ_FeeStructures_*`, `UQ_FeeStructureItems_*`, `UQ_FeeInstallments_*` |
| F2 | Fee amounts are non-negative; fee changes keep history | DB `CK_FeeStructureItems_Amount`; temporal table |
| F3 | Installment percentages total 100 per structure | **Not enforced in the database** (see Known limitations). The invoicing SP issues per installment. |
| F4 | A payer is exactly one guardian or one sponsor, and each appears as a payer at most once | DB `CK_Payers_ExactlyOne`, `IX_Payers_GuardianId`, `IX_Payers_SponsorId` |
| F5 | Payer responsibility shares per enrollment total 100 | SP `usp_IssueInvoice` (55005); VQ check 20 |
| F6 | A discount is a percentage (0–100] **or** a positive amount; amount discounts name a fee type | DB `CK_StudentDiscounts_Value`, `CK_StudentDiscounts_AmountNeedsFeeType` |
| F7 | A discount never exceeds the amount it applies to; tax applies only to taxable fee types | SP `usp_IssueInvoice` (capped); DB `CK_FeeTypes_TaxPercent` |
| F7a | **Tax rates (project assumption, not legal fact):** tuition is tax-exempt; uniforms are taxed at 16%; other fee types are 0% | Reference data in `07_reference_data.sql` (`finance.FeeTypes.IsTaxable`, `TaxPercent`). Must be confirmed against current Jordanian tax law before any real use. |
| F7b | Single currency: all amounts are in JOD (3 decimal places); multi-currency is out of scope | Reference data and sample data (`finance.Currencies`, school default currency) |
| F8 | Amounts are rounded once, to the currency's minor units, when the invoice is issued | SP `usp_IssueInvoice` (`finance.Currencies.MinorUnits`) |
| F9 | Invoice total = subtotal − discount + tax; paid + credited ≤ total; due date ≥ invoice date | DB `CK_Invoices_Total`, `CK_Invoices_Settlement`, `CK_Invoices_DueDate` |
| F10 | Header totals equal the sum of the lines | SP (computed from the lines); VQ check 21 |
| F11 | An installment is invoiced at most once per enrollment and payer (cancelled invoices excepted) | DB `IX_Invoices_LivePerInstallmentPayer`; SP (55006) |
| F12 | Issued invoices are never edited or deleted; corrections use credit notes; only an unpaid, uncredited invoice may be cancelled | SP `usp_IssueCreditNote` (55022/55023), `usp_CancelInvoice` (55031); DB `CK_Invoices_Cancellation`; APP (no direct DML grant) |
| F13 | Paid amount = Σ allocations; credited = Σ credit notes; status matches the amounts | SP; VQ checks 22–24 |
| F14 | Allocations target open invoices of the same payer and never exceed the balance or the payment | SP `usp_RecordPayment` (55016–55019); VQ checks 25–26 |
| F15 | Methods that need a reference (cheque, transfer, card, eFAWATEERcom) get one, and a reference can't be posted twice | SP (55013); DB `IX_Payments_Method_Reference` |
| F16 | Overpayments stay on account (unallocated) and are visible | View `finance.vw_PaymentAllocationStatus`, `fn_PayerBalance` |

## Audit

| # | Rule | Enforced by |
|---|---|---|
| AU1 | Audit images are valid JSON | DB `CK_AuditEvents_OldValues/NewValues` |
| AU2 | Audit and security logs are append-only | APP / permissions: no UPDATE or DELETE granted on `audit` |
| AU3 | Audit never blocks deletes or archiving of business data | DB: soft references only (no FKs from `audit`) |

## Known limitations

These rules are deliberately **not implemented** in the delivered scope.

| # | Limitation | Consequence |
|---|---|---|
| L1 | **No database check that installment percentages total 100** per fee structure (rule F3) | A mis-configured structure would invoice more or less than 100% of the fees. Whoever enters fee installments must verify the total. |
| L2 | **No payment reversal procedure.** `finance.Payments.PaymentStatus` allows `Reversed`, but no procedure sets it or undoes allocations. | A bounced cheque or wrong posting can't be reversed through the procedures. |

Both are listed in [FUTURE_EXPANSION.md](FUTURE_EXPANSION.md) as possible extensions.
