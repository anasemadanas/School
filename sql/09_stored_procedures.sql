/* =============================================================================
   09_stored_procedures.sql
   Purpose     : Table types (TVPs) and transactional business procedures.
   Dependencies: 08_views.sql. Two procedures read inline TVFs from
                 10_functions.sql; SQL Server resolves them at run time
                 (deferred name resolution), so they work once 10 has run.
   Run order   : 9 of 12
   Idempotent  : Yes (CREATE TYPE guarded by TYPE_ID; CREATE OR ALTER PROCEDURE).
   Conventions : SET NOCOUNT ON; SET XACT_ABORT ON; TRY/CATCH with THROW;
                 explicit transactions for multi-step work. Every business
                 procedure writes audit.AuditEvents.
                 Caller identity: EXEC sys.sp_set_session_context
                 @key = N'UserAccountId', @value = <id>.
   Error codes : 50xxx common, 51xxx enrollment, 52xxx timetable,
                 53xxx attendance, 54xxx assessment, 55xxx finance.
   ============================================================================= */
USE [$(DatabaseName)];
GO

/* =============================================================================
   Table types (table-valued parameters). No constraints on the types so that
   no system-named constraints are created; procedures validate duplicates.
   ============================================================================= */
IF TYPE_ID(N'attendance.AttendanceEntryList') IS NULL
    CREATE TYPE attendance.AttendanceEntryList AS TABLE
    (
        EnrollmentId    INT             NOT NULL,
        StatusCode      NVARCHAR(20)    NOT NULL,
        MinutesLate     SMALLINT        NULL,
        Remarks         NVARCHAR(500)   NULL
    );
GO
IF TYPE_ID(N'assessment.ResultEntryList') IS NULL
    CREATE TYPE assessment.ResultEntryList AS TABLE
    (
        EnrollmentId    INT             NOT NULL,
        Score           DECIMAL(9,3)    NULL,
        IsAbsent        BIT             NOT NULL,
        IsExempt        BIT             NOT NULL,
        Comment         NVARCHAR(500)   NULL
    );
GO
IF TYPE_ID(N'finance.AllocationList') IS NULL
    CREATE TYPE finance.AllocationList AS TABLE
    (
        InvoiceId       BIGINT          NOT NULL,
        Amount          DECIMAL(19,4)   NOT NULL
    );
GO

/* =============================================================================
   audit.usp_LogEvent — append one business event (used by every procedure).
   ============================================================================= */
CREATE OR ALTER PROCEDURE audit.usp_LogEvent
    @EventType      NVARCHAR(50),
    @SchemaName     NVARCHAR(128),
    @TableName      NVARCHAR(128),
    @EntityKey      NVARCHAR(100),
    @EventAction    NVARCHAR(10),
    @OldValues      NVARCHAR(MAX) = NULL,
    @NewValues      NVARCHAR(MAX) = NULL,
    @ProcedureName  NVARCHAR(256) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO audit.AuditEvents (EventType, SchemaName, TableName, EntityKey, EventAction, OldValues, NewValues, ProcedureName)
    VALUES (@EventType, @SchemaName, @TableName, @EntityKey, @EventAction, @OldValues, @NewValues, @ProcedureName);
END;
GO

/* =============================================================================
   organization.usp_GetNextDocumentNumber — gap-tolerant business numbers
   (no SEQUENCE objects). Call inside the caller's transaction so the series
   row stays locked until commit. Series rows are created on first use.
   ============================================================================= */
CREATE OR ALTER PROCEDURE organization.usp_GetNextDocumentNumber
    @DocumentType   NVARCHAR(20),
    @BranchId       INT,
    @AcademicYearId INT,
    @DocumentNumber NVARCHAR(30) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Next INT, @Prefix NVARCHAR(20), @Pad TINYINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE s WITH (UPDLOCK, HOLDLOCK)
        SET    @Next      = s.NextNumber,
               @Prefix    = s.Prefix,
               @Pad       = s.PadLength,
               NextNumber = s.NextNumber + 1,
               UpdatedAt  = SYSUTCDATETIME(),
               UpdatedBy  = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        FROM   organization.DocumentNumberSeries AS s
        WHERE  s.DocumentType = @DocumentType
          AND  s.BranchId = @BranchId
          AND  s.AcademicYearId = @AcademicYearId;

        IF @@ROWCOUNT = 0
        BEGIN
            SELECT @Prefix = CONCAT(CASE @DocumentType WHEN N'Application' THEN N'APP'
                                                       WHEN N'Invoice'     THEN N'INV'
                                                       WHEN N'Receipt'     THEN N'RCT'
                                                       WHEN N'CreditNote'  THEN N'CRN' END,
                                    N'-', b.BranchCode, N'-', LEFT(ay.YearCode, 4), N'-')
            FROM   organization.Branches AS b
            CROSS JOIN academic.AcademicYears AS ay
            WHERE  b.BranchId = @BranchId AND ay.AcademicYearId = @AcademicYearId;

            IF @Prefix IS NULL
                THROW 50001, N'Unknown document type, branch or academic year for document numbering.', 1;

            SELECT @Next = 1, @Pad = 6;

            INSERT INTO organization.DocumentNumberSeries (DocumentType, BranchId, AcademicYearId, Prefix, NextNumber, PadLength)
            VALUES (@DocumentType, @BranchId, @AcademicYearId, @Prefix, 2, @Pad);
        END;

        SET @DocumentNumber = CONCAT(@Prefix,
                                     CASE WHEN LEN(CAST(@Next AS NVARCHAR(12))) >= @Pad
                                          THEN CAST(@Next AS NVARCHAR(12))
                                          ELSE RIGHT(REPLICATE(N'0', @Pad) + CAST(@Next AS NVARCHAR(12)), @Pad) END);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   people.usp_CreatePerson — supertype row plus optional primary contacts.
   ============================================================================= */
CREATE OR ALTER PROCEDURE people.usp_CreatePerson
    @FirstNameEn        NVARCHAR(100),
    @FamilyNameEn       NVARCHAR(100),
    @FirstNameAr        NVARCHAR(100),
    @FamilyNameAr       NVARCHAR(100),
    @Gender             NVARCHAR(1),
    @FatherNameEn       NVARCHAR(100) = NULL,
    @GrandfatherNameEn  NVARCHAR(100) = NULL,
    @FatherNameAr       NVARCHAR(100) = NULL,
    @GrandfatherNameAr  NVARCHAR(100) = NULL,
    @DateOfBirth        DATE          = NULL,
    @NationalityIso2    NVARCHAR(2)   = NULL,
    @PrimaryLanguage    NVARCHAR(2)   = NULL,
    @MobilePhone        NVARCHAR(254) = NULL,
    @Email              NVARCHAR(254) = NULL,
    @PersonId           INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CountryId INT = NULL, @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));

    BEGIN TRY
        IF @NationalityIso2 IS NOT NULL
        BEGIN
            SELECT @CountryId = CountryId FROM organization.Countries WHERE IsoAlpha2 = @NationalityIso2;
            IF @CountryId IS NULL THROW 50010, N'Unknown nationality country code.', 1;
        END;

        BEGIN TRANSACTION;

        INSERT INTO people.Persons (FirstNameEn, FatherNameEn, GrandfatherNameEn, FamilyNameEn,
                                    FirstNameAr, FatherNameAr, GrandfatherNameAr, FamilyNameAr,
                                    Gender, DateOfBirth, NationalityCountryId, PrimaryLanguage)
        VALUES (@FirstNameEn, @FatherNameEn, @GrandfatherNameEn, @FamilyNameEn,
                @FirstNameAr, @FatherNameAr, @GrandfatherNameAr, @FamilyNameAr,
                @Gender, @DateOfBirth, @CountryId, @PrimaryLanguage);

        SET @PersonId = CAST(SCOPE_IDENTITY() AS INT);

        IF @MobilePhone IS NOT NULL
            INSERT INTO people.PersonContacts (PersonId, ContactType, ContactValue, IsPrimary) VALUES (@PersonId, N'Mobile', @MobilePhone, 1);
        IF @Email IS NOT NULL
            INSERT INTO people.PersonContacts (PersonId, ContactType, ContactValue, IsPrimary) VALUES (@PersonId, N'Email', @Email, 1);

        DECLARE @New NVARCHAR(MAX) = (SELECT PersonId, FirstNameEn, FamilyNameEn, FirstNameAr, FamilyNameAr, Gender, DateOfBirth
                                      FROM people.Persons WHERE PersonId = @PersonId FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        DECLARE @Key NVARCHAR(100) = CAST(@PersonId AS NVARCHAR(100));
        EXEC audit.usp_LogEvent @EventType = N'PersonCreated', @SchemaName = N'people', @TableName = N'Persons',
             @EntityKey = @Key, @EventAction = N'Insert', @NewValues = @New, @ProcedureName = @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   enrollment.usp_SubmitApplication — admission application (status Submitted).
   ============================================================================= */
CREATE OR ALTER PROCEDURE enrollment.usp_SubmitApplication
    @ApplicantPersonId  INT,
    @AcademicYearId     INT,
    @BranchId           INT,
    @GradeLevelId       INT,
    @ProgramId          INT  = NULL,
    @ApplicationDate    DATE = NULL,
    @ApplicationId      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID)),
            @Number NVARCHAR(30);
    SET @ApplicationDate = ISNULL(@ApplicationDate, CONVERT(DATE, SYSUTCDATETIME()));

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM people.Persons WHERE PersonId = @ApplicantPersonId)
            THROW 51001, N'Applicant person does not exist.', 1;
        IF NOT EXISTS (SELECT 1 FROM academic.AcademicYears WHERE AcademicYearId = @AcademicYearId AND YearStatus <> N'Closed')
            THROW 51002, N'Academic year does not exist or is closed.', 1;
        IF EXISTS (SELECT 1 FROM enrollment.Applications
                   WHERE ApplicantPersonId = @ApplicantPersonId AND AcademicYearId = @AcademicYearId
                     AND ApplicationStatus IN (N'Submitted', N'UnderReview', N'Accepted', N'Waitlisted'))
            THROW 51003, N'An open application already exists for this applicant and academic year.', 1;

        BEGIN TRANSACTION;

        EXEC organization.usp_GetNextDocumentNumber @DocumentType = N'Application', @BranchId = @BranchId,
             @AcademicYearId = @AcademicYearId, @DocumentNumber = @Number OUTPUT;

        INSERT INTO enrollment.Applications (ApplicationNumber, ApplicantPersonId, AcademicYearId, BranchId, GradeLevelId, ProgramId, ApplicationDate, ApplicationStatus)
        VALUES (@Number, @ApplicantPersonId, @AcademicYearId, @BranchId, @GradeLevelId, @ProgramId, @ApplicationDate, N'Submitted');

        SET @ApplicationId = CAST(SCOPE_IDENTITY() AS INT);

        INSERT INTO enrollment.ApplicationStatusHistory (ApplicationId, FromStatus, ToStatus, Notes)
        VALUES (@ApplicationId, NULL, N'Submitted', NULL);

        DECLARE @Key NVARCHAR(100) = CAST(@ApplicationId AS NVARCHAR(100));
        DECLARE @New NVARCHAR(MAX) = (SELECT @Number AS ApplicationNumber, @ApplicantPersonId AS ApplicantPersonId,
                                             @AcademicYearId AS AcademicYearId, @GradeLevelId AS GradeLevelId
                                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'ApplicationSubmitted', N'enrollment', N'Applications', @Key, N'Insert', NULL, @New, @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   enrollment.usp_DecideApplication — status workflow with history.
   Allowed: Submitted -> UnderReview|Accepted|Rejected|Waitlisted|Withdrawn
            UnderReview -> Accepted|Rejected|Waitlisted|Withdrawn
            Waitlisted -> Accepted|Rejected|Withdrawn
            Accepted -> Withdrawn
   ============================================================================= */
CREATE OR ALTER PROCEDURE enrollment.usp_DecideApplication
    @ApplicationId  INT,
    @NewStatus      NVARCHAR(20),
    @DecisionDate   DATE          = NULL,
    @Notes          NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID)),
            @Old NVARCHAR(20);
    SET @DecisionDate = ISNULL(@DecisionDate, CONVERT(DATE, SYSUTCDATETIME()));

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @Old = ApplicationStatus
        FROM   enrollment.Applications WITH (UPDLOCK, HOLDLOCK)
        WHERE  ApplicationId = @ApplicationId;

        IF @Old IS NULL THROW 51004, N'Application does not exist.', 1;

        IF NOT (   (@Old = N'Submitted'   AND @NewStatus IN (N'UnderReview', N'Accepted', N'Rejected', N'Waitlisted', N'Withdrawn'))
                OR (@Old = N'UnderReview' AND @NewStatus IN (N'Accepted', N'Rejected', N'Waitlisted', N'Withdrawn'))
                OR (@Old = N'Waitlisted'  AND @NewStatus IN (N'Accepted', N'Rejected', N'Withdrawn'))
                OR (@Old = N'Accepted'    AND @NewStatus = N'Withdrawn'))
        BEGIN
            DECLARE @Msg NVARCHAR(400) = CONCAT(N'Invalid application status transition: ', @Old, N' -> ', @NewStatus, N'.');
            THROW 51005, @Msg, 1;
        END;

        UPDATE enrollment.Applications
        SET    ApplicationStatus = @NewStatus,
               DecisionDate      = CASE WHEN @NewStatus IN (N'Accepted', N'Rejected') THEN @DecisionDate ELSE DecisionDate END,
               DecisionNotes     = ISNULL(@Notes, DecisionNotes),
               UpdatedAt         = SYSUTCDATETIME(),
               UpdatedBy         = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        WHERE  ApplicationId = @ApplicationId;

        INSERT INTO enrollment.ApplicationStatusHistory (ApplicationId, FromStatus, ToStatus, Notes)
        VALUES (@ApplicationId, @Old, @NewStatus, LEFT(@Notes, 500));

        DECLARE @Key NVARCHAR(100) = CAST(@ApplicationId AS NVARCHAR(100));
        DECLARE @OldJ NVARCHAR(MAX) = (SELECT @Old AS ApplicationStatus FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        DECLARE @NewJ NVARCHAR(MAX) = (SELECT @NewStatus AS ApplicationStatus FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'ApplicationStatusChanged', N'enrollment', N'Applications', @Key, N'Update', @OldJ, @NewJ, @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   enrollment.usp_AssignSection — place or transfer an enrollment into a section.
   Closes the open assignment (history kept). Capacity is the section's own
   configurable value; @AllowOverCapacity = 1 lets an authorised user override.
   ============================================================================= */
CREATE OR ALTER PROCEDURE enrollment.usp_AssignSection
    @EnrollmentId       INT,
    @SectionId          INT,
    @StartDate          DATE,
    @Reason             NVARCHAR(200) = NULL,
    @AllowOverCapacity  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @YearId INT, @BranchId INT, @GradeId INT, @Status NVARCHAR(20),
            @SecYear INT, @SecBranch INT, @SecGrade INT, @Capacity INT, @SecActive BIT,
            @OpenId INT, @OpenSection INT, @OpenStart DATE, @Current INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @YearId = AcademicYearId, @BranchId = BranchId, @GradeId = GradeLevelId, @Status = EnrollmentStatus
        FROM   enrollment.Enrollments WITH (UPDLOCK)
        WHERE  EnrollmentId = @EnrollmentId;

        IF @YearId IS NULL THROW 51006, N'Enrollment does not exist.', 1;
        IF @Status <> N'Enrolled' THROW 51007, N'Only enrollments with status Enrolled can be assigned to a section.', 1;

        -- Lock the section row: serialises concurrent placements into the same section.
        SELECT @SecYear = AcademicYearId, @SecBranch = BranchId, @SecGrade = GradeLevelId,
               @Capacity = Capacity, @SecActive = IsActive
        FROM   academic.Sections WITH (UPDLOCK, HOLDLOCK)
        WHERE  SectionId = @SectionId;

        IF @SecYear IS NULL THROW 51008, N'Section does not exist.', 1;
        IF @SecActive = 0 THROW 51009, N'Section is inactive.', 1;
        IF @SecYear <> @YearId OR @SecBranch <> @BranchId OR @SecGrade <> @GradeId
            THROW 51010, N'Section academic year, branch and grade level must match the enrollment.', 1;

        SELECT @OpenId = SectionAssignmentId, @OpenSection = SectionId, @OpenStart = StartDate
        FROM   enrollment.SectionAssignments WITH (UPDLOCK)
        WHERE  EnrollmentId = @EnrollmentId AND EndDate IS NULL;

        IF @OpenSection = @SectionId
            THROW 51011, N'The enrollment is already assigned to this section.', 1;

        IF @Capacity IS NOT NULL AND @AllowOverCapacity = 0
        BEGIN
            SELECT @Current = COUNT(*) FROM enrollment.SectionAssignments WHERE SectionId = @SectionId AND EndDate IS NULL;
            IF @Current >= @Capacity
                THROW 51012, N'Section capacity reached. Use @AllowOverCapacity = 1 to override.', 1;
        END;

        IF @OpenId IS NOT NULL AND @OpenStart >= @StartDate
        BEGIN
            -- Same-day (or back-dated) change: treat as a correction of the open assignment.
            UPDATE enrollment.SectionAssignments
            SET    SectionId = @SectionId, StartDate = @StartDate, Reason = ISNULL(@Reason, Reason),
                   UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
            WHERE  SectionAssignmentId = @OpenId;
        END
        ELSE
        BEGIN
            IF @OpenId IS NOT NULL
                UPDATE enrollment.SectionAssignments
                SET    EndDate = DATEADD(DAY, -1, @StartDate),
                       UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
                WHERE  SectionAssignmentId = @OpenId;

            INSERT INTO enrollment.SectionAssignments (EnrollmentId, AcademicYearId, SectionId, StartDate, Reason)
            VALUES (@EnrollmentId, @YearId, @SectionId, @StartDate, @Reason);
        END;

        DECLARE @Key NVARCHAR(100) = CAST(@EnrollmentId AS NVARCHAR(100));
        DECLARE @OldJ NVARCHAR(MAX) = (SELECT @OpenSection AS SectionId FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        DECLARE @NewJ NVARCHAR(MAX) = (SELECT @SectionId AS SectionId, @StartDate AS StartDate, @AllowOverCapacity AS OverCapacityOverride FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'SectionAssigned', N'enrollment', N'SectionAssignments', @Key, N'Execute', @OldJ, @NewJ, @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   enrollment.usp_EnrollStudent — enroll a person for one academic year.
   Creates the Students subtype row on first enrollment, links an accepted
   application, and optionally places the student in a section.
   ============================================================================= */
CREATE OR ALTER PROCEDURE enrollment.usp_EnrollStudent
    @PersonId           INT,
    @AcademicYearId     INT,
    @BranchId           INT,
    @GradeLevelId       INT,
    @ProgramId          INT,
    @EnrollmentDate     DATE,
    @SectionId          INT           = NULL,
    @ApplicationId      INT           = NULL,
    @StudentNumber      NVARCHAR(20)  = NULL,
    @AllowOverCapacity  BIT           = 0,
    @EnrollmentId       INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @AppStatus NVARCHAR(20), @AppPerson INT, @AppYear INT, @YearStatus NVARCHAR(20), @YearStart DATE, @YearEnd DATE;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM people.Persons WHERE PersonId = @PersonId)
            THROW 51013, N'Person does not exist.', 1;

        SELECT @YearStatus = YearStatus, @YearStart = StartDate, @YearEnd = EndDate
        FROM   academic.AcademicYears WHERE AcademicYearId = @AcademicYearId;
        IF @YearStatus IS NULL OR @YearStatus = N'Closed'
            THROW 51014, N'Academic year does not exist or is closed.', 1;
        IF @EnrollmentDate > @YearEnd
            THROW 51015, N'Enrollment date is after the end of the academic year.', 1;

        BEGIN TRANSACTION;

        IF @ApplicationId IS NOT NULL
        BEGIN
            SELECT @AppStatus = ApplicationStatus, @AppPerson = ApplicantPersonId, @AppYear = AcademicYearId
            FROM   enrollment.Applications WITH (UPDLOCK)
            WHERE  ApplicationId = @ApplicationId;

            IF @AppStatus IS NULL OR @AppStatus <> N'Accepted' OR @AppPerson <> @PersonId OR @AppYear <> @AcademicYearId
                THROW 51016, N'Application must exist, be Accepted, and match the person and academic year.', 1;

            UPDATE enrollment.Applications
            SET    ApplicationStatus = N'Enrolled', UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
            WHERE  ApplicationId = @ApplicationId;

            INSERT INTO enrollment.ApplicationStatusHistory (ApplicationId, FromStatus, ToStatus, Notes)
            VALUES (@ApplicationId, N'Accepted', N'Enrolled', NULL);
        END;

        -- Students subtype row (overlapping specialisation: the person may also be a guardian/employee).
        IF NOT EXISTS (SELECT 1 FROM people.Students WITH (UPDLOCK, HOLDLOCK) WHERE PersonId = @PersonId)
        BEGIN
            IF @StudentNumber IS NULL
                SET @StudentNumber = CONCAT(N'S', CASE WHEN @PersonId > 99999999 THEN CAST(@PersonId AS NVARCHAR(12))
                                                       ELSE RIGHT(N'00000000' + CAST(@PersonId AS NVARCHAR(12)), 8) END);
            INSERT INTO people.Students (PersonId, StudentNumber, AdmissionDate, StudentStatus)
            VALUES (@PersonId, @StudentNumber, @EnrollmentDate, N'Active');
        END
        ELSE
            UPDATE people.Students
            SET    StudentStatus = N'Active', UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
            WHERE  PersonId = @PersonId AND StudentStatus <> N'Active';

        IF EXISTS (SELECT 1 FROM enrollment.Enrollments WHERE StudentId = @PersonId AND AcademicYearId = @AcademicYearId)
            THROW 51017, N'The student is already enrolled in this academic year.', 1;

        INSERT INTO enrollment.Enrollments (StudentId, AcademicYearId, BranchId, GradeLevelId, ProgramId, ApplicationId, EnrollmentDate, EnrollmentStatus)
        VALUES (@PersonId, @AcademicYearId, @BranchId, @GradeLevelId, @ProgramId, @ApplicationId, @EnrollmentDate, N'Enrolled');

        SET @EnrollmentId = CAST(SCOPE_IDENTITY() AS INT);

        IF @SectionId IS NOT NULL
        BEGIN
            DECLARE @SectionStart DATE = CASE WHEN @EnrollmentDate < @YearStart THEN @YearStart ELSE @EnrollmentDate END;
            EXEC enrollment.usp_AssignSection @EnrollmentId = @EnrollmentId, @SectionId = @SectionId,
                 @StartDate = @SectionStart, @Reason = N'Initial placement', @AllowOverCapacity = @AllowOverCapacity;
        END;

        DECLARE @Key NVARCHAR(100) = CAST(@EnrollmentId AS NVARCHAR(100));
        DECLARE @New NVARCHAR(MAX) = (SELECT EnrollmentId, StudentId, AcademicYearId, BranchId, GradeLevelId, ProgramId, EnrollmentDate
                                      FROM enrollment.Enrollments WHERE EnrollmentId = @EnrollmentId FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'StudentEnrolled', N'enrollment', N'Enrollments', @Key, N'Insert', NULL, @New, @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   enrollment.usp_WithdrawStudent — end an enrollment (Withdrawn | Transferred).
   ============================================================================= */
CREATE OR ALTER PROCEDURE enrollment.usp_WithdrawStudent
    @EnrollmentId   INT,
    @WithdrawalDate DATE,
    @NewStatus      NVARCHAR(20) = N'Withdrawn',
    @Reason         NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @StudentId INT, @Status NVARCHAR(20), @EnrollDate DATE;

    BEGIN TRY
        IF @NewStatus NOT IN (N'Withdrawn', N'Transferred')
            THROW 51018, N'@NewStatus must be Withdrawn or Transferred.', 1;

        BEGIN TRANSACTION;

        SELECT @StudentId = StudentId, @Status = EnrollmentStatus, @EnrollDate = EnrollmentDate
        FROM   enrollment.Enrollments WITH (UPDLOCK)
        WHERE  EnrollmentId = @EnrollmentId;

        IF @StudentId IS NULL THROW 51006, N'Enrollment does not exist.', 1;
        IF @Status <> N'Enrolled' THROW 51019, N'Only an Enrolled enrollment can be withdrawn.', 1;
        IF @WithdrawalDate < @EnrollDate THROW 51020, N'Withdrawal date is before the enrollment date.', 1;

        UPDATE enrollment.SectionAssignments
        SET    EndDate = CASE WHEN @WithdrawalDate < StartDate THEN StartDate ELSE @WithdrawalDate END,
               Reason = ISNULL(@Reason, Reason), UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        WHERE  EnrollmentId = @EnrollmentId AND EndDate IS NULL;

        UPDATE enrollment.Enrollments
        SET    EnrollmentStatus = @NewStatus, WithdrawalDate = @WithdrawalDate,
               UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        WHERE  EnrollmentId = @EnrollmentId;

        IF NOT EXISTS (SELECT 1 FROM enrollment.Enrollments WHERE StudentId = @StudentId AND EnrollmentStatus = N'Enrolled')
            UPDATE people.Students
            SET    StudentStatus = @NewStatus, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
            WHERE  PersonId = @StudentId;

        DECLARE @Key NVARCHAR(100) = CAST(@EnrollmentId AS NVARCHAR(100));
        DECLARE @NewJ NVARCHAR(MAX) = (SELECT @NewStatus AS EnrollmentStatus, @WithdrawalDate AS WithdrawalDate, @Reason AS Reason FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'StudentWithdrawn', N'enrollment', N'Enrollments', @Key, N'Update', NULL, @NewJ, @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   enrollment.usp_PromoteStudents — year rollover. For every enrollment of the
   source year with PromotionOutcome Promoted/Retained, create the next year's
   enrollment (next grade / same grade). Graduated students are marked as such.
   Source enrollments become Completed. Never overwrites history.
   ============================================================================= */
CREATE OR ALTER PROCEDURE enrollment.usp_PromoteStudents
    @FromAcademicYearId INT,
    @ToAcademicYearId   INT,
    @BranchId           INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @ToStart DATE, @ToStatus NVARCHAR(20), @Created INT = 0, @Graduated INT = 0;

    BEGIN TRY
        SELECT @ToStart = StartDate, @ToStatus = YearStatus FROM academic.AcademicYears WHERE AcademicYearId = @ToAcademicYearId;
        IF @ToStart IS NULL OR @ToStatus = N'Closed'
            THROW 51021, N'Target academic year does not exist or is closed.', 1;
        IF NOT EXISTS (SELECT 1 FROM academic.AcademicYears WHERE AcademicYearId = @FromAcademicYearId)
            THROW 51022, N'Source academic year does not exist.', 1;

        BEGIN TRANSACTION;

        INSERT INTO enrollment.Enrollments (StudentId, AcademicYearId, BranchId, GradeLevelId, ProgramId, EnrollmentDate, EnrollmentStatus)
        SELECT e.StudentId, @ToAcademicYearId, e.BranchId,
               CASE e.PromotionOutcome WHEN N'Promoted' THEN gl.NextGradeLevelId ELSE e.GradeLevelId END,
               e.ProgramId, @ToStart, N'Enrolled'
        FROM   enrollment.Enrollments AS e
        JOIN   academic.GradeLevels   AS gl ON gl.GradeLevelId = e.GradeLevelId
        WHERE  e.AcademicYearId = @FromAcademicYearId
          AND  (@BranchId IS NULL OR e.BranchId = @BranchId)
          AND  e.EnrollmentStatus IN (N'Enrolled', N'Completed')
          AND  e.PromotionOutcome IN (N'Promoted', N'Retained')
          AND  (e.PromotionOutcome = N'Retained' OR gl.NextGradeLevelId IS NOT NULL)
          AND  NOT EXISTS (SELECT 1 FROM enrollment.Enrollments AS x WHERE x.StudentId = e.StudentId AND x.AcademicYearId = @ToAcademicYearId);
        SET @Created = @@ROWCOUNT;

        UPDATE s
        SET    StudentStatus = N'Graduated', UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        FROM   people.Students AS s
        JOIN   enrollment.Enrollments AS e ON e.StudentId = s.PersonId
        WHERE  e.AcademicYearId = @FromAcademicYearId
          AND  (@BranchId IS NULL OR e.BranchId = @BranchId)
          AND  e.PromotionOutcome = N'Graduated'
          AND  s.StudentStatus <> N'Graduated';
        SET @Graduated = @@ROWCOUNT;

        UPDATE enrollment.SectionAssignments
        SET    EndDate = ay.EndDate, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        FROM   enrollment.SectionAssignments AS sa
        JOIN   enrollment.Enrollments AS e ON e.EnrollmentId = sa.EnrollmentId
        JOIN   academic.AcademicYears AS ay ON ay.AcademicYearId = e.AcademicYearId
        WHERE  e.AcademicYearId = @FromAcademicYearId
          AND  (@BranchId IS NULL OR e.BranchId = @BranchId)
          AND  e.EnrollmentStatus = N'Enrolled'
          AND  sa.EndDate IS NULL
          AND  ay.EndDate >= sa.StartDate;

        UPDATE enrollment.Enrollments
        SET    EnrollmentStatus = N'Completed', UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        WHERE  AcademicYearId = @FromAcademicYearId
          AND  (@BranchId IS NULL OR BranchId = @BranchId)
          AND  EnrollmentStatus = N'Enrolled';

        DECLARE @Key NVARCHAR(100) = CONCAT(@FromAcademicYearId, N'->', @ToAcademicYearId);
        DECLARE @NewJ NVARCHAR(MAX) = (SELECT @Created AS EnrollmentsCreated, @Graduated AS StudentsGraduated, @BranchId AS BranchId FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'StudentsPromoted', N'enrollment', N'Enrollments', @Key, N'Execute', NULL, @NewJ, @Proc;

        COMMIT TRANSACTION;

        SELECT @Created AS EnrollmentsCreated, @Graduated AS StudentsGraduated;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   timetable.usp_PublishTimetable — clash-checked publication. Rejects the
   publish if a teacher or room would be in two places at overlapping times
   against other published timetables of the same term. The previously
   published version for the same section/term is archived (not deleted).
   ============================================================================= */
CREATE OR ALTER PROCEDURE timetable.usp_PublishTimetable
    @TimetableId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @SectionId INT, @TermId INT, @Status NVARCHAR(20), @From DATE, @TeacherClashes INT, @RoomClashes INT, @PrevId INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @SectionId = SectionId, @TermId = TermId, @Status = TimetableStatus, @From = EffectiveFrom
        FROM   timetable.Timetables WITH (UPDLOCK, HOLDLOCK)
        WHERE  TimetableId = @TimetableId;

        IF @SectionId IS NULL THROW 52001, N'Timetable does not exist.', 1;
        IF @Status <> N'Draft' THROW 52002, N'Only Draft timetables can be published.', 1;
        IF NOT EXISTS (SELECT 1 FROM timetable.TimetableEntries WHERE TimetableId = @TimetableId)
            THROW 52003, N'Timetable has no entries.', 1;

        ;WITH Mine AS
        (
            SELECT te.DayOfWeek, p.StartTime, p.EndTime, ta.TeacherId, te.RoomId
            FROM   timetable.TimetableEntries AS te
            JOIN   timetable.Periods AS p ON p.PeriodId = te.PeriodId
            JOIN   academic.TeachingAssignments AS ta ON ta.TeachingAssignmentId = te.TeachingAssignmentId
            WHERE  te.TimetableId = @TimetableId
        ),
        Others AS
        (
            SELECT te.DayOfWeek, p.StartTime, p.EndTime, ta.TeacherId, te.RoomId
            FROM   timetable.Timetables AS tt
            JOIN   timetable.TimetableEntries AS te ON te.TimetableId = tt.TimetableId
            JOIN   timetable.Periods AS p ON p.PeriodId = te.PeriodId
            JOIN   academic.TeachingAssignments AS ta ON ta.TeachingAssignmentId = te.TeachingAssignmentId
            WHERE  tt.TermId = @TermId
              AND  tt.TimetableStatus = N'Published'
              AND  tt.SectionId <> @SectionId
        )
        SELECT @TeacherClashes = SUM(CASE WHEN m.TeacherId = o.TeacherId THEN 1 ELSE 0 END),
               @RoomClashes    = SUM(CASE WHEN m.RoomId = o.RoomId THEN 1 ELSE 0 END)
        FROM   Mine AS m
        JOIN   Others AS o
          ON   o.DayOfWeek = m.DayOfWeek
         AND   o.StartTime < m.EndTime AND m.StartTime < o.EndTime
         AND  (o.TeacherId = m.TeacherId OR o.RoomId = m.RoomId);

        IF ISNULL(@TeacherClashes, 0) > 0 OR ISNULL(@RoomClashes, 0) > 0
        BEGIN
            DECLARE @Msg NVARCHAR(400) = CONCAT(N'Timetable clashes with published timetables: ', ISNULL(@TeacherClashes, 0),
                                                N' teacher clash(es), ', ISNULL(@RoomClashes, 0), N' room clash(es).');
            THROW 52004, @Msg, 1;
        END;

        SELECT @PrevId = TimetableId
        FROM   timetable.Timetables WITH (UPDLOCK)
        WHERE  SectionId = @SectionId AND TermId = @TermId AND TimetableStatus = N'Published';

        IF @PrevId IS NOT NULL
            UPDATE timetable.Timetables
            SET    TimetableStatus = N'Archived',
                   EffectiveTo = CASE WHEN DATEADD(DAY, -1, @From) < EffectiveFrom THEN EffectiveFrom ELSE DATEADD(DAY, -1, @From) END,
                   UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
            WHERE  TimetableId = @PrevId;

        UPDATE timetable.Timetables
        SET    TimetableStatus = N'Published', PublishedAt = SYSUTCDATETIME(),
               UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        WHERE  TimetableId = @TimetableId;

        DECLARE @Key NVARCHAR(100) = CAST(@TimetableId AS NVARCHAR(100));
        DECLARE @NewJ NVARCHAR(MAX) = (SELECT N'Published' AS TimetableStatus, @PrevId AS ArchivedTimetableId FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'TimetablePublished', N'timetable', N'Timetables', @Key, N'Update', NULL, @NewJ, @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   attendance.usp_RecordSectionAttendance — record (or correct) a roll-call for
   a whole section in one call using a table-valued parameter.
   ============================================================================= */
CREATE OR ALTER PROCEDURE attendance.usp_RecordSectionAttendance
    @SectionId              INT,
    @SessionDate            DATE,
    @Entries                attendance.AttendanceEntryList READONLY,
    @PeriodId               INT    = NULL,
    @TakenByEmployeeId      INT    = NULL,
    @AttendanceSessionId    BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @YearId INT, @BranchId INT, @YearStart DATE, @YearEnd DATE, @Mask TINYINT, @SchoolId INT,
            @Inserted INT = 0, @Updated INT = 0;
    DECLARE @Changes TABLE (MergeAction NVARCHAR(10) NOT NULL);

    -- OUTPUT parameters arrive with the caller's value; never reuse it as a lookup result.
    SET @AttendanceSessionId = NULL;

    BEGIN TRY
        SELECT @YearId = sec.AcademicYearId, @BranchId = sec.BranchId, @YearStart = ay.StartDate, @YearEnd = ay.EndDate,
               @Mask = b.WorkingDaysMask, @SchoolId = b.SchoolId
        FROM   academic.Sections AS sec
        JOIN   academic.AcademicYears AS ay ON ay.AcademicYearId = sec.AcademicYearId
        JOIN   organization.Branches AS b ON b.BranchId = sec.BranchId
        WHERE  sec.SectionId = @SectionId;

        IF @YearId IS NULL THROW 53001, N'Section does not exist.', 1;
        IF @SessionDate NOT BETWEEN @YearStart AND @YearEnd
            THROW 53002, N'Session date is outside the section''s academic year.', 1;
        IF (@Mask & POWER(2, DATEDIFF(DAY, CONVERT(DATE, '19000101'), @SessionDate) % 7)) = 0
            THROW 53003, N'Session date is not a working day for this branch.', 1;
        IF EXISTS (SELECT 1 FROM academic.Holidays
                   WHERE AcademicYearId = @YearId AND @SessionDate BETWEEN StartDate AND EndDate
                     AND (BranchId IS NULL OR BranchId = @BranchId))
            THROW 53004, N'Session date is a holiday.', 1;
        IF @PeriodId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM timetable.Periods WHERE PeriodId = @PeriodId AND IsBreak = 0)
            THROW 53005, N'Period does not exist or is a break.', 1;
        IF NOT EXISTS (SELECT 1 FROM @Entries)
            THROW 53006, N'No attendance entries supplied.', 1;
        IF EXISTS (SELECT EnrollmentId FROM @Entries GROUP BY EnrollmentId HAVING COUNT(*) > 1)
            THROW 53007, N'Duplicate EnrollmentId in attendance entries.', 1;
        IF EXISTS (SELECT 1 FROM @Entries AS e
                   LEFT JOIN attendance.AttendanceStatuses AS s ON s.Code = e.StatusCode AND s.IsActive = 1
                   WHERE s.AttendanceStatusId IS NULL)
            THROW 53008, N'Unknown or inactive attendance status code.', 1;
        IF EXISTS (SELECT 1 FROM @Entries AS e
                   WHERE NOT EXISTS (SELECT 1 FROM enrollment.SectionAssignments AS sa
                                     WHERE sa.EnrollmentId = e.EnrollmentId AND sa.SectionId = @SectionId
                                       AND sa.StartDate <= @SessionDate AND (sa.EndDate IS NULL OR sa.EndDate >= @SessionDate)))
            THROW 53009, N'One or more students were not in this section on the session date.', 1;

        BEGIN TRANSACTION;

        SELECT @AttendanceSessionId = AttendanceSessionId
        FROM   attendance.AttendanceSessions WITH (UPDLOCK, HOLDLOCK)
        WHERE  SectionId = @SectionId AND SessionDate = @SessionDate
          AND  ((@PeriodId IS NULL AND PeriodId IS NULL) OR PeriodId = @PeriodId);

        IF @AttendanceSessionId IS NULL
        BEGIN
            INSERT INTO attendance.AttendanceSessions (SectionId, SessionDate, PeriodId, TakenByEmployeeId)
            VALUES (@SectionId, @SessionDate, @PeriodId, @TakenByEmployeeId);
            SET @AttendanceSessionId = CAST(SCOPE_IDENTITY() AS BIGINT);
        END
        ELSE
            UPDATE attendance.AttendanceSessions
            SET    TakenByEmployeeId = ISNULL(@TakenByEmployeeId, TakenByEmployeeId), TakenAt = SYSUTCDATETIME(),
                   UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
            WHERE  AttendanceSessionId = @AttendanceSessionId;

        MERGE attendance.AttendanceRecords AS t
        USING (
            SELECT e.EnrollmentId, s.AttendanceStatusId, e.MinutesLate, e.Remarks
            FROM   @Entries AS e
            JOIN   attendance.AttendanceStatuses AS s ON s.Code = e.StatusCode
        ) AS src
        ON t.AttendanceSessionId = @AttendanceSessionId AND t.EnrollmentId = src.EnrollmentId
        WHEN MATCHED AND EXISTS (SELECT src.AttendanceStatusId, src.MinutesLate, src.Remarks
                                 EXCEPT SELECT t.AttendanceStatusId, t.MinutesLate, t.Remarks)
            THEN UPDATE SET AttendanceStatusId = src.AttendanceStatusId, MinutesLate = src.MinutesLate, Remarks = src.Remarks,
                            UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        WHEN NOT MATCHED BY TARGET
            THEN INSERT (AttendanceSessionId, SessionDate, SectionId, EnrollmentId, AttendanceStatusId, MinutesLate, Remarks)
                 VALUES (@AttendanceSessionId, @SessionDate, @SectionId, src.EnrollmentId, src.AttendanceStatusId, src.MinutesLate, src.Remarks)
        OUTPUT $action INTO @Changes (MergeAction);

        SELECT @Inserted = SUM(CASE WHEN MergeAction = N'INSERT' THEN 1 ELSE 0 END),
               @Updated  = SUM(CASE WHEN MergeAction = N'UPDATE' THEN 1 ELSE 0 END)
        FROM   @Changes;

        DECLARE @Key NVARCHAR(100) = CAST(@AttendanceSessionId AS NVARCHAR(100));
        DECLARE @NewJ NVARCHAR(MAX) = (SELECT @SectionId AS SectionId, @SessionDate AS SessionDate, @PeriodId AS PeriodId,
                                              ISNULL(@Inserted, 0) AS RecordsInserted, ISNULL(@Updated, 0) AS RecordsUpdated
                                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'AttendanceRecorded', N'attendance', N'AttendanceRecords', @Key, N'Execute', NULL, @NewJ, @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   assessment.usp_RecordResults — record or correct results for one assessment
   (TVP). Rows are updated only when a value changed, so the temporal history
   contains only real grade changes.
   ============================================================================= */
CREATE OR ALTER PROCEDURE assessment.usp_RecordResults
    @AssessmentId   INT,
    @Results        assessment.ResultEntryList READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @MaxScore DECIMAL(9,3), @SectionId INT, @AssessmentDate DATE, @Inserted INT = 0, @Updated INT = 0;
    DECLARE @Changes TABLE (MergeAction NVARCHAR(10) NOT NULL);

    BEGIN TRY
        SELECT @MaxScore = a.MaxScore, @SectionId = ta.SectionId, @AssessmentDate = a.AssessmentDate
        FROM   assessment.Assessments AS a
        JOIN   academic.TeachingAssignments AS ta ON ta.TeachingAssignmentId = a.TeachingAssignmentId
        WHERE  a.AssessmentId = @AssessmentId;

        IF @MaxScore IS NULL THROW 54001, N'Assessment does not exist.', 1;
        IF NOT EXISTS (SELECT 1 FROM @Results) THROW 54002, N'No results supplied.', 1;
        IF EXISTS (SELECT EnrollmentId FROM @Results GROUP BY EnrollmentId HAVING COUNT(*) > 1)
            THROW 54003, N'Duplicate EnrollmentId in results.', 1;
        IF EXISTS (SELECT 1 FROM @Results WHERE Score < 0 OR Score > @MaxScore)
            THROW 54004, N'Score must be between 0 and the assessment MaxScore.', 1;
        IF EXISTS (SELECT 1 FROM @Results WHERE Score IS NULL AND IsAbsent = 0 AND IsExempt = 0)
            THROW 54005, N'A result needs a score unless the student is absent or exempt.', 1;
        IF EXISTS (SELECT 1 FROM @Results AS r
                   WHERE NOT EXISTS (SELECT 1 FROM enrollment.SectionAssignments AS sa
                                     WHERE sa.EnrollmentId = r.EnrollmentId AND sa.SectionId = @SectionId
                                       AND sa.StartDate <= @AssessmentDate AND (sa.EndDate IS NULL OR sa.EndDate >= @AssessmentDate)))
            THROW 54006, N'One or more students were not in the assessed section on the assessment date.', 1;

        BEGIN TRANSACTION;

        MERGE assessment.AssessmentResults WITH (HOLDLOCK) AS t
        USING @Results AS src
        ON t.AssessmentId = @AssessmentId AND t.EnrollmentId = src.EnrollmentId
        WHEN MATCHED AND EXISTS (SELECT src.Score, src.IsAbsent, src.IsExempt, src.Comment
                                 EXCEPT SELECT t.Score, t.IsAbsent, t.IsExempt, t.Comment)
            THEN UPDATE SET Score = src.Score, IsAbsent = src.IsAbsent, IsExempt = src.IsExempt, Comment = src.Comment,
                            UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        WHEN NOT MATCHED BY TARGET
            THEN INSERT (AssessmentId, EnrollmentId, Score, IsAbsent, IsExempt, Comment)
                 VALUES (@AssessmentId, src.EnrollmentId, src.Score, src.IsAbsent, src.IsExempt, src.Comment)
        OUTPUT $action INTO @Changes (MergeAction);

        SELECT @Inserted = SUM(CASE WHEN MergeAction = N'INSERT' THEN 1 ELSE 0 END),
               @Updated  = SUM(CASE WHEN MergeAction = N'UPDATE' THEN 1 ELSE 0 END)
        FROM   @Changes;

        DECLARE @Key NVARCHAR(100) = CAST(@AssessmentId AS NVARCHAR(100));
        DECLARE @NewJ NVARCHAR(MAX) = (SELECT ISNULL(@Inserted, 0) AS ResultsInserted, ISNULL(@Updated, 0) AS ResultsUpdated FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'ResultsRecorded', N'assessment', N'AssessmentResults', @Key, N'Execute', NULL, @NewJ, @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   assessment.usp_GenerateReportCards — (re)build DRAFT report cards for every
   student who was in the section during the term. Published cards are never
   touched; regenerating after publication creates a new Draft version.
   Uses inline TVF assessment.fn_SubjectTermScores (10_functions.sql).
   ============================================================================= */
CREATE OR ALTER PROCEDURE assessment.usp_GenerateReportCards
    @SectionId  INT,
    @TermId     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @TermStart DATE, @TermEnd DATE, @Cards INT;
    DECLARE @Students TABLE (EnrollmentId INT NOT NULL PRIMARY KEY, ReportCardId INT NULL);

    BEGIN TRY
        SELECT @TermStart = t.StartDate, @TermEnd = t.EndDate
        FROM   academic.Terms AS t
        JOIN   academic.Sections AS s ON s.AcademicYearId = t.AcademicYearId
        WHERE  t.TermId = @TermId AND s.SectionId = @SectionId;

        IF @TermStart IS NULL THROW 54007, N'Term does not belong to the section''s academic year.', 1;

        BEGIN TRANSACTION;

        INSERT INTO @Students (EnrollmentId)
        SELECT DISTINCT sa.EnrollmentId
        FROM   enrollment.SectionAssignments AS sa
        WHERE  sa.SectionId = @SectionId
          AND  sa.StartDate <= @TermEnd
          AND  (sa.EndDate IS NULL OR sa.EndDate >= @TermStart)
          -- The student's section at the end of their time in the term owns the card.
          AND  NOT EXISTS (SELECT 1 FROM enrollment.SectionAssignments AS later
                           WHERE later.EnrollmentId = sa.EnrollmentId AND later.SectionId <> @SectionId
                             AND later.StartDate > sa.StartDate AND later.StartDate <= @TermEnd);

        -- Reuse an existing draft, otherwise create the next version.
        UPDATE st SET ReportCardId = rc.ReportCardId
        FROM   @Students AS st
        JOIN   assessment.ReportCards AS rc WITH (UPDLOCK)
               ON rc.EnrollmentId = st.EnrollmentId AND rc.TermId = @TermId AND rc.ReportCardStatus = N'Draft';

        INSERT INTO assessment.ReportCards (EnrollmentId, TermId, VersionNumber, ReportCardStatus, GeneratedAt)
        SELECT st.EnrollmentId, @TermId,
               ISNULL((SELECT MAX(VersionNumber) FROM assessment.ReportCards AS x WHERE x.EnrollmentId = st.EnrollmentId AND x.TermId = @TermId), 0) + 1,
               N'Draft', SYSUTCDATETIME()
        FROM   @Students AS st
        WHERE  st.ReportCardId IS NULL;

        UPDATE st SET ReportCardId = rc.ReportCardId
        FROM   @Students AS st
        JOIN   assessment.ReportCards AS rc ON rc.EnrollmentId = st.EnrollmentId AND rc.TermId = @TermId AND rc.ReportCardStatus = N'Draft'
        WHERE  st.ReportCardId IS NULL;

        DELETE l
        FROM   assessment.ReportCardLines AS l
        JOIN   @Students AS st ON st.ReportCardId = l.ReportCardId;

        -- One line per subject taught to the section in this term.
        INSERT INTO assessment.ReportCardLines (ReportCardId, CurriculumSubjectId, SubjectPercent, LetterGrade, IsPassed)
        SELECT st.ReportCardId, subj.CurriculumSubjectId, sc.SubjectPercent, band.LetterGrade,
               CASE WHEN sc.SubjectPercent IS NULL THEN NULL
                    WHEN sc.SubjectPercent >= gs.PassPercent THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END
        FROM   @Students AS st
        CROSS JOIN (SELECT DISTINCT ta.CurriculumSubjectId
                    FROM   academic.TeachingAssignments AS ta
                    WHERE  ta.SectionId = @SectionId AND (ta.TermId = @TermId OR ta.TermId IS NULL)) AS subj
        JOIN   academic.CurriculumSubjects AS cs ON cs.CurriculumSubjectId = subj.CurriculumSubjectId
        JOIN   assessment.GradingScales    AS gs ON gs.GradingScaleId = cs.GradingScaleId
        LEFT JOIN assessment.fn_SubjectTermScores(NULL, @TermId) AS sc
               ON sc.EnrollmentId = st.EnrollmentId AND sc.CurriculumSubjectId = subj.CurriculumSubjectId
        OUTER APPLY (SELECT TOP (1) b.LetterGrade
                     FROM   assessment.GradingScaleBands AS b
                     WHERE  b.GradingScaleId = cs.GradingScaleId AND b.MinPercent <= sc.SubjectPercent
                     ORDER BY b.MinPercent DESC) AS band;

        -- Header: overall percent and daily attendance in the term.
        UPDATE rc
        SET    OverallPercent = agg.OverallPercent,
               DaysPresent    = att.DaysPresent,
               DaysAbsent     = att.DaysAbsent,
               DaysLate       = att.DaysLate,
               GeneratedAt    = SYSUTCDATETIME(),
               UpdatedAt      = SYSUTCDATETIME(),
               UpdatedBy      = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        FROM   assessment.ReportCards AS rc
        JOIN   @Students AS st ON st.ReportCardId = rc.ReportCardId
        OUTER APPLY (SELECT CAST(AVG(l.SubjectPercent) AS DECIMAL(9,3)) AS OverallPercent
                     FROM assessment.ReportCardLines AS l WHERE l.ReportCardId = rc.ReportCardId AND l.SubjectPercent IS NOT NULL) AS agg
        OUTER APPLY (SELECT CAST(SUM(CASE WHEN s.CountsAsPresent = 1 THEN 1 ELSE 0 END) AS SMALLINT) AS DaysPresent,
                            CAST(SUM(CASE WHEN s.CountsAsPresent = 0 THEN 1 ELSE 0 END) AS SMALLINT) AS DaysAbsent,
                            CAST(SUM(CASE WHEN s.Code = N'LATE' THEN 1 ELSE 0 END) AS SMALLINT)       AS DaysLate
                     FROM   attendance.AttendanceRecords AS r
                     JOIN   attendance.AttendanceSessions AS ses ON ses.AttendanceSessionId = r.AttendanceSessionId
                     JOIN   attendance.AttendanceStatuses AS s ON s.AttendanceStatusId = r.AttendanceStatusId
                     WHERE  r.EnrollmentId = rc.EnrollmentId AND ses.PeriodId IS NULL
                       AND  r.SessionDate BETWEEN @TermStart AND @TermEnd) AS att;

        SELECT @Cards = COUNT(*) FROM @Students;

        DECLARE @Key NVARCHAR(100) = CONCAT(@SectionId, N'/', @TermId);
        DECLARE @NewJ NVARCHAR(MAX) = (SELECT @Cards AS DraftReportCards FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'ReportCardsGenerated', N'assessment', N'ReportCards', @Key, N'Execute', NULL, @NewJ, @Proc;

        COMMIT TRANSACTION;

        SELECT @Cards AS DraftReportCards;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   assessment.usp_PublishReportCards — Draft -> Published for a section/term;
   the previously published version becomes Superseded (snapshot preserved).
   ============================================================================= */
CREATE OR ALTER PROCEDURE assessment.usp_PublishReportCards
    @SectionId  INT,
    @TermId     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @Drafts TABLE (ReportCardId INT NOT NULL PRIMARY KEY, EnrollmentId INT NOT NULL);
    DECLARE @Published INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO @Drafts (ReportCardId, EnrollmentId)
        SELECT rc.ReportCardId, rc.EnrollmentId
        FROM   assessment.ReportCards AS rc WITH (UPDLOCK)
        WHERE  rc.TermId = @TermId AND rc.ReportCardStatus = N'Draft'
          AND  EXISTS (SELECT 1 FROM enrollment.SectionAssignments AS sa
                       WHERE sa.EnrollmentId = rc.EnrollmentId AND sa.SectionId = @SectionId);

        IF NOT EXISTS (SELECT 1 FROM @Drafts) THROW 54008, N'No draft report cards to publish for this section and term.', 1;

        UPDATE rc
        SET    ReportCardStatus = N'Superseded', UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        FROM   assessment.ReportCards AS rc
        JOIN   @Drafts AS d ON d.EnrollmentId = rc.EnrollmentId
        WHERE  rc.TermId = @TermId AND rc.ReportCardStatus = N'Published';

        UPDATE rc
        SET    ReportCardStatus = N'Published', PublishedAt = SYSUTCDATETIME(),
               UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        FROM   assessment.ReportCards AS rc
        JOIN   @Drafts AS d ON d.ReportCardId = rc.ReportCardId;
        SET @Published = @@ROWCOUNT;

        DECLARE @Key NVARCHAR(100) = CONCAT(@SectionId, N'/', @TermId);
        DECLARE @NewJ NVARCHAR(MAX) = (SELECT @Published AS ReportCardsPublished FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'ReportCardsPublished', N'assessment', N'ReportCards', @Key, N'Update', NULL, @NewJ, @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   finance.usp_IssueInvoice — issue the invoices for one fee installment of an
   enrollment: one invoice per responsible payer (StudentPayers shares must
   total 100%). Applies installment %, payer share, discounts and tax; rounds
   to the currency's minor units; numbers each invoice from the series table.
   Returns the invoices created.
   ============================================================================= */
CREATE OR ALTER PROCEDURE finance.usp_IssueInvoice
    @EnrollmentId       INT,
    @FeeInstallmentId   INT,
    @InvoiceDate        DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @YearId INT, @BranchId INT, @GradeId INT, @ProgramId INT, @Status NVARCHAR(20),
            @FeeStructureId INT, @CurrencyId INT, @Minor TINYINT, @InstNo TINYINT, @InstPct DECIMAL(7,4), @DueDate DATE,
            @FirstInstNo TINYINT, @PayerId INT, @Share DECIMAL(7,4), @InvoiceId BIGINT, @Number NVARCHAR(30);
    DECLARE @Created TABLE (InvoiceId BIGINT NOT NULL, InvoiceNumber NVARCHAR(30) NOT NULL, PayerId INT NOT NULL, TotalAmount DECIMAL(19,4) NOT NULL);
    DECLARE @Lines TABLE (LineNumber SMALLINT NOT NULL, FeeTypeId INT NOT NULL, DescriptionEn NVARCHAR(200) NOT NULL, DescriptionAr NVARCHAR(200) NOT NULL,
                          UnitAmount DECIMAL(19,4) NOT NULL, DiscountAmount DECIMAL(19,4) NOT NULL, TaxAmount DECIMAL(19,4) NOT NULL);

    SET @InvoiceDate = ISNULL(@InvoiceDate, CONVERT(DATE, SYSUTCDATETIME()));

    BEGIN TRY
        SELECT @YearId = AcademicYearId, @BranchId = BranchId, @GradeId = GradeLevelId, @ProgramId = ProgramId, @Status = EnrollmentStatus
        FROM   enrollment.Enrollments WHERE EnrollmentId = @EnrollmentId;
        IF @YearId IS NULL THROW 55001, N'Enrollment does not exist.', 1;
        IF @Status <> N'Enrolled' THROW 55002, N'Invoices can only be issued for Enrolled enrollments.', 1;

        SELECT @FeeStructureId = fs.FeeStructureId, @CurrencyId = fs.CurrencyId, @Minor = c.MinorUnits,
               @InstNo = fi.InstallmentNumber, @InstPct = fi.InstallmentPercent, @DueDate = fi.DueDate
        FROM   finance.FeeInstallments AS fi
        JOIN   finance.FeeStructures   AS fs ON fs.FeeStructureId = fi.FeeStructureId
        JOIN   finance.Currencies      AS c  ON c.CurrencyId = fs.CurrencyId
        WHERE  fi.FeeInstallmentId = @FeeInstallmentId
          AND  fs.AcademicYearId = @YearId AND fs.BranchId = @BranchId AND fs.GradeLevelId = @GradeId AND fs.ProgramId = @ProgramId
          AND  fs.IsActive = 1;
        IF @FeeStructureId IS NULL
            THROW 55003, N'Installment does not belong to the active fee structure for this enrollment.', 1;

        SELECT @FirstInstNo = MIN(InstallmentNumber) FROM finance.FeeInstallments WHERE FeeStructureId = @FeeStructureId;

        IF NOT EXISTS (SELECT 1 FROM finance.StudentPayers WHERE EnrollmentId = @EnrollmentId)
            THROW 55004, N'No payer is responsible for this enrollment.', 1;
        IF (SELECT SUM(ResponsibilityPercent) FROM finance.StudentPayers WHERE EnrollmentId = @EnrollmentId) <> 100
            THROW 55005, N'Payer responsibility percentages for this enrollment must total 100.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM finance.Invoices WITH (UPDLOCK, HOLDLOCK)
                   WHERE EnrollmentId = @EnrollmentId AND FeeInstallmentId = @FeeInstallmentId AND InvoiceStatus <> N'Cancelled')
            THROW 55006, N'This installment has already been invoiced for this enrollment.', 1;

        DECLARE payer_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT PayerId, ResponsibilityPercent FROM finance.StudentPayers WHERE EnrollmentId = @EnrollmentId ORDER BY PayerId;
        OPEN payer_cursor;
        FETCH NEXT FROM payer_cursor INTO @PayerId, @Share;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DELETE FROM @Lines;

            ;WITH Base AS
            (
                SELECT fsi.FeeTypeId, ft.NameEn, ft.NameAr, ft.IsTaxable, ft.TaxPercent,
                       CASE WHEN fsi.IsInstallable = 1 THEN fsi.Amount * @InstPct / 100
                            WHEN @InstNo = @FirstInstNo THEN fsi.Amount
                            ELSE 0 END * @Share / 100 AS Gross,
                       CASE WHEN fsi.IsInstallable = 1 THEN @InstPct / 100
                            WHEN @InstNo = @FirstInstNo THEN 1
                            ELSE 0 END * @Share / 100 AS Portion
                FROM   finance.FeeStructureItems AS fsi
                JOIN   finance.FeeTypes AS ft ON ft.FeeTypeId = fsi.FeeTypeId
                WHERE  fsi.FeeStructureId = @FeeStructureId
            ),
            Disc AS
            (
                SELECT b.FeeTypeId,
                       SUM(CASE WHEN sd.StudentDiscountId IS NULL      THEN 0
                                WHEN sd.DiscountPercent IS NOT NULL    THEN b.Gross * sd.DiscountPercent / 100
                                ELSE sd.DiscountAmount * b.Portion END) AS DiscountRaw
                FROM   Base AS b
                LEFT JOIN finance.StudentDiscounts AS sd
                       ON sd.EnrollmentId = @EnrollmentId AND sd.IsActive = 1
                      AND (sd.FeeTypeId = b.FeeTypeId OR (sd.FeeTypeId IS NULL AND sd.DiscountPercent IS NOT NULL))
                GROUP BY b.FeeTypeId
            )
            INSERT INTO @Lines (LineNumber, FeeTypeId, DescriptionEn, DescriptionAr, UnitAmount, DiscountAmount, TaxAmount)
            SELECT CAST(ROW_NUMBER() OVER (ORDER BY b.FeeTypeId) AS SMALLINT),
                   b.FeeTypeId,
                   CONCAT(b.NameEn, N' - Installment ', @InstNo),
                   CONCAT(b.NameAr, N' - القسط ', @InstNo),
                   ROUND(b.Gross, @Minor),
                   ROUND(CASE WHEN d.DiscountRaw > b.Gross THEN b.Gross ELSE d.DiscountRaw END, @Minor),
                   CASE WHEN b.IsTaxable = 1
                        THEN ROUND((b.Gross - CASE WHEN d.DiscountRaw > b.Gross THEN b.Gross ELSE d.DiscountRaw END) * b.TaxPercent / 100, @Minor)
                        ELSE 0 END
            FROM   Base AS b
            JOIN   Disc AS d ON d.FeeTypeId = b.FeeTypeId
            WHERE  ROUND(b.Gross, @Minor) > 0;

            IF NOT EXISTS (SELECT 1 FROM @Lines)
                THROW 55007, N'Nothing to invoice for this installment.', 1;

            EXEC organization.usp_GetNextDocumentNumber @DocumentType = N'Invoice', @BranchId = @BranchId,
                 @AcademicYearId = @YearId, @DocumentNumber = @Number OUTPUT;

            INSERT INTO finance.Invoices (InvoiceNumber, BranchId, EnrollmentId, PayerId, FeeInstallmentId, CurrencyId, InvoiceDate, DueDate,
                                          SubtotalAmount, DiscountAmount, TaxAmount, TotalAmount, PaidAmount, CreditedAmount, InvoiceStatus, IssuedAt)
            SELECT @Number, @BranchId, @EnrollmentId, @PayerId, @FeeInstallmentId, @CurrencyId, @InvoiceDate,
                   CASE WHEN @DueDate < @InvoiceDate THEN @InvoiceDate ELSE @DueDate END,
                   SUM(UnitAmount), SUM(DiscountAmount), SUM(TaxAmount),
                   SUM(UnitAmount) - SUM(DiscountAmount) + SUM(TaxAmount), 0, 0, N'Issued', SYSUTCDATETIME()
            FROM   @Lines;

            SET @InvoiceId = CAST(SCOPE_IDENTITY() AS BIGINT);

            INSERT INTO finance.InvoiceLines (InvoiceId, LineNumber, FeeTypeId, DescriptionEn, DescriptionAr, Quantity, UnitAmount, DiscountAmount, TaxAmount, LineTotal)
            SELECT @InvoiceId, LineNumber, FeeTypeId, DescriptionEn, DescriptionAr, 1, UnitAmount, DiscountAmount, TaxAmount,
                   UnitAmount - DiscountAmount + TaxAmount
            FROM   @Lines;

            INSERT INTO @Created (InvoiceId, InvoiceNumber, PayerId, TotalAmount)
            SELECT InvoiceId, InvoiceNumber, PayerId, TotalAmount FROM finance.Invoices WHERE InvoiceId = @InvoiceId;

            DECLARE @Key NVARCHAR(100) = CAST(@InvoiceId AS NVARCHAR(100));
            DECLARE @NewJ NVARCHAR(MAX) = (SELECT InvoiceNumber, EnrollmentId, PayerId, FeeInstallmentId, TotalAmount
                                           FROM finance.Invoices WHERE InvoiceId = @InvoiceId FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            EXEC audit.usp_LogEvent N'InvoiceIssued', N'finance', N'Invoices', @Key, N'Insert', NULL, @NewJ, @Proc;

            FETCH NEXT FROM payer_cursor INTO @PayerId, @Share;
        END;

        CLOSE payer_cursor;
        DEALLOCATE payer_cursor;

        COMMIT TRANSACTION;

        SELECT InvoiceId, InvoiceNumber, PayerId, TotalAmount FROM @Created;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   finance.usp_RecordPayment — record money received and allocate it.
   With @Allocations: explicit allocation (validated). Without: automatic FIFO
   allocation to the payer's open invoices by due date. Any remainder stays
   unallocated (credit on account, visible in finance.vw_PaymentAllocationStatus).
   ============================================================================= */
CREATE OR ALTER PROCEDURE finance.usp_RecordPayment
    @PayerId            INT,
    @BranchId           INT,
    @PaymentMethodCode  NVARCHAR(20),
    @PaymentDate        DATE,
    @Amount             DECIMAL(19,4),
    @Allocations        finance.AllocationList READONLY,
    @ReferenceNumber    NVARCHAR(100) = NULL,
    @Notes              NVARCHAR(500) = NULL,
    @PaymentId          BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @MethodId INT, @NeedsRef BIT, @CurrencyId INT, @YearId INT, @Receipt NVARCHAR(30), @Allocated DECIMAL(19,4);
    DECLARE @Alloc TABLE (InvoiceId BIGINT NOT NULL PRIMARY KEY, Amount DECIMAL(19,4) NOT NULL);

    BEGIN TRY
        IF @Amount IS NULL OR @Amount <= 0 THROW 55010, N'Payment amount must be greater than zero.', 1;
        IF NOT EXISTS (SELECT 1 FROM finance.Payers WHERE PayerId = @PayerId AND IsActive = 1)
            THROW 55011, N'Payer does not exist or is inactive.', 1;

        SELECT @MethodId = PaymentMethodId, @NeedsRef = RequiresReference
        FROM   finance.PaymentMethods WHERE Code = @PaymentMethodCode AND IsActive = 1;
        IF @MethodId IS NULL THROW 55012, N'Unknown or inactive payment method.', 1;
        IF @NeedsRef = 1 AND @ReferenceNumber IS NULL THROW 55013, N'This payment method requires a reference number.', 1;

        SELECT @CurrencyId = s.DefaultCurrencyId
        FROM   organization.Branches AS b JOIN organization.Schools AS s ON s.SchoolId = b.SchoolId
        WHERE  b.BranchId = @BranchId;
        IF @CurrencyId IS NULL THROW 55014, N'Branch does not exist.', 1;

        -- Receipt series is per branch and the academic year containing the payment date.
        SELECT TOP (1) @YearId = ay.AcademicYearId
        FROM   academic.AcademicYears AS ay
        JOIN   organization.Branches AS b ON b.SchoolId = ay.SchoolId
        WHERE  b.BranchId = @BranchId AND @PaymentDate BETWEEN ay.StartDate AND ay.EndDate;
        IF @YearId IS NULL
            SELECT TOP (1) @YearId = ay.AcademicYearId
            FROM   academic.AcademicYears AS ay JOIN organization.Branches AS b ON b.SchoolId = ay.SchoolId
            WHERE  b.BranchId = @BranchId AND ay.StartDate <= @PaymentDate
            ORDER BY ay.StartDate DESC;
        IF @YearId IS NULL THROW 55015, N'No academic year found for the payment date.', 1;

        IF EXISTS (SELECT InvoiceId FROM @Allocations GROUP BY InvoiceId HAVING COUNT(*) > 1)
            THROW 55016, N'Duplicate invoice in allocations.', 1;
        IF EXISTS (SELECT 1 FROM @Allocations WHERE Amount <= 0)
            THROW 55017, N'Allocation amounts must be greater than zero.', 1;
        IF (SELECT ISNULL(SUM(Amount), 0) FROM @Allocations) > @Amount
            THROW 55018, N'Allocations exceed the payment amount.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM @Allocations)
        BEGIN
            IF EXISTS (SELECT 1 FROM @Allocations AS a
                       LEFT JOIN finance.Invoices AS i WITH (UPDLOCK) ON i.InvoiceId = a.InvoiceId
                       WHERE i.InvoiceId IS NULL OR i.PayerId <> @PayerId OR i.InvoiceStatus NOT IN (N'Issued', N'PartiallyPaid')
                          OR a.Amount > i.TotalAmount - i.PaidAmount - i.CreditedAmount)
                THROW 55019, N'Each allocation must target an open invoice of this payer and not exceed its balance.', 1;

            INSERT INTO @Alloc (InvoiceId, Amount) SELECT InvoiceId, Amount FROM @Allocations;
        END
        ELSE
        BEGIN
            ;WITH OpenInv AS
            (
                SELECT i.InvoiceId,
                       i.TotalAmount - i.PaidAmount - i.CreditedAmount AS Balance,
                       SUM(i.TotalAmount - i.PaidAmount - i.CreditedAmount)
                           OVER (ORDER BY i.DueDate, i.InvoiceId ROWS UNBOUNDED PRECEDING) AS Cumulative
                FROM   finance.Invoices AS i WITH (UPDLOCK)
                WHERE  i.PayerId = @PayerId AND i.InvoiceStatus IN (N'Issued', N'PartiallyPaid')
            )
            INSERT INTO @Alloc (InvoiceId, Amount)
            SELECT InvoiceId,
                   CASE WHEN Cumulative <= @Amount THEN Balance ELSE @Amount - (Cumulative - Balance) END
            FROM   OpenInv
            WHERE  Cumulative - Balance < @Amount AND Balance > 0;
        END;

        EXEC organization.usp_GetNextDocumentNumber @DocumentType = N'Receipt', @BranchId = @BranchId,
             @AcademicYearId = @YearId, @DocumentNumber = @Receipt OUTPUT;

        INSERT INTO finance.Payments (ReceiptNumber, BranchId, PayerId, PaymentMethodId, CurrencyId, PaymentDate, Amount, ReferenceNumber, PaymentStatus, ReceivedByUserId, Notes)
        VALUES (@Receipt, @BranchId, @PayerId, @MethodId, @CurrencyId, @PaymentDate, @Amount, @ReferenceNumber, N'Received',
                TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId')), @Notes);

        SET @PaymentId = CAST(SCOPE_IDENTITY() AS BIGINT);

        INSERT INTO finance.PaymentAllocations (PaymentId, InvoiceId, AllocatedAmount)
        SELECT @PaymentId, InvoiceId, Amount FROM @Alloc;

        UPDATE i
        SET    PaidAmount    = i.PaidAmount + a.Amount,
               InvoiceStatus = CASE WHEN i.PaidAmount + a.Amount + i.CreditedAmount >= i.TotalAmount THEN N'Paid' ELSE N'PartiallyPaid' END,
               UpdatedAt     = SYSUTCDATETIME(),
               UpdatedBy     = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        FROM   finance.Invoices AS i
        JOIN   @Alloc AS a ON a.InvoiceId = i.InvoiceId;

        SELECT @Allocated = ISNULL(SUM(Amount), 0) FROM @Alloc;

        DECLARE @Key NVARCHAR(100) = CAST(@PaymentId AS NVARCHAR(100));
        DECLARE @NewJ NVARCHAR(MAX) = (SELECT @Receipt AS ReceiptNumber, @PayerId AS PayerId, @Amount AS Amount, @Allocated AS AllocatedAmount,
                                              @PaymentMethodCode AS PaymentMethod, @ReferenceNumber AS ReferenceNumber
                                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'PaymentRecorded', N'finance', N'Payments', @Key, N'Insert', NULL, @NewJ, @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   finance.usp_IssueCreditNote — reduce an invoice's balance (invoices are
   never edited or deleted once issued).
   ============================================================================= */
CREATE OR ALTER PROCEDURE finance.usp_IssueCreditNote
    @InvoiceId      BIGINT,
    @Amount         DECIMAL(19,4),
    @Reason         NVARCHAR(500),
    @CreditDate     DATE = NULL,
    @CreditNoteId   BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @Status NVARCHAR(20), @Balance DECIMAL(19,4), @BranchId INT, @YearId INT, @Number NVARCHAR(30);
    SET @CreditDate = ISNULL(@CreditDate, CONVERT(DATE, SYSUTCDATETIME()));

    BEGIN TRY
        IF @Amount IS NULL OR @Amount <= 0 THROW 55020, N'Credit amount must be greater than zero.', 1;

        BEGIN TRANSACTION;

        SELECT @Status = i.InvoiceStatus, @Balance = i.TotalAmount - i.PaidAmount - i.CreditedAmount,
               @BranchId = i.BranchId, @YearId = e.AcademicYearId
        FROM   finance.Invoices AS i WITH (UPDLOCK)
        JOIN   enrollment.Enrollments AS e ON e.EnrollmentId = i.EnrollmentId
        WHERE  i.InvoiceId = @InvoiceId;

        IF @Status IS NULL THROW 55021, N'Invoice does not exist.', 1;
        IF @Status NOT IN (N'Issued', N'PartiallyPaid') THROW 55022, N'Credit notes can only be issued against open invoices.', 1;
        IF @Amount > @Balance THROW 55023, N'Credit amount exceeds the invoice balance.', 1;

        EXEC organization.usp_GetNextDocumentNumber @DocumentType = N'CreditNote', @BranchId = @BranchId,
             @AcademicYearId = @YearId, @DocumentNumber = @Number OUTPUT;

        INSERT INTO finance.CreditNotes (CreditNoteNumber, InvoiceId, CreditDate, Amount, Reason)
        VALUES (@Number, @InvoiceId, @CreditDate, @Amount, @Reason);
        SET @CreditNoteId = CAST(SCOPE_IDENTITY() AS BIGINT);

        UPDATE finance.Invoices
        SET    CreditedAmount = CreditedAmount + @Amount,
               InvoiceStatus  = CASE WHEN PaidAmount + CreditedAmount + @Amount >= TotalAmount THEN N'Paid' ELSE InvoiceStatus END,
               UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        WHERE  InvoiceId = @InvoiceId;

        DECLARE @Key NVARCHAR(100) = CAST(@InvoiceId AS NVARCHAR(100));
        DECLARE @NewJ NVARCHAR(MAX) = (SELECT @Number AS CreditNoteNumber, @Amount AS Amount, @Reason AS Reason FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'CreditNoteIssued', N'finance', N'Invoices', @Key, N'Update', NULL, @NewJ, @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   finance.usp_CancelInvoice — only an invoice with no payments and no credits.
   ============================================================================= */
CREATE OR ALTER PROCEDURE finance.usp_CancelInvoice
    @InvoiceId  BIGINT,
    @Reason     NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Proc NVARCHAR(256) = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID));
    DECLARE @Status NVARCHAR(20), @Paid DECIMAL(19,4), @Credited DECIMAL(19,4);

    BEGIN TRY
        IF @Reason IS NULL THROW 55030, N'A cancellation reason is required.', 1;

        BEGIN TRANSACTION;

        SELECT @Status = InvoiceStatus, @Paid = PaidAmount, @Credited = CreditedAmount
        FROM   finance.Invoices WITH (UPDLOCK) WHERE InvoiceId = @InvoiceId;

        IF @Status IS NULL THROW 55021, N'Invoice does not exist.', 1;
        IF @Status <> N'Issued' OR @Paid <> 0 OR @Credited <> 0
            THROW 55031, N'Only an Issued invoice with no payments or credits can be cancelled; use a credit note instead.', 1;

        UPDATE finance.Invoices
        SET    InvoiceStatus = N'Cancelled', CancelledAt = SYSUTCDATETIME(), CancellationReason = @Reason,
               UpdatedAt = SYSUTCDATETIME(), UpdatedBy = TRY_CONVERT(INT, SESSION_CONTEXT(N'UserAccountId'))
        WHERE  InvoiceId = @InvoiceId;

        DECLARE @Key NVARCHAR(100) = CAST(@InvoiceId AS NVARCHAR(100));
        DECLARE @NewJ NVARCHAR(MAX) = (SELECT N'Cancelled' AS InvoiceStatus, @Reason AS Reason FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        EXEC audit.usp_LogEvent N'InvoiceCancelled', N'finance', N'Invoices', @Key, N'Update', NULL, @NewJ, @Proc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
