/* =============================================================================
   08_views.sql
   Purpose     : Read models for common business questions.
   Dependencies: 07_reference_data.sql (tables only; no view depends on a
                 function, so 10_functions.sql may run later)
   Run order   : 8 of 12
   Idempotent  : Yes (CREATE OR ALTER VIEW).
   ============================================================================= */
USE [$(DatabaseName)];
GO

/* ---------------------------------------------------------------------------
   people.vw_PersonRoles — overlapping role flags derived from subtype rows.
   --------------------------------------------------------------------------- */
CREATE OR ALTER VIEW people.vw_PersonRoles
AS
SELECT  p.PersonId,
        CAST(CASE WHEN s.PersonId IS NULL THEN 0 ELSE 1 END AS BIT) AS IsStudent,
        CAST(CASE WHEN g.PersonId IS NULL THEN 0 ELSE 1 END AS BIT) AS IsGuardian,
        CAST(CASE WHEN e.PersonId IS NULL THEN 0 ELSE 1 END AS BIT) AS IsEmployee,
        CAST(CASE WHEN t.PersonId IS NULL THEN 0 ELSE 1 END AS BIT) AS IsTeacher,
        CASE WHEN s.PersonId IS NULL THEN 0 ELSE 1 END
      + CASE WHEN g.PersonId IS NULL THEN 0 ELSE 1 END
      + CASE WHEN e.PersonId IS NULL THEN 0 ELSE 1 END                AS RoleCount
FROM    people.Persons   AS p
LEFT JOIN people.Students  AS s ON s.PersonId = p.PersonId
LEFT JOIN people.Guardians AS g ON g.PersonId = p.PersonId
LEFT JOIN people.Employees AS e ON e.PersonId = p.PersonId
LEFT JOIN people.Teachers  AS t ON t.PersonId = p.PersonId;
GO

/* ---------------------------------------------------------------------------
   people.vw_PersonDirectory — bilingual full names, primary contacts, roles.
   --------------------------------------------------------------------------- */
CREATE OR ALTER VIEW people.vw_PersonDirectory
AS
SELECT  p.PersonId,
        CONCAT_WS(N' ', p.FirstNameEn, p.FatherNameEn, p.GrandfatherNameEn, p.FamilyNameEn) AS FullNameEn,
        CONCAT_WS(N' ', p.FirstNameAr, p.FatherNameAr, p.GrandfatherNameAr, p.FamilyNameAr) AS FullNameAr,
        p.Gender,
        p.DateOfBirth,
        c.NationalityEn,
        c.NationalityAr,
        mob.ContactValue  AS PrimaryMobile,
        eml.ContactValue  AS PrimaryEmail,
        r.IsStudent, r.IsGuardian, r.IsEmployee, r.IsTeacher
FROM    people.Persons AS p
JOIN    people.vw_PersonRoles AS r ON r.PersonId = p.PersonId
LEFT JOIN organization.Countries AS c ON c.CountryId = p.NationalityCountryId
LEFT JOIN people.PersonContacts AS mob ON mob.PersonId = p.PersonId AND mob.ContactType = N'Mobile' AND mob.IsPrimary = 1
LEFT JOIN people.PersonContacts AS eml ON eml.PersonId = p.PersonId AND eml.ContactType = N'Email'  AND eml.IsPrimary = 1;
GO

/* ---------------------------------------------------------------------------
   enrollment.vw_CurrentSectionRoster — students currently placed in a section.
   --------------------------------------------------------------------------- */
CREATE OR ALTER VIEW enrollment.vw_CurrentSectionRoster
AS
SELECT  ay.AcademicYearId,
        ay.YearCode,
        sec.BranchId,
        sec.SectionId,
        sec.NameEn        AS SectionNameEn,
        sec.NameAr        AS SectionNameAr,
        gl.Code           AS GradeLevelCode,
        e.EnrollmentId,
        e.StudentId,
        st.StudentNumber,
        CONCAT_WS(N' ', p.FirstNameEn, p.FatherNameEn, p.FamilyNameEn) AS StudentNameEn,
        CONCAT_WS(N' ', p.FirstNameAr, p.FatherNameAr, p.FamilyNameAr) AS StudentNameAr,
        sa.StartDate      AS InSectionSince
FROM    enrollment.SectionAssignments AS sa
JOIN    enrollment.Enrollments AS e   ON e.EnrollmentId = sa.EnrollmentId
JOIN    academic.Sections      AS sec ON sec.SectionId = sa.SectionId
JOIN    academic.AcademicYears AS ay  ON ay.AcademicYearId = sa.AcademicYearId
JOIN    academic.GradeLevels   AS gl  ON gl.GradeLevelId = sec.GradeLevelId
JOIN    people.Students        AS st  ON st.PersonId = e.StudentId
JOIN    people.Persons         AS p   ON p.PersonId = e.StudentId
WHERE   sa.EndDate IS NULL
  AND   e.EnrollmentStatus = N'Enrolled';
GO

/* ---------------------------------------------------------------------------
   academic.vw_SectionOccupancy — configurable per-section capacity vs. roster.
   Capacity NULL means "not limited"; no system-wide student limit exists.
   --------------------------------------------------------------------------- */
CREATE OR ALTER VIEW academic.vw_SectionOccupancy
AS
SELECT  sec.SectionId,
        sec.AcademicYearId,
        sec.BranchId,
        sec.GradeLevelId,
        sec.NameEn,
        sec.NameAr,
        sec.Capacity,
        COUNT(sa.SectionAssignmentId)                         AS CurrentStudents,
        sec.Capacity - COUNT(sa.SectionAssignmentId)          AS SeatsRemaining
FROM    academic.Sections AS sec
LEFT JOIN enrollment.SectionAssignments AS sa
       ON sa.SectionId = sec.SectionId AND sa.EndDate IS NULL
GROUP BY sec.SectionId, sec.AcademicYearId, sec.BranchId, sec.GradeLevelId, sec.NameEn, sec.NameAr, sec.Capacity;
GO

/* ---------------------------------------------------------------------------
   attendance.vw_DailySectionAttendance — per section / date / session counts.
   --------------------------------------------------------------------------- */
CREATE OR ALTER VIEW attendance.vw_DailySectionAttendance
AS
SELECT  s.AttendanceSessionId,
        s.SectionId,
        s.SessionDate,
        s.PeriodId,
        COUNT(r.AttendanceRecordId)                                         AS StudentsRecorded,
        SUM(CASE WHEN st.CountsAsPresent = 1 THEN 1 ELSE 0 END)             AS PresentCount,
        SUM(CASE WHEN st.Code = N'LATE' THEN 1 ELSE 0 END)                  AS LateCount,
        SUM(CASE WHEN st.CountsAsPresent = 0 AND st.IsExcused = 0 THEN 1 ELSE 0 END) AS UnexcusedAbsentCount,
        SUM(CASE WHEN st.IsExcused = 1 THEN 1 ELSE 0 END)                   AS ExcusedAbsentCount,
        CAST(100.0 * SUM(CASE WHEN st.CountsAsPresent = 1 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(r.AttendanceRecordId), 0) AS DECIMAL(7,4))      AS AttendanceRatePercent
FROM    attendance.AttendanceSessions AS s
LEFT JOIN attendance.AttendanceRecords  AS r  ON r.AttendanceSessionId = s.AttendanceSessionId
LEFT JOIN attendance.AttendanceStatuses AS st ON st.AttendanceStatusId = r.AttendanceStatusId
GROUP BY s.AttendanceSessionId, s.SectionId, s.SessionDate, s.PeriodId;
GO

/* ---------------------------------------------------------------------------
   assessment.vw_StudentResults — every result with subject, term and percent.
   --------------------------------------------------------------------------- */
CREATE OR ALTER VIEW assessment.vw_StudentResults
AS
SELECT  ar.AssessmentResultId,
        ar.EnrollmentId,
        e.StudentId,
        a.TermId,
        cs.CurriculumSubjectId,
        sub.SubjectCode,
        sub.NameEn          AS SubjectNameEn,
        sub.NameAr          AS SubjectNameAr,
        a.AssessmentId,
        a.TitleEn,
        at.Code             AS AssessmentTypeCode,
        a.AssessmentDate,
        a.MaxScore,
        ar.Score,
        ar.IsAbsent,
        ar.IsExempt,
        CAST(100.0 * ar.Score / a.MaxScore AS DECIMAL(9,3)) AS ScorePercent
FROM    assessment.AssessmentResults   AS ar
JOIN    assessment.Assessments         AS a   ON a.AssessmentId = ar.AssessmentId
JOIN    assessment.AssessmentTypes     AS at  ON at.AssessmentTypeId = a.AssessmentTypeId
JOIN    academic.TeachingAssignments   AS ta  ON ta.TeachingAssignmentId = a.TeachingAssignmentId
JOIN    academic.CurriculumSubjects    AS cs  ON cs.CurriculumSubjectId = ta.CurriculumSubjectId
JOIN    academic.Subjects              AS sub ON sub.SubjectId = cs.SubjectId
JOIN    enrollment.Enrollments         AS e   ON e.EnrollmentId = ar.EnrollmentId;
GO

/* ---------------------------------------------------------------------------
   finance.vw_PayerDirectory — resolves the payer category (Guardian | Sponsor).
   --------------------------------------------------------------------------- */
CREATE OR ALTER VIEW finance.vw_PayerDirectory
AS
SELECT  py.PayerId,
        py.PayerType,
        py.GuardianId,
        py.SponsorId,
        -- CONCAT_WS returns '' (not NULL) when every part is NULL, so branch on the category explicitly.
        CASE py.PayerType WHEN N'Guardian' THEN CONCAT_WS(N' ', gp.FirstNameEn, gp.FatherNameEn, gp.FamilyNameEn) ELSE sp.NameEn END AS PayerNameEn,
        CASE py.PayerType WHEN N'Guardian' THEN CONCAT_WS(N' ', gp.FirstNameAr, gp.FatherNameAr, gp.FamilyNameAr) ELSE sp.NameAr END AS PayerNameAr,
        py.IsActive
FROM    finance.Payers AS py
LEFT JOIN people.Persons   AS gp ON gp.PersonId = py.GuardianId
LEFT JOIN finance.Sponsors AS sp ON sp.SponsorId = py.SponsorId;
GO

/* ---------------------------------------------------------------------------
   finance.vw_InvoiceBalances — outstanding balance and overdue days.
   --------------------------------------------------------------------------- */
CREATE OR ALTER VIEW finance.vw_InvoiceBalances
AS
SELECT  i.InvoiceId,
        i.InvoiceNumber,
        i.BranchId,
        i.EnrollmentId,
        e.StudentId,
        i.PayerId,
        pd.PayerNameEn,
        pd.PayerNameAr,
        i.InvoiceDate,
        i.DueDate,
        i.TotalAmount,
        i.PaidAmount,
        i.CreditedAmount,
        i.TotalAmount - i.PaidAmount - i.CreditedAmount AS BalanceAmount,
        i.InvoiceStatus,
        CASE WHEN i.InvoiceStatus IN (N'Issued', N'PartiallyPaid')
                  AND i.DueDate < CONVERT(DATE, SYSUTCDATETIME())
             THEN DATEDIFF(DAY, i.DueDate, CONVERT(DATE, SYSUTCDATETIME()))
             ELSE 0 END                                AS DaysOverdue
FROM    finance.Invoices AS i
JOIN    enrollment.Enrollments AS e  ON e.EnrollmentId = i.EnrollmentId
JOIN    finance.vw_PayerDirectory AS pd ON pd.PayerId = i.PayerId;
GO

/* ---------------------------------------------------------------------------
   finance.vw_PayerStatement — debits (invoices) and credits (payments, credit
   notes) per payer with a running balance.
   --------------------------------------------------------------------------- */
CREATE OR ALTER VIEW finance.vw_PayerStatement
AS
WITH Movements AS
(
    SELECT i.PayerId, i.InvoiceDate AS MovementDate, N'Invoice' AS MovementType,
           i.InvoiceNumber AS DocumentNumber, i.TotalAmount AS Debit, CAST(0 AS DECIMAL(19,4)) AS Credit, i.IssuedAt AS SortStamp
    FROM   finance.Invoices AS i
    WHERE  i.InvoiceStatus <> N'Cancelled'
    UNION ALL
    SELECT p.PayerId, p.PaymentDate, N'Payment', p.ReceiptNumber, 0, p.Amount, p.CreatedAt
    FROM   finance.Payments AS p
    WHERE  p.PaymentStatus = N'Received'
    UNION ALL
    SELECT i.PayerId, cn.CreditDate, N'CreditNote', cn.CreditNoteNumber, 0, cn.Amount, cn.CreatedAt
    FROM   finance.CreditNotes AS cn
    JOIN   finance.Invoices    AS i ON i.InvoiceId = cn.InvoiceId
)
SELECT  m.PayerId,
        m.MovementDate,
        m.MovementType,
        m.DocumentNumber,
        m.Debit,
        m.Credit,
        SUM(m.Debit - m.Credit) OVER (PARTITION BY m.PayerId ORDER BY m.MovementDate, m.SortStamp, m.DocumentNumber
                                      ROWS UNBOUNDED PRECEDING) AS RunningBalance
FROM    Movements AS m;
GO

/* ---------------------------------------------------------------------------
   finance.vw_PaymentAllocationStatus — allocated vs. unallocated (on-account).
   --------------------------------------------------------------------------- */
CREATE OR ALTER VIEW finance.vw_PaymentAllocationStatus
AS
SELECT  p.PaymentId,
        p.ReceiptNumber,
        p.PayerId,
        p.PaymentDate,
        p.Amount,
        ISNULL(SUM(pa.AllocatedAmount), 0)            AS AllocatedAmount,
        p.Amount - ISNULL(SUM(pa.AllocatedAmount), 0) AS UnallocatedAmount,
        p.PaymentStatus
FROM    finance.Payments AS p
LEFT JOIN finance.PaymentAllocations AS pa ON pa.PaymentId = p.PaymentId
GROUP BY p.PaymentId, p.ReceiptNumber, p.PayerId, p.PaymentDate, p.Amount, p.PaymentStatus;
GO

/* ---------------------------------------------------------------------------
   timetable.vw_PublishedTimetable — the weekly grid of published timetables.
   --------------------------------------------------------------------------- */
CREATE OR ALTER VIEW timetable.vw_PublishedTimetable
AS
SELECT  tt.TimetableId,
        tt.SectionId,
        sec.NameEn            AS SectionNameEn,
        tt.TermId,
        te.DayOfWeek,
        pr.PeriodNumber,
        pr.StartTime,
        pr.EndTime,
        sub.SubjectCode,
        sub.NameEn            AS SubjectNameEn,
        sub.NameAr            AS SubjectNameAr,
        ta.TeacherId,
        CONCAT_WS(N' ', tp.FirstNameEn, tp.FamilyNameEn) AS TeacherNameEn,
        te.RoomId,
        rm.RoomCode
FROM    timetable.Timetables       AS tt
JOIN    timetable.TimetableEntries AS te  ON te.TimetableId = tt.TimetableId
JOIN    timetable.Periods          AS pr  ON pr.PeriodId = te.PeriodId
JOIN    academic.Sections          AS sec ON sec.SectionId = tt.SectionId
JOIN    academic.TeachingAssignments AS ta ON ta.TeachingAssignmentId = te.TeachingAssignmentId
JOIN    academic.CurriculumSubjects AS cs ON cs.CurriculumSubjectId = ta.CurriculumSubjectId
JOIN    academic.Subjects          AS sub ON sub.SubjectId = cs.SubjectId
JOIN    people.Persons             AS tp  ON tp.PersonId = ta.TeacherId
LEFT JOIN organization.Rooms       AS rm  ON rm.RoomId = te.RoomId
WHERE   tt.TimetableStatus = N'Published';
GO

/* ---------------------------------------------------------------------------
   audit.vw_GradeChangeHistory — every version of every result (temporal).
   --------------------------------------------------------------------------- */
CREATE OR ALTER VIEW audit.vw_GradeChangeHistory
AS
SELECT  ar.AssessmentResultId,
        ar.AssessmentId,
        ar.EnrollmentId,
        ar.Score,
        ar.IsAbsent,
        ar.IsExempt,
        ar.UpdatedBy,
        ar.SysStartTime AS ValidFromUtc,
        ar.SysEndTime   AS ValidToUtc,
        CASE WHEN ar.SysEndTime = CONVERT(DATETIME2(7), '9999-12-31 23:59:59.9999999') THEN 1 ELSE 0 END AS IsCurrent
FROM    assessment.AssessmentResults FOR SYSTEM_TIME ALL AS ar;
GO
