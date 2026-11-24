/* =============================================================================
   10_functions.sql
   Purpose     : Inline table-valued functions (no scalar UDFs: inline TVFs are
                 expanded into the calling query and stay set-based).
   Dependencies: 09_stored_procedures.sql
   Run order   : 10 of 12
   Idempotent  : Yes (CREATE OR ALTER FUNCTION).
   ============================================================================= */
USE [$(DatabaseName)];
GO

/* ---------------------------------------------------------------------------
   people.fn_NormalizeArabicText — search normalisation. SQL Server collations
   (including Arabic_100_CI_AI_SC) do NOT ignore Arabic diacritics or alef
   variants, so name search normalises both sides explicitly:
   strips tashkeel (U+064B..U+0652) and tatweel (U+0640), maps
   أ إ آ ٱ -> ا, ى -> ي, ة -> ه. Binary collation makes the replacements exact.
   --------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION people.fn_NormalizeArabicText (@Text NVARCHAR(400))
RETURNS TABLE
AS
RETURN
    SELECT NormalizedText =
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            TRANSLATE(@Text COLLATE Arabic_100_BIN2,
                      NCHAR(1571) + NCHAR(1573) + NCHAR(1570) + NCHAR(1649) + NCHAR(1609) + NCHAR(1577),
                      NCHAR(1575) + NCHAR(1575) + NCHAR(1575) + NCHAR(1575) + NCHAR(1610) + NCHAR(1607)),
            NCHAR(1611), N''), NCHAR(1612), N''), NCHAR(1613), N''), NCHAR(1614), N''), NCHAR(1615), N''),
            NCHAR(1616), N''), NCHAR(1617), N''), NCHAR(1618), N''), NCHAR(1600), N'');
GO

/* ---------------------------------------------------------------------------
   people.fn_SearchPersons — bilingual name search (English via the database's
   case/accent-insensitive collation; Arabic via explicit normalisation).
   Not index-seekable by design; see FUTURE_EXPANSION.md for the persisted
   normalised-name column suggested if search volume grows.
   --------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION people.fn_SearchPersons (@SearchText NVARCHAR(200))
RETURNS TABLE
AS
RETURN
    SELECT  p.PersonId,
            CONCAT_WS(N' ', p.FirstNameEn, p.FatherNameEn, p.GrandfatherNameEn, p.FamilyNameEn) AS FullNameEn,
            CONCAT_WS(N' ', p.FirstNameAr, p.FatherNameAr, p.GrandfatherNameAr, p.FamilyNameAr) AS FullNameAr,
            p.DateOfBirth
    FROM    people.Persons AS p
    CROSS APPLY people.fn_NormalizeArabicText(@SearchText) AS q
    CROSS APPLY people.fn_NormalizeArabicText(CONCAT_WS(N' ', p.FirstNameAr, p.FatherNameAr, p.GrandfatherNameAr, p.FamilyNameAr)) AS n
    WHERE   CONCAT_WS(N' ', p.FirstNameEn, p.FatherNameEn, p.GrandfatherNameEn, p.FamilyNameEn) LIKE N'%' + @SearchText + N'%'
       OR   n.NormalizedText LIKE N'%' + q.NormalizedText + N'%';
GO

/* ---------------------------------------------------------------------------
   academic.fn_SchoolDays — working school days for a branch in a date range
   (branch working-day mask minus school-wide and branch holidays).
   ISO weekday bit: Monday = 1, Tuesday = 2, ... Sunday = 64 (1900-01-01 was a Monday).
   --------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION academic.fn_SchoolDays (@BranchId INT, @FromDate DATE, @ToDate DATE)
RETURNS TABLE
AS
RETURN
    WITH Numbers AS
    (
        SELECT TOP (CASE WHEN @ToDate >= @FromDate THEN DATEDIFF(DAY, @FromDate, @ToDate) + 1 ELSE 0 END)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
        FROM   sys.all_objects AS a CROSS JOIN sys.all_objects AS b
    )
    SELECT  d.SchoolDate,
            DATEDIFF(DAY, CONVERT(DATE, '19000101'), d.SchoolDate) % 7 + 1 AS IsoDayOfWeek
    FROM    Numbers
    CROSS APPLY (SELECT DATEADD(DAY, Numbers.n, @FromDate) AS SchoolDate) AS d
    JOIN    organization.Branches AS b ON b.BranchId = @BranchId
    WHERE   (b.WorkingDaysMask & POWER(2, DATEDIFF(DAY, CONVERT(DATE, '19000101'), d.SchoolDate) % 7)) <> 0
      AND   NOT EXISTS (SELECT 1
                        FROM   academic.Holidays AS h
                        JOIN   academic.AcademicYears AS ay ON ay.AcademicYearId = h.AcademicYearId
                        WHERE  ay.SchoolId = b.SchoolId
                          AND  d.SchoolDate BETWEEN h.StartDate AND h.EndDate
                          AND  (h.BranchId IS NULL OR h.BranchId = @BranchId));
GO

/* ---------------------------------------------------------------------------
   attendance.fn_StudentAttendanceSummary — daily roll-call totals for one
   enrollment in a date range.
   --------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION attendance.fn_StudentAttendanceSummary (@EnrollmentId INT, @FromDate DATE, @ToDate DATE)
RETURNS TABLE
AS
RETURN
    SELECT  @EnrollmentId                                                         AS EnrollmentId,
            COUNT(*)                                                              AS DaysRecorded,
            SUM(CASE WHEN s.CountsAsPresent = 1 THEN 1 ELSE 0 END)                AS DaysPresent,
            SUM(CASE WHEN s.CountsAsPresent = 0 AND s.IsExcused = 0 THEN 1 ELSE 0 END) AS DaysAbsentUnexcused,
            SUM(CASE WHEN s.IsExcused = 1 THEN 1 ELSE 0 END)                      AS DaysAbsentExcused,
            SUM(CASE WHEN s.Code = N'LATE' THEN 1 ELSE 0 END)                     AS DaysLate,
            CAST(100.0 * SUM(CASE WHEN s.CountsAsPresent = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(7,4)) AS AttendanceRatePercent
    FROM    attendance.AttendanceRecords  AS r
    JOIN    attendance.AttendanceSessions AS ses ON ses.AttendanceSessionId = r.AttendanceSessionId
    JOIN    attendance.AttendanceStatuses AS s   ON s.AttendanceStatusId = r.AttendanceStatusId
    WHERE   r.EnrollmentId = @EnrollmentId
      AND   ses.PeriodId IS NULL
      AND   r.SessionDate BETWEEN @FromDate AND @ToDate;
GO

/* ---------------------------------------------------------------------------
   assessment.fn_SubjectTermScores — weighted subject percentage per
   enrollment for a term. Within each assessment type the average percentage
   is taken (absent = 0, exempt = ignored); types are then combined with
   assessment.AssessmentWeights. If no weights are configured for a subject,
   the plain average of the type averages is used.
   @EnrollmentId NULL = all enrollments with results in the term.
   --------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION assessment.fn_SubjectTermScores (@EnrollmentId INT, @TermId INT)
RETURNS TABLE
AS
RETURN
    WITH Results AS
    (
        SELECT ar.EnrollmentId, ta.CurriculumSubjectId, a.AssessmentTypeId,
               CASE WHEN ar.IsAbsent = 1 THEN 0.0 ELSE 100.0 * ar.Score / a.MaxScore END AS Pct
        FROM   assessment.AssessmentResults AS ar
        JOIN   assessment.Assessments       AS a  ON a.AssessmentId = ar.AssessmentId
        JOIN   academic.TeachingAssignments AS ta ON ta.TeachingAssignmentId = a.TeachingAssignmentId
        WHERE  a.TermId = @TermId
          AND  ar.IsExempt = 0
          AND  (@EnrollmentId IS NULL OR ar.EnrollmentId = @EnrollmentId)
    ),
    TypeAverages AS
    (
        SELECT EnrollmentId, CurriculumSubjectId, AssessmentTypeId, AVG(Pct) AS AvgPct
        FROM   Results
        GROUP BY EnrollmentId, CurriculumSubjectId, AssessmentTypeId
    )
    SELECT  t.EnrollmentId,
            t.CurriculumSubjectId,
            CAST(CASE WHEN SUM(ISNULL(w.WeightPercent, 0)) = 0
                      THEN AVG(t.AvgPct)
                      ELSE SUM(t.AvgPct * ISNULL(w.WeightPercent, 0)) / SUM(ISNULL(w.WeightPercent, 0)) END AS DECIMAL(9,3)) AS SubjectPercent
    FROM    TypeAverages AS t
    LEFT JOIN assessment.AssessmentWeights AS w
           ON w.CurriculumSubjectId = t.CurriculumSubjectId AND w.TermId = @TermId AND w.AssessmentTypeId = t.AssessmentTypeId
    GROUP BY t.EnrollmentId, t.CurriculumSubjectId;
GO

/* ---------------------------------------------------------------------------
   assessment.fn_LetterGrade — band for a percentage on a grading scale
   (highest band whose MinPercent <= the percentage; no gaps by construction).
   --------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION assessment.fn_LetterGrade (@GradingScaleId INT, @Percent DECIMAL(9,3))
RETURNS TABLE
AS
RETURN
    SELECT TOP (1) b.LetterGrade, b.DescriptorEn, b.DescriptorAr, b.GradePoint,
           CAST(CASE WHEN @Percent >= gs.PassPercent THEN 1 ELSE 0 END AS BIT) AS IsPassed
    FROM   assessment.GradingScaleBands AS b
    JOIN   assessment.GradingScales     AS gs ON gs.GradingScaleId = b.GradingScaleId
    WHERE  b.GradingScaleId = @GradingScaleId AND b.MinPercent <= @Percent
    ORDER BY b.MinPercent DESC;
GO

/* ---------------------------------------------------------------------------
   finance.fn_EnrollmentFeeSchedule — gross fee schedule for an enrollment
   (before discounts and payer split): one row per installment and fee type.
   --------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION finance.fn_EnrollmentFeeSchedule (@EnrollmentId INT)
RETURNS TABLE
AS
RETURN
    SELECT  fi.FeeInstallmentId,
            fi.InstallmentNumber,
            fi.DueDate,
            ft.Code AS FeeTypeCode,
            ft.NameEn AS FeeTypeNameEn,
            ft.NameAr AS FeeTypeNameAr,
            CAST(CASE WHEN fsi.IsInstallable = 1 THEN fsi.Amount * fi.InstallmentPercent / 100
                      WHEN fi.InstallmentNumber = firstInst.FirstNo THEN fsi.Amount
                      ELSE 0 END AS DECIMAL(19,4)) AS GrossAmount,
            c.CurrencyCode
    FROM    enrollment.Enrollments   AS e
    JOIN    finance.FeeStructures    AS fs  ON fs.AcademicYearId = e.AcademicYearId AND fs.BranchId = e.BranchId
                                           AND fs.GradeLevelId = e.GradeLevelId AND fs.ProgramId = e.ProgramId AND fs.IsActive = 1
    JOIN    finance.FeeInstallments  AS fi  ON fi.FeeStructureId = fs.FeeStructureId
    JOIN    finance.FeeStructureItems AS fsi ON fsi.FeeStructureId = fs.FeeStructureId
    JOIN    finance.FeeTypes         AS ft  ON ft.FeeTypeId = fsi.FeeTypeId
    JOIN    finance.Currencies       AS c   ON c.CurrencyId = fs.CurrencyId
    CROSS APPLY (SELECT MIN(x.InstallmentNumber) AS FirstNo FROM finance.FeeInstallments AS x WHERE x.FeeStructureId = fs.FeeStructureId) AS firstInst
    WHERE   e.EnrollmentId = @EnrollmentId;
GO

/* ---------------------------------------------------------------------------
   finance.fn_PayerBalance — receivable position of one payer.
   --------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION finance.fn_PayerBalance (@PayerId INT)
RETURNS TABLE
AS
RETURN
    SELECT  @PayerId AS PayerId,
            ISNULL(inv.TotalInvoiced, 0)   AS TotalInvoiced,
            ISNULL(inv.TotalPaid, 0)       AS TotalAllocatedPayments,
            ISNULL(inv.TotalCredited, 0)   AS TotalCredited,
            ISNULL(inv.TotalInvoiced, 0) - ISNULL(inv.TotalPaid, 0) - ISNULL(inv.TotalCredited, 0) AS OutstandingBalance,
            ISNULL(pay.Unallocated, 0)     AS UnallocatedPayments
    FROM    (SELECT 1 AS One) AS anchor
    OUTER APPLY (SELECT SUM(i.TotalAmount) AS TotalInvoiced, SUM(i.PaidAmount) AS TotalPaid, SUM(i.CreditedAmount) AS TotalCredited
                 FROM   finance.Invoices AS i
                 WHERE  i.PayerId = @PayerId AND i.InvoiceStatus <> N'Cancelled') AS inv
    OUTER APPLY (SELECT SUM(p.Amount - ISNULL(a.Allocated, 0)) AS Unallocated
                 FROM   finance.Payments AS p
                 OUTER APPLY (SELECT SUM(pa.AllocatedAmount) AS Allocated FROM finance.PaymentAllocations AS pa WHERE pa.PaymentId = p.PaymentId) AS a
                 WHERE  p.PayerId = @PayerId AND p.PaymentStatus = N'Received') AS pay;
GO
