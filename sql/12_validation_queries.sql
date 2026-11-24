/* =============================================================================
   12_validation_queries.sql
   Purpose     : Post-deployment validation:
                   1. database settings
                   2. object inventory per schema (tables, columns, constraints, indexes)
                   3. naming convention and system-named object checks
                   4. untrusted / disabled FK and CHECK constraints
                   5. FK columns without a supporting index
                   6. orphan checks (DBCC CHECKCONSTRAINTS + soft references)
                   7. row counts per table
                   8. business-rule consistency checks (expected: 0 violations)
                   9. representative business queries
                 A summary (#Checks) lists every check with its violation count;
                 the script ends with an error if any check that must be 0 fails.
   Dependencies: 01..10 (11 optional: without sample data most counts are 0)
   Run order   : 12 of 12
   Idempotent  : Yes (read-only apart from #temp tables).
   ============================================================================= */
USE [$(DatabaseName)];
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'tempdb..#Checks') IS NOT NULL DROP TABLE #Checks;
CREATE TABLE #Checks
(
    CheckNo     INT IDENTITY(1,1) NOT NULL,
    Category    NVARCHAR(40)  COLLATE DATABASE_DEFAULT NOT NULL,
    CheckName   NVARCHAR(200) COLLATE DATABASE_DEFAULT NOT NULL,
    Violations  INT NOT NULL,
    MustBeZero  BIT NOT NULL
);
GO

PRINT N'=== 1. Database settings ===';
SELECT name, collation_name, compatibility_level, recovery_model_desc,
       is_read_committed_snapshot_on, is_query_store_on
FROM   sys.databases WHERE name = DB_NAME();
GO

PRINT N'=== 2. Inventory per schema ===';
WITH s AS (SELECT schema_id, name FROM sys.schemas
           WHERE name IN (N'organization', N'iam', N'people', N'academic', N'enrollment', N'timetable', N'attendance',
                          N'assessment', N'finance', N'audit', N'hr', N'transport', N'library', N'inventory', N'communication'))
SELECT s.name AS SchemaName,
       (SELECT COUNT(*) FROM sys.tables t WHERE t.schema_id = s.schema_id)                                         AS Tables,
       (SELECT COUNT(*) FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id WHERE t.schema_id = s.schema_id) AS Columns,
       (SELECT COUNT(*) FROM sys.key_constraints k WHERE k.schema_id = s.schema_id AND k.type = 'PK')              AS PrimaryKeys,
       (SELECT COUNT(*) FROM sys.key_constraints k WHERE k.schema_id = s.schema_id AND k.type = 'UQ')              AS UniqueKeys,
       (SELECT COUNT(*) FROM sys.foreign_keys f WHERE f.schema_id = s.schema_id)                                   AS ForeignKeys,
       (SELECT COUNT(*) FROM sys.check_constraints c WHERE c.schema_id = s.schema_id)                              AS CheckConstraints,
       (SELECT COUNT(*) FROM sys.default_constraints d WHERE d.schema_id = s.schema_id)                            AS DefaultConstraints,
       (SELECT COUNT(*) FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id
         WHERE t.schema_id = s.schema_id AND i.type > 0 AND i.is_primary_key = 0 AND i.is_unique_constraint = 0)    AS OtherIndexes,
       (SELECT COUNT(*) FROM sys.views v WHERE v.schema_id = s.schema_id)                                          AS Views,
       (SELECT COUNT(*) FROM sys.procedures p WHERE p.schema_id = s.schema_id)                                     AS Procedures,
       (SELECT COUNT(*) FROM sys.objects o WHERE o.schema_id = s.schema_id AND o.type IN ('IF', 'TF', 'FN'))       AS Functions
FROM s ORDER BY s.name;

SELECT SCHEMA_NAME(t.schema_id) AS SchemaName, t.name AS TableName, COUNT(c.column_id) AS Columns,
       t.temporal_type_desc AS TemporalType
FROM   sys.tables AS t JOIN sys.columns AS c ON c.object_id = t.object_id
GROUP BY t.schema_id, t.name, t.temporal_type_desc
ORDER BY SchemaName, TableName;
GO

PRINT N'=== 3. Naming conventions ===';
INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Naming', N'System-named constraints (PK/UQ/FK/CK/DF)',
       (SELECT COUNT(*) FROM sys.key_constraints WHERE is_system_named = 1)
     + (SELECT COUNT(*) FROM sys.foreign_keys WHERE is_system_named = 1)
     + (SELECT COUNT(*) FROM sys.check_constraints WHERE is_system_named = 1)
     + (SELECT COUNT(*) FROM sys.default_constraints WHERE is_system_named = 1), 1;

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Naming', N'Constraints not following PK_/UQ_/FK_/CK_/DF_ prefix', COUNT(*), 1
FROM (SELECT name, type FROM sys.objects WHERE type IN ('PK', 'UQ', 'F', 'C', 'D') AND is_ms_shipped = 0) AS o
WHERE NOT ((o.type = 'PK' AND o.name LIKE N'PK[_]%') OR (o.type = 'UQ' AND o.name LIKE N'UQ[_]%') OR (o.type = 'F' AND o.name LIKE N'FK[_]%')
        OR (o.type = 'C' AND o.name LIKE N'CK[_]%') OR (o.type = 'D' AND o.name LIKE N'DF[_]%'));

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Naming', N'Indexes not named PK_/UQ_/IX_', COUNT(*), 1
FROM   sys.indexes AS i JOIN sys.tables AS t ON t.object_id = i.object_id
WHERE  i.type > 0 AND i.name NOT LIKE N'PK[_]%' AND i.name NOT LIKE N'UQ[_]%' AND i.name NOT LIKE N'IX[_]%';

SELECT o.type_desc, SCHEMA_NAME(o.schema_id) AS SchemaName, o.name
FROM   sys.objects AS o
WHERE  o.is_ms_shipped = 0 AND o.type IN ('PK', 'UQ', 'F', 'C', 'D')
  AND  OBJECTPROPERTY(o.object_id, 'IsSystemNamed') = 1;
GO

PRINT N'=== 4. Untrusted / disabled constraints ===';
INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Integrity', N'Untrusted or disabled foreign keys', COUNT(*), 1 FROM sys.foreign_keys WHERE is_not_trusted = 1 OR is_disabled = 1;
INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Integrity', N'Untrusted or disabled CHECK constraints', COUNT(*), 1 FROM sys.check_constraints WHERE is_not_trusted = 1 OR is_disabled = 1;
SELECT N'FK' AS Kind, OBJECT_SCHEMA_NAME(parent_object_id) AS SchemaName, name, is_not_trusted, is_disabled FROM sys.foreign_keys WHERE is_not_trusted = 1 OR is_disabled = 1
UNION ALL
SELECT N'CK', OBJECT_SCHEMA_NAME(parent_object_id), name, is_not_trusted, is_disabled FROM sys.check_constraints WHERE is_not_trusted = 1 OR is_disabled = 1;
GO

PRINT N'=== 5. Foreign keys without a supporting index (FK leading column = index leading key column) ===';
IF OBJECT_ID(N'tempdb..#MissingFkIndex') IS NOT NULL DROP TABLE #MissingFkIndex;
SELECT OBJECT_SCHEMA_NAME(fk.parent_object_id) AS SchemaName, OBJECT_NAME(fk.parent_object_id) AS TableName,
       fk.name AS ForeignKey, COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS LeadingColumn
INTO   #MissingFkIndex
FROM   sys.foreign_keys AS fk
JOIN   sys.foreign_key_columns AS fkc ON fkc.constraint_object_id = fk.object_id AND fkc.constraint_column_id = 1
WHERE  NOT EXISTS (SELECT 1
                   FROM   sys.indexes AS i
                   JOIN   sys.index_columns AS ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
                   WHERE  i.object_id = fk.parent_object_id AND ic.key_ordinal = 1 AND ic.column_id = fkc.parent_column_id);
INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Indexing', N'Foreign keys without a supporting index', COUNT(*), 1 FROM #MissingFkIndex;
SELECT * FROM #MissingFkIndex ORDER BY SchemaName, TableName;
GO

PRINT N'=== 6. Orphan checks ===';
-- 6a. Every FK and CHECK re-validated against the data (catches rows loaded while a constraint was disabled).
IF OBJECT_ID(N'tempdb..#ConstraintViolations') IS NOT NULL DROP TABLE #ConstraintViolations;
CREATE TABLE #ConstraintViolations (TableName NVARCHAR(400) COLLATE DATABASE_DEFAULT, ConstraintName NVARCHAR(400) COLLATE DATABASE_DEFAULT, WhereClause NVARCHAR(4000) COLLATE DATABASE_DEFAULT);
INSERT INTO #ConstraintViolations EXEC (N'DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS, NO_INFOMSGS;');
INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Orphans', N'DBCC CHECKCONSTRAINTS violations (FK + CHECK)', COUNT(*), 1 FROM #ConstraintViolations;
SELECT * FROM #ConstraintViolations;

-- 6b. Soft references (no FK by design): CreatedBy/UpdatedBy and audit user ids.
DECLARE @sql NVARCHAR(MAX) = N'', @orphans INT = 0;
SELECT @sql = STRING_AGG(CONVERT(NVARCHAR(MAX),
        N'SELECT COUNT(*) AS n FROM ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name)
      + N' AS x WHERE x.' + QUOTENAME(c.name) + N' IS NOT NULL AND NOT EXISTS (SELECT 1 FROM iam.UserAccounts AS u WHERE u.UserAccountId = x.' + QUOTENAME(c.name) + N')'),
        N' UNION ALL ')
FROM   sys.tables AS t JOIN sys.columns AS c ON c.object_id = t.object_id
WHERE  c.name IN (N'CreatedBy', N'UpdatedBy', N'ChangedBy', N'ApprovedByUserId', N'ReceivedByUserId')
   OR (c.name = N'UserAccountId' AND SCHEMA_NAME(t.schema_id) = N'audit');
SET @sql = N'SELECT @o = SUM(n) FROM (' + @sql + N') AS q;';
EXEC sys.sp_executesql @sql, N'@o INT OUTPUT', @o = @orphans OUTPUT;
INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
VALUES (N'Orphans', N'Soft user references not found in iam.UserAccounts', ISNULL(@orphans, 0), 1);

-- 6c. People with no role at all (allowed: applicants, contacts) - informational.
INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Info', N'Persons without any subtype role (applicants / contacts; allowed)', COUNT(*), 0
FROM   people.vw_PersonRoles WHERE RoleCount = 0;
GO

PRINT N'=== 7. Row counts ===';
SELECT SCHEMA_NAME(t.schema_id) AS SchemaName, t.name AS TableName, SUM(p.rows) AS RowCount_
FROM   sys.tables AS t
JOIN   sys.partitions AS p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY t.schema_id, t.name
ORDER BY SchemaName, TableName;
GO

PRINT N'=== 8. Business-rule consistency checks ===';
INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Assessment', N'Assessment weights not totalling 100 per subject and term', COUNT(*), 1
FROM (SELECT CurriculumSubjectId, TermId FROM assessment.AssessmentWeights GROUP BY CurriculumSubjectId, TermId HAVING SUM(WeightPercent) <> 100) AS x;

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Assessment', N'Scores above the assessment MaxScore', COUNT(*), 1
FROM assessment.AssessmentResults AS r JOIN assessment.Assessments AS a ON a.AssessmentId = r.AssessmentId WHERE r.Score > a.MaxScore;

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Assessment', N'Results for students not in the section on the assessment date', COUNT(*), 1
FROM assessment.AssessmentResults AS r
JOIN assessment.Assessments AS a ON a.AssessmentId = r.AssessmentId
JOIN academic.TeachingAssignments AS ta ON ta.TeachingAssignmentId = a.TeachingAssignmentId
WHERE NOT EXISTS (SELECT 1 FROM enrollment.SectionAssignments AS sa WHERE sa.EnrollmentId = r.EnrollmentId AND sa.SectionId = ta.SectionId
                  AND sa.StartDate <= a.AssessmentDate AND (sa.EndDate IS NULL OR sa.EndDate >= a.AssessmentDate));

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Assessment', N'Published report cards per enrollment+term > 1', COUNT(*), 1
FROM (SELECT EnrollmentId, TermId FROM assessment.ReportCards WHERE ReportCardStatus = N'Published' GROUP BY EnrollmentId, TermId HAVING COUNT(*) > 1) AS x;

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Enrollment', N'Section assignments whose branch/grade differ from the enrollment', COUNT(*), 1
FROM enrollment.SectionAssignments AS sa
JOIN enrollment.Enrollments AS e ON e.EnrollmentId = sa.EnrollmentId
JOIN academic.Sections AS s ON s.SectionId = sa.SectionId
WHERE s.BranchId <> e.BranchId OR s.GradeLevelId <> e.GradeLevelId;

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Enrollment', N'Overlapping section assignments for one enrollment', COUNT(*), 1
FROM enrollment.SectionAssignments AS a
JOIN enrollment.SectionAssignments AS b ON b.EnrollmentId = a.EnrollmentId AND b.SectionAssignmentId > a.SectionAssignmentId
WHERE a.StartDate <= ISNULL(b.EndDate, '99991231') AND b.StartDate <= ISNULL(a.EndDate, '99991231');

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Enrollment', N'Enrolled students without an open section assignment (active year)', COUNT(*), 0
FROM enrollment.Enrollments AS e JOIN academic.AcademicYears AS ay ON ay.AcademicYearId = e.AcademicYearId AND ay.YearStatus = N'Active'
WHERE e.EnrollmentStatus = N'Enrolled'
  AND NOT EXISTS (SELECT 1 FROM enrollment.SectionAssignments AS sa WHERE sa.EnrollmentId = e.EnrollmentId AND sa.EndDate IS NULL);

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Info', N'Sections over their configured capacity (override used)', COUNT(*), 0
FROM academic.vw_SectionOccupancy WHERE Capacity IS NOT NULL AND CurrentStudents > Capacity;

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Attendance', N'Attendance records outside the student''s section placement', COUNT(*), 1
FROM attendance.AttendanceRecords AS r
WHERE NOT EXISTS (SELECT 1 FROM enrollment.SectionAssignments AS sa WHERE sa.EnrollmentId = r.EnrollmentId AND sa.SectionId = r.SectionId
                  AND sa.StartDate <= r.SessionDate AND (sa.EndDate IS NULL OR sa.EndDate >= r.SessionDate));

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Timetable', N'Teacher or room clashes between published timetables', COUNT(*), 1
FROM timetable.TimetableEntries AS e1
JOIN timetable.Timetables AS t1 ON t1.TimetableId = e1.TimetableId AND t1.TimetableStatus = N'Published'
JOIN timetable.Periods AS p1 ON p1.PeriodId = e1.PeriodId
JOIN academic.TeachingAssignments AS a1 ON a1.TeachingAssignmentId = e1.TeachingAssignmentId
JOIN timetable.TimetableEntries AS e2 ON e2.TimetableEntryId > e1.TimetableEntryId AND e2.DayOfWeek = e1.DayOfWeek
JOIN timetable.Timetables AS t2 ON t2.TimetableId = e2.TimetableId AND t2.TimetableStatus = N'Published' AND t2.TermId = t1.TermId AND t2.TimetableId <> t1.TimetableId
JOIN timetable.Periods AS p2 ON p2.PeriodId = e2.PeriodId AND p2.StartTime < p1.EndTime AND p1.StartTime < p2.EndTime
JOIN academic.TeachingAssignments AS a2 ON a2.TeachingAssignmentId = e2.TeachingAssignmentId
WHERE a1.TeacherId = a2.TeacherId OR e1.RoomId = e2.RoomId;

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Finance', N'Payer responsibility not totalling 100 per enrollment', COUNT(*), 1
FROM (SELECT EnrollmentId FROM finance.StudentPayers GROUP BY EnrollmentId HAVING SUM(ResponsibilityPercent) <> 100) AS x;

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Finance', N'Invoice header totals differ from the sum of lines', COUNT(*), 1
FROM finance.Invoices AS i
CROSS APPLY (SELECT SUM(l.Quantity * l.UnitAmount) AS Sub, SUM(l.DiscountAmount) AS Disc, SUM(l.TaxAmount) AS Tax, SUM(l.LineTotal) AS Tot
             FROM finance.InvoiceLines AS l WHERE l.InvoiceId = i.InvoiceId) AS s
WHERE i.SubtotalAmount <> ISNULL(s.Sub, 0) OR i.DiscountAmount <> ISNULL(s.Disc, 0) OR i.TaxAmount <> ISNULL(s.Tax, 0) OR i.TotalAmount <> ISNULL(s.Tot, 0);

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Finance', N'Invoice PaidAmount differs from its payment allocations', COUNT(*), 1
FROM finance.Invoices AS i
OUTER APPLY (SELECT SUM(pa.AllocatedAmount) AS Alloc FROM finance.PaymentAllocations AS pa WHERE pa.InvoiceId = i.InvoiceId) AS a
WHERE i.PaidAmount <> ISNULL(a.Alloc, 0);

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Finance', N'Invoice CreditedAmount differs from its credit notes', COUNT(*), 1
FROM finance.Invoices AS i
OUTER APPLY (SELECT SUM(cn.Amount) AS Cr FROM finance.CreditNotes AS cn WHERE cn.InvoiceId = i.InvoiceId) AS c
WHERE i.CreditedAmount <> ISNULL(c.Cr, 0);

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Finance', N'Invoice status inconsistent with paid/credited amounts', COUNT(*), 1
FROM finance.Invoices
WHERE (InvoiceStatus = N'Paid'          AND PaidAmount + CreditedAmount <> TotalAmount)
   OR (InvoiceStatus = N'PartiallyPaid' AND (PaidAmount = 0 OR PaidAmount + CreditedAmount >= TotalAmount))
   OR (InvoiceStatus = N'Issued'        AND PaidAmount <> 0)
   OR (InvoiceStatus = N'Cancelled'     AND (PaidAmount <> 0 OR CreditedAmount <> 0));

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Finance', N'Payments allocated beyond their amount', COUNT(*), 1
FROM finance.vw_PaymentAllocationStatus WHERE UnallocatedAmount < 0;

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Finance', N'Allocations to another payer''s invoice', COUNT(*), 1
FROM finance.PaymentAllocations AS pa
JOIN finance.Payments AS p ON p.PaymentId = pa.PaymentId
JOIN finance.Invoices AS i ON i.InvoiceId = pa.InvoiceId
WHERE p.PayerId <> i.PayerId;

INSERT INTO #Checks (Category, CheckName, Violations, MustBeZero)
SELECT N'Design', N'CHECK constraints that look like a global student cap', COUNT(*), 1
FROM sys.check_constraints
WHERE definition LIKE N'%student%' AND (definition LIKE N'%1500%' OR definition LIKE N'%3000%' OR definition LIKE N'%COUNT%');
GO

PRINT N'=== 9. Representative business queries ===';
DECLARE @Y2 INT = (SELECT AcademicYearId FROM academic.AcademicYears WHERE YearStatus = N'Active');

PRINT N'-- 9.1 Current rosters (active year)';
SELECT YearCode, SectionNameEn, SectionNameAr, StudentNumber, StudentNameEn, StudentNameAr
FROM   enrollment.vw_CurrentSectionRoster WHERE AcademicYearId = @Y2 ORDER BY SectionNameEn, StudentNameEn;

PRINT N'-- 9.2 Section occupancy vs configurable capacity';
SELECT NameEn, Capacity, CurrentStudents, SeatsRemaining FROM academic.vw_SectionOccupancy WHERE AcademicYearId = @Y2 ORDER BY NameEn;

PRINT N'-- 9.3 Attendance rate by section and date (section + date access path)';
SELECT sec.NameEn AS Section, d.SessionDate, d.StudentsRecorded, d.PresentCount, d.LateCount, d.UnexcusedAbsentCount, d.ExcusedAbsentCount, d.AttendanceRatePercent
FROM   attendance.vw_DailySectionAttendance AS d JOIN academic.Sections AS sec ON sec.SectionId = d.SectionId
WHERE  sec.AcademicYearId = @Y2 ORDER BY sec.NameEn, d.SessionDate;

PRINT N'-- 9.4 One student''s attendance history (student + date access path)';
SELECT TOP (10) r.SessionDate, st.NameEn AS Status, st.NameAr AS StatusAr, r.MinutesLate
FROM   attendance.AttendanceRecords AS r
JOIN   attendance.AttendanceStatuses AS st ON st.AttendanceStatusId = r.AttendanceStatusId
WHERE  r.EnrollmentId = (SELECT MIN(EnrollmentId) FROM enrollment.Enrollments)
ORDER BY r.SessionDate;

PRINT N'-- 9.5 Published report cards (latest closed year, term 2)';
SELECT TOP (20) p.FullNameEn, t.NameEn AS Term, rc.VersionNumber, rc.OverallPercent, rc.DaysPresent, rc.DaysAbsent,
       sub.NameEn AS Subject, l.SubjectPercent, l.LetterGrade, l.IsPassed
FROM   assessment.ReportCards AS rc
JOIN   assessment.ReportCardLines AS l ON l.ReportCardId = rc.ReportCardId
JOIN   academic.CurriculumSubjects AS cs ON cs.CurriculumSubjectId = l.CurriculumSubjectId
JOIN   academic.Subjects AS sub ON sub.SubjectId = cs.SubjectId
JOIN   academic.Terms AS t ON t.TermId = rc.TermId
JOIN   enrollment.Enrollments AS e ON e.EnrollmentId = rc.EnrollmentId
JOIN   people.vw_PersonDirectory AS p ON p.PersonId = e.StudentId
WHERE  rc.ReportCardStatus = N'Published' AND t.TermNumber = 2
ORDER BY p.FullNameEn, cs.ReportOrder;

PRINT N'-- 9.6 Grade-change history from the temporal table';
SELECT h.AssessmentResultId, h.Score, h.ValidFromUtc, h.ValidToUtc, h.IsCurrent
FROM   audit.vw_GradeChangeHistory AS h
WHERE  h.AssessmentResultId IN (SELECT AssessmentResultId FROM audit.vw_GradeChangeHistory GROUP BY AssessmentResultId HAVING COUNT(*) > 1)
ORDER BY h.AssessmentResultId, h.ValidFromUtc;

PRINT N'-- 9.7 Outstanding and overdue invoices';
SELECT InvoiceNumber, PayerNameEn, PayerNameAr, DueDate, TotalAmount, PaidAmount, CreditedAmount, BalanceAmount, DaysOverdue, InvoiceStatus
FROM   finance.vw_InvoiceBalances WHERE BalanceAmount > 0 AND InvoiceStatus <> N'Cancelled' ORDER BY DaysOverdue DESC, DueDate;

PRINT N'-- 9.8 Payer statement with running balance (sponsor payer)';
SELECT ps.MovementDate, ps.MovementType, ps.DocumentNumber, ps.Debit, ps.Credit, ps.RunningBalance
FROM   finance.vw_PayerStatement AS ps
WHERE  ps.PayerId = (SELECT MIN(PayerId) FROM finance.Payers WHERE PayerType = N'Sponsor')
ORDER BY ps.MovementDate, ps.DocumentNumber;

PRINT N'-- 9.9 Payer balances (category: Guardian | Sponsor)';
SELECT pd.PayerType, pd.PayerNameEn, b.TotalInvoiced, b.TotalAllocatedPayments, b.TotalCredited, b.OutstandingBalance, b.UnallocatedPayments
FROM   finance.vw_PayerDirectory AS pd CROSS APPLY finance.fn_PayerBalance(pd.PayerId) AS b
ORDER BY pd.PayerType, pd.PayerNameEn;

PRINT N'-- 9.10 Overlapping roles (persons holding more than one role)';
SELECT FullNameEn, FullNameAr, IsStudent, IsGuardian, IsEmployee, IsTeacher
FROM   people.vw_PersonDirectory WHERE (CAST(IsStudent AS INT) + IsGuardian + IsEmployee) > 1;

PRINT N'-- 9.11 Arabic search ignoring hamza/madda and tashkeel: "ادم" finds "آدم"';
SELECT PersonId, FullNameEn, FullNameAr FROM people.fn_SearchPersons(N'ادم');

PRINT N'-- 9.12 School days in the current term for the Amman branch';
SELECT COUNT(*) AS SchoolDaysInTerm1
FROM   academic.fn_SchoolDays((SELECT BranchId FROM organization.Branches WHERE BranchCode = N'AMM'),
                              (SELECT StartDate FROM academic.Terms WHERE AcademicYearId = @Y2 AND TermNumber = 1),
                              (SELECT EndDate FROM academic.Terms WHERE AcademicYearId = @Y2 AND TermNumber = 1));

PRINT N'-- 9.13 Published timetable (Grade 6 - A, Sunday)';
SELECT SectionNameEn, DayOfWeek, PeriodNumber, StartTime, EndTime, SubjectNameEn, SubjectNameAr, TeacherNameEn, RoomCode
FROM   timetable.vw_PublishedTimetable WHERE SectionNameEn = N'Grade 6 - A' AND DayOfWeek = 7 ORDER BY PeriodNumber;

PRINT N'-- 9.14 Audit trail: events by type';
SELECT EventType, COUNT(*) AS Events, MIN(OccurredAt) AS FirstUtc, MAX(OccurredAt) AS LastUtc
FROM   audit.AuditEvents GROUP BY EventType ORDER BY EventType;
GO

PRINT N'=== SUMMARY ===';
SELECT CheckNo, Category, CheckName, Violations,
       CASE WHEN MustBeZero = 0 THEN N'INFO' WHEN Violations = 0 THEN N'PASS' ELSE N'FAIL' END AS Result
FROM   #Checks ORDER BY CheckNo;

IF EXISTS (SELECT 1 FROM #Checks WHERE MustBeZero = 1 AND Violations > 0)
    THROW 50999, N'Validation failed: see the SUMMARY result set.', 1;
ELSE
    PRINT N'All mandatory validation checks passed.';
GO
