/* =============================================================================
   03_create_tables.sql
   Purpose     : Create every table: columns, data types, NULL/NOT NULL,
                 IDENTITY, ROWVERSION and (for temporal tables) PERIOD columns.
                 Keys are added in 04, UNIQUE/CHECK/DEFAULT in 05, indexes in 06.
   Dependencies: 02_create_schemas.sql
   Run order   : 3 of 12
   Idempotent  : Yes (IF OBJECT_ID(...) IS NULL around each CREATE TABLE).
   Conventions : - INT IDENTITY keys; BIGINT IDENTITY for high-volume tables
                   (attendance, assessment results, finance transactions, audit).
                 - Money = DECIMAL(19,4); percentages = DECIMAL(7,4);
                   scores = DECIMAL(9,3).
                 - Audit columns CreatedAt/CreatedBy/UpdatedAt/UpdatedBy.
                   CreatedBy/UpdatedBy are soft references to
                   iam.UserAccounts.UserAccountId (no FK by design).
                 - RowVer ROWVERSION on concurrently edited tables.
                 - Temporal tables (period columns SysStartTime/SysEndTime) are
                   switched to SYSTEM_VERSIONING = ON in 05 (after the PK).
                 - No table imposes a system-wide maximum number of students.
   ============================================================================= */
USE [$(DatabaseName)];
GO

/* =============================================================================
   organization
   ============================================================================= */
IF OBJECT_ID(N'organization.Countries', N'U') IS NULL
BEGIN
    CREATE TABLE organization.Countries
    (
        CountryId           INT             IDENTITY(1,1) NOT NULL,
        IsoAlpha2           NVARCHAR(2)     NOT NULL,
        IsoAlpha3           NVARCHAR(3)     NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        NationalityEn       NVARCHAR(100)   NULL,
        NationalityAr       NVARCHAR(100)   NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'organization.Schools', N'U') IS NULL
BEGIN
    CREATE TABLE organization.Schools
    (
        SchoolId            INT             IDENTITY(1,1) NOT NULL,
        SchoolCode          NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(200)   NOT NULL,
        NameAr              NVARCHAR(200)   NOT NULL,
        LicenseNumber       NVARCHAR(50)    NULL,
        CountryId           INT             NOT NULL,
        DefaultCurrencyId   INT             NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'organization.Branches', N'U') IS NULL
BEGIN
    CREATE TABLE organization.Branches
    (
        BranchId            INT             IDENTITY(1,1) NOT NULL,
        SchoolId            INT             NOT NULL,
        BranchCode          NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(200)   NOT NULL,
        NameAr              NVARCHAR(200)   NOT NULL,
        City                NVARCHAR(100)   NOT NULL,
        AddressLine         NVARCHAR(300)   NULL,
        Phone               NVARCHAR(30)    NULL,
        Email               NVARCHAR(254)   NULL,
        WorkingDaysMask     TINYINT         NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'organization.Buildings', N'U') IS NULL
BEGIN
    CREATE TABLE organization.Buildings
    (
        BuildingId          INT             IDENTITY(1,1) NOT NULL,
        BranchId            INT             NOT NULL,
        BuildingCode        NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'organization.RoomTypes', N'U') IS NULL
BEGIN
    CREATE TABLE organization.RoomTypes
    (
        RoomTypeId          INT             IDENTITY(1,1) NOT NULL,
        Code                NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'organization.Rooms', N'U') IS NULL
BEGIN
    CREATE TABLE organization.Rooms
    (
        RoomId              INT             IDENTITY(1,1) NOT NULL,
        BuildingId          INT             NOT NULL,
        RoomTypeId          INT             NOT NULL,
        RoomCode            NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        FloorNumber         SMALLINT        NULL,
        SeatCapacity        INT             NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'organization.Departments', N'U') IS NULL
BEGIN
    CREATE TABLE organization.Departments
    (
        DepartmentId        INT             IDENTITY(1,1) NOT NULL,
        SchoolId            INT             NOT NULL,
        DepartmentCode      NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        DepartmentType      NVARCHAR(20)    NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'organization.DocumentNumberSeries', N'U') IS NULL
BEGIN
    CREATE TABLE organization.DocumentNumberSeries
    (
        DocumentNumberSeriesId INT          IDENTITY(1,1) NOT NULL,
        DocumentType        NVARCHAR(20)    NOT NULL,
        BranchId            INT             NOT NULL,
        AcademicYearId      INT             NOT NULL,
        Prefix              NVARCHAR(20)    NOT NULL,
        NextNumber          INT             NOT NULL,
        PadLength           TINYINT         NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

/* =============================================================================
   iam  (the "identity" module; see 02_create_schemas.sql)
   ============================================================================= */
IF OBJECT_ID(N'iam.UserAccounts', N'U') IS NULL
BEGIN
    CREATE TABLE iam.UserAccounts
    (
        UserAccountId       INT             IDENTITY(1,1) NOT NULL,
        PersonId            INT             NULL,
        UserName            NVARCHAR(100)   NOT NULL,
        Email               NVARCHAR(254)   NULL,
        AuthProvider        NVARCHAR(20)    NOT NULL,
        PasswordHash        VARBINARY(256)  NULL,
        ExternalSubjectId   NVARCHAR(200)   NULL,
        AccountStatus       NVARCHAR(20)    NOT NULL,
        FailedLoginCount    INT             NOT NULL,
        LastLoginAt         DATETIME2(3)    NULL,
        PreferredLanguage   NVARCHAR(2)     NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL
    );
END;
GO

IF OBJECT_ID(N'iam.Roles', N'U') IS NULL
BEGIN
    CREATE TABLE iam.Roles
    (
        RoleId              INT             IDENTITY(1,1) NOT NULL,
        RoleCode            NVARCHAR(50)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        Description         NVARCHAR(400)   NULL,
        IsSystem            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'iam.Permissions', N'U') IS NULL
BEGIN
    CREATE TABLE iam.Permissions
    (
        PermissionId        INT             IDENTITY(1,1) NOT NULL,
        PermissionCode      NVARCHAR(100)   NOT NULL,
        ModuleName          NVARCHAR(30)    NOT NULL,
        Description         NVARCHAR(400)   NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

-- Pure associative entity: composite primary key (RoleId, PermissionId).
IF OBJECT_ID(N'iam.RolePermissions', N'U') IS NULL
BEGIN
    CREATE TABLE iam.RolePermissions
    (
        RoleId              INT             NOT NULL,
        PermissionId        INT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'iam.UserRoles', N'U') IS NULL
BEGIN
    CREATE TABLE iam.UserRoles
    (
        UserRoleId          INT             IDENTITY(1,1) NOT NULL,
        UserAccountId       INT             NOT NULL,
        RoleId              INT             NOT NULL,
        BranchId            INT             NULL,
        ValidFrom           DATE            NOT NULL,
        ValidTo             DATE            NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

/* =============================================================================
   people  (supertype Persons; subtypes Students, Guardians, Employees;
            Teachers is a subtype of Employees)
   ============================================================================= */
IF OBJECT_ID(N'people.Persons', N'U') IS NULL
BEGIN
    CREATE TABLE people.Persons
    (
        PersonId            INT             IDENTITY(1,1) NOT NULL,
        FirstNameEn         NVARCHAR(100)   NOT NULL,
        FatherNameEn        NVARCHAR(100)   NULL,
        GrandfatherNameEn   NVARCHAR(100)   NULL,
        FamilyNameEn        NVARCHAR(100)   NOT NULL,
        FirstNameAr         NVARCHAR(100)   NOT NULL,
        FatherNameAr        NVARCHAR(100)   NULL,
        GrandfatherNameAr   NVARCHAR(100)   NULL,
        FamilyNameAr        NVARCHAR(100)   NOT NULL,
        Gender              NVARCHAR(1)     NOT NULL,
        DateOfBirth         DATE            NULL,
        NationalityCountryId INT            NULL,
        PrimaryLanguage     NVARCHAR(2)     NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL,
        SysStartTime        DATETIME2(7)    GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
        SysEndTime          DATETIME2(7)    GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
        PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime)
    );
END;
GO

IF OBJECT_ID(N'people.PersonContacts', N'U') IS NULL
BEGIN
    CREATE TABLE people.PersonContacts
    (
        PersonContactId     INT             IDENTITY(1,1) NOT NULL,
        PersonId            INT             NOT NULL,
        ContactType         NVARCHAR(20)    NOT NULL,
        ContactValue        NVARCHAR(254)   NOT NULL,
        IsPrimary           BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'people.PersonAddresses', N'U') IS NULL
BEGIN
    CREATE TABLE people.PersonAddresses
    (
        PersonAddressId     INT             IDENTITY(1,1) NOT NULL,
        PersonId            INT             NOT NULL,
        AddressType         NVARCHAR(20)    NOT NULL,
        CountryId           INT             NOT NULL,
        City                NVARCHAR(100)   NOT NULL,
        Area                NVARCHAR(100)   NULL,
        Street              NVARCHAR(200)   NULL,
        BuildingNumber      NVARCHAR(20)    NULL,
        PostalCode          NVARCHAR(20)    NULL,
        IsPrimary           BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'people.IdentityDocumentTypes', N'U') IS NULL
BEGIN
    CREATE TABLE people.IdentityDocumentTypes
    (
        IdentityDocumentTypeId INT          IDENTITY(1,1) NOT NULL,
        Code                NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'people.PersonIdentityDocuments', N'U') IS NULL
BEGIN
    CREATE TABLE people.PersonIdentityDocuments
    (
        PersonIdentityDocumentId INT        IDENTITY(1,1) NOT NULL,
        PersonId            INT             NOT NULL,
        IdentityDocumentTypeId INT          NOT NULL,
        IssuingCountryId    INT             NOT NULL,
        DocumentNumber      NVARCHAR(50)    NOT NULL,
        IssueDate           DATE            NULL,
        ExpiryDate          DATE            NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

-- Subtype of Persons: PersonId is both PK and FK to people.Persons.
IF OBJECT_ID(N'people.Students', N'U') IS NULL
BEGIN
    CREATE TABLE people.Students
    (
        PersonId            INT             NOT NULL,
        StudentNumber       NVARCHAR(20)    NOT NULL,
        AdmissionDate       DATE            NOT NULL,
        StudentStatus       NVARCHAR(20)    NOT NULL,
        PreviousSchool      NVARCHAR(200)   NULL,
        MedicalNotes        NVARCHAR(1000)  NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL
    );
END;
GO

-- Subtype of Persons.
IF OBJECT_ID(N'people.Guardians', N'U') IS NULL
BEGIN
    CREATE TABLE people.Guardians
    (
        PersonId            INT             NOT NULL,
        Occupation          NVARCHAR(100)   NULL,
        EmployerName        NVARCHAR(200)   NULL,
        PreferredLanguage   NVARCHAR(2)     NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

-- Subtype of Persons. A future hr module could extend this table by shared PK.
IF OBJECT_ID(N'people.Employees', N'U') IS NULL
BEGIN
    CREATE TABLE people.Employees
    (
        PersonId            INT             NOT NULL,
        EmployeeNumber      NVARCHAR(20)    NOT NULL,
        DepartmentId        INT             NULL,
        PrimaryBranchId     INT             NOT NULL,
        JobTitleEn          NVARCHAR(100)   NOT NULL,
        JobTitleAr          NVARCHAR(100)   NOT NULL,
        HireDate            DATE            NOT NULL,
        TerminationDate     DATE            NULL,
        EmploymentStatus    NVARCHAR(20)    NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

-- Subtype of Employees (not of Persons): PersonId is PK and FK to people.Employees.
IF OBJECT_ID(N'people.Teachers', N'U') IS NULL
BEGIN
    CREATE TABLE people.Teachers
    (
        PersonId            INT             NOT NULL,
        TeachingLicenseNumber NVARCHAR(50)  NULL,
        Specialization      NVARCHAR(100)   NULL,
        MaxWeeklyPeriods    TINYINT         NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'people.RelationshipTypes', N'U') IS NULL
BEGIN
    CREATE TABLE people.RelationshipTypes
    (
        RelationshipTypeId  INT             IDENTITY(1,1) NOT NULL,
        Code                NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'people.StudentGuardians', N'U') IS NULL
BEGIN
    CREATE TABLE people.StudentGuardians
    (
        StudentGuardianId   INT             IDENTITY(1,1) NOT NULL,
        StudentId           INT             NOT NULL,
        GuardianId          INT             NOT NULL,
        RelationshipTypeId  INT             NOT NULL,
        IsPrimaryContact    BIT             NOT NULL,
        HasCustody          BIT             NOT NULL,
        CanPickUp           BIT             NOT NULL,
        IsEmergencyContact  BIT             NOT NULL,
        LivesWithStudent    BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

/* =============================================================================
   academic
   ============================================================================= */
IF OBJECT_ID(N'academic.AcademicYears', N'U') IS NULL
BEGIN
    CREATE TABLE academic.AcademicYears
    (
        AcademicYearId      INT             IDENTITY(1,1) NOT NULL,
        SchoolId            INT             NOT NULL,
        YearCode            NVARCHAR(9)     NOT NULL,
        NameEn              NVARCHAR(50)    NOT NULL,
        NameAr              NVARCHAR(50)    NOT NULL,
        StartDate           DATE            NOT NULL,
        EndDate             DATE            NOT NULL,
        YearStatus          NVARCHAR(20)    NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'academic.Terms', N'U') IS NULL
BEGIN
    CREATE TABLE academic.Terms
    (
        TermId              INT             IDENTITY(1,1) NOT NULL,
        AcademicYearId      INT             NOT NULL,
        TermNumber          TINYINT         NOT NULL,
        NameEn              NVARCHAR(50)    NOT NULL,
        NameAr              NVARCHAR(50)    NOT NULL,
        StartDate           DATE            NOT NULL,
        EndDate             DATE            NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'academic.Holidays', N'U') IS NULL
BEGIN
    CREATE TABLE academic.Holidays
    (
        HolidayId           INT             IDENTITY(1,1) NOT NULL,
        AcademicYearId      INT             NOT NULL,
        BranchId            INT             NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        StartDate           DATE            NOT NULL,
        EndDate             DATE            NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'academic.GradeLevels', N'U') IS NULL
BEGIN
    CREATE TABLE academic.GradeLevels
    (
        GradeLevelId        INT             IDENTITY(1,1) NOT NULL,
        Code                NVARCHAR(10)    NOT NULL,
        NameEn              NVARCHAR(50)    NOT NULL,
        NameAr              NVARCHAR(50)    NOT NULL,
        Stage               NVARCHAR(20)    NOT NULL,
        SortOrder           SMALLINT        NOT NULL,
        NextGradeLevelId    INT             NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'academic.Programs', N'U') IS NULL
BEGIN
    CREATE TABLE academic.Programs
    (
        ProgramId           INT             IDENTITY(1,1) NOT NULL,
        Code                NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        Description         NVARCHAR(400)   NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'academic.Subjects', N'U') IS NULL
BEGIN
    CREATE TABLE academic.Subjects
    (
        SubjectId           INT             IDENTITY(1,1) NOT NULL,
        SubjectCode         NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        DepartmentId        INT             NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'academic.CurriculumSubjects', N'U') IS NULL
BEGIN
    CREATE TABLE academic.CurriculumSubjects
    (
        CurriculumSubjectId INT             IDENTITY(1,1) NOT NULL,
        AcademicYearId      INT             NOT NULL,
        GradeLevelId        INT             NOT NULL,
        ProgramId           INT             NOT NULL,
        SubjectId           INT             NOT NULL,
        GradingScaleId      INT             NOT NULL,
        WeeklyPeriods       TINYINT         NOT NULL,
        IsElective          BIT             NOT NULL,
        ReportOrder         SMALLINT        NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

-- Capacity is optional, per-section business data (no system-wide limit).
IF OBJECT_ID(N'academic.Sections', N'U') IS NULL
BEGIN
    CREATE TABLE academic.Sections
    (
        SectionId           INT             IDENTITY(1,1) NOT NULL,
        AcademicYearId      INT             NOT NULL,
        BranchId            INT             NOT NULL,
        GradeLevelId        INT             NOT NULL,
        ProgramId           INT             NOT NULL,
        SectionCode         NVARCHAR(10)    NOT NULL,
        NameEn              NVARCHAR(50)    NOT NULL,
        NameAr              NVARCHAR(50)    NOT NULL,
        Capacity            INT             NULL,
        HomeroomTeacherId   INT             NULL,
        HomeRoomId          INT             NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL
    );
END;
GO

IF OBJECT_ID(N'academic.TeachingAssignments', N'U') IS NULL
BEGIN
    CREATE TABLE academic.TeachingAssignments
    (
        TeachingAssignmentId INT            IDENTITY(1,1) NOT NULL,
        SectionId           INT             NOT NULL,
        CurriculumSubjectId INT             NOT NULL,
        TeacherId           INT             NOT NULL,
        TermId              INT             NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

/* =============================================================================
   enrollment
   ============================================================================= */
IF OBJECT_ID(N'enrollment.Applications', N'U') IS NULL
BEGIN
    CREATE TABLE enrollment.Applications
    (
        ApplicationId       INT             IDENTITY(1,1) NOT NULL,
        ApplicationNumber   NVARCHAR(30)    NOT NULL,
        ApplicantPersonId   INT             NOT NULL,
        AcademicYearId      INT             NOT NULL,
        BranchId            INT             NOT NULL,
        GradeLevelId        INT             NOT NULL,
        ProgramId           INT             NULL,
        ApplicationDate     DATE            NOT NULL,
        ApplicationStatus   NVARCHAR(20)    NOT NULL,
        DecisionDate        DATE            NULL,
        DecisionNotes       NVARCHAR(1000)  NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL
    );
END;
GO

-- Append-only log: uses ChangedAt/ChangedBy instead of the four audit columns.
IF OBJECT_ID(N'enrollment.ApplicationStatusHistory', N'U') IS NULL
BEGIN
    CREATE TABLE enrollment.ApplicationStatusHistory
    (
        ApplicationStatusHistoryId INT      IDENTITY(1,1) NOT NULL,
        ApplicationId       INT             NOT NULL,
        FromStatus          NVARCHAR(20)    NULL,
        ToStatus            NVARCHAR(20)    NOT NULL,
        Notes               NVARCHAR(500)   NULL,
        ChangedAt           DATETIME2(3)    NOT NULL,
        ChangedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'enrollment.Enrollments', N'U') IS NULL
BEGIN
    CREATE TABLE enrollment.Enrollments
    (
        EnrollmentId        INT             IDENTITY(1,1) NOT NULL,
        StudentId           INT             NOT NULL,
        AcademicYearId      INT             NOT NULL,
        BranchId            INT             NOT NULL,
        GradeLevelId        INT             NOT NULL,
        ProgramId           INT             NOT NULL,
        ApplicationId       INT             NULL,
        EnrollmentDate      DATE            NOT NULL,
        WithdrawalDate      DATE            NULL,
        EnrollmentStatus    NVARCHAR(20)    NOT NULL,
        PromotionOutcome    NVARCHAR(20)    NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL,
        SysStartTime        DATETIME2(7)    GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
        SysEndTime          DATETIME2(7)    GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
        PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime)
    );
END;
GO

-- AcademicYearId is carried so composite FKs guarantee that the section and
-- the enrollment belong to the same academic year.
IF OBJECT_ID(N'enrollment.SectionAssignments', N'U') IS NULL
BEGIN
    CREATE TABLE enrollment.SectionAssignments
    (
        SectionAssignmentId INT             IDENTITY(1,1) NOT NULL,
        EnrollmentId        INT             NOT NULL,
        AcademicYearId      INT             NOT NULL,
        SectionId           INT             NOT NULL,
        StartDate           DATE            NOT NULL,
        EndDate             DATE            NULL,
        Reason              NVARCHAR(200)   NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL
    );
END;
GO

IF OBJECT_ID(N'enrollment.EnrollmentSubjects', N'U') IS NULL
BEGIN
    CREATE TABLE enrollment.EnrollmentSubjects
    (
        EnrollmentSubjectId INT             IDENTITY(1,1) NOT NULL,
        EnrollmentId        INT             NOT NULL,
        CurriculumSubjectId INT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

/* =============================================================================
   timetable
   ============================================================================= */
IF OBJECT_ID(N'timetable.BellSchedules', N'U') IS NULL
BEGIN
    CREATE TABLE timetable.BellSchedules
    (
        BellScheduleId      INT             IDENTITY(1,1) NOT NULL,
        BranchId            INT             NOT NULL,
        AcademicYearId      INT             NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        IsDefault           BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'timetable.Periods', N'U') IS NULL
BEGIN
    CREATE TABLE timetable.Periods
    (
        PeriodId            INT             IDENTITY(1,1) NOT NULL,
        BellScheduleId      INT             NOT NULL,
        PeriodNumber        TINYINT         NOT NULL,
        NameEn              NVARCHAR(50)    NOT NULL,
        NameAr              NVARCHAR(50)    NOT NULL,
        StartTime           TIME(0)         NOT NULL,
        EndTime             TIME(0)         NOT NULL,
        IsBreak             BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'timetable.Timetables', N'U') IS NULL
BEGIN
    CREATE TABLE timetable.Timetables
    (
        TimetableId         INT             IDENTITY(1,1) NOT NULL,
        SectionId           INT             NOT NULL,
        TermId              INT             NOT NULL,
        BellScheduleId      INT             NOT NULL,
        VersionNumber       SMALLINT        NOT NULL,
        TimetableStatus     NVARCHAR(20)    NOT NULL,
        EffectiveFrom       DATE            NOT NULL,
        EffectiveTo         DATE            NULL,
        PublishedAt         DATETIME2(3)    NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL
    );
END;
GO

IF OBJECT_ID(N'timetable.TimetableEntries', N'U') IS NULL
BEGIN
    CREATE TABLE timetable.TimetableEntries
    (
        TimetableEntryId    INT             IDENTITY(1,1) NOT NULL,
        TimetableId         INT             NOT NULL,
        DayOfWeek           TINYINT         NOT NULL,
        PeriodId            INT             NOT NULL,
        TeachingAssignmentId INT            NOT NULL,
        RoomId              INT             NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL
    );
END;
GO

/* =============================================================================
   attendance
   ============================================================================= */
IF OBJECT_ID(N'attendance.AttendanceStatuses', N'U') IS NULL
BEGIN
    CREATE TABLE attendance.AttendanceStatuses
    (
        AttendanceStatusId  INT             IDENTITY(1,1) NOT NULL,
        Code                NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(50)    NOT NULL,
        NameAr              NVARCHAR(50)    NOT NULL,
        CountsAsPresent     BIT             NOT NULL,
        IsExcused           BIT             NOT NULL,
        SortOrder           SMALLINT        NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

-- PeriodId NULL = daily roll-call; NOT NULL = per-period roll-call.
IF OBJECT_ID(N'attendance.AttendanceSessions', N'U') IS NULL
BEGIN
    CREATE TABLE attendance.AttendanceSessions
    (
        AttendanceSessionId BIGINT          IDENTITY(1,1) NOT NULL,
        SectionId           INT             NOT NULL,
        SessionDate         DATE            NOT NULL,
        PeriodId            INT             NULL,
        TakenByEmployeeId   INT             NULL,
        TakenAt             DATETIME2(3)    NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

-- SessionDate and SectionId are deliberately copied from the session and kept
-- consistent by a composite FK; they serve the student+date / section+date paths.
IF OBJECT_ID(N'attendance.AttendanceRecords', N'U') IS NULL
BEGIN
    CREATE TABLE attendance.AttendanceRecords
    (
        AttendanceRecordId  BIGINT          IDENTITY(1,1) NOT NULL,
        AttendanceSessionId BIGINT          NOT NULL,
        SessionDate         DATE            NOT NULL,
        SectionId           INT             NOT NULL,
        EnrollmentId        INT             NOT NULL,
        AttendanceStatusId  INT             NOT NULL,
        MinutesLate         SMALLINT        NULL,
        Remarks             NVARCHAR(500)   NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

/* =============================================================================
   assessment
   ============================================================================= */
IF OBJECT_ID(N'assessment.GradingScales', N'U') IS NULL
BEGIN
    CREATE TABLE assessment.GradingScales
    (
        GradingScaleId      INT             IDENTITY(1,1) NOT NULL,
        Code                NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        PassPercent         DECIMAL(7,4)    NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'assessment.GradingScaleBands', N'U') IS NULL
BEGIN
    CREATE TABLE assessment.GradingScaleBands
    (
        GradingScaleBandId  INT             IDENTITY(1,1) NOT NULL,
        GradingScaleId      INT             NOT NULL,
        MinPercent          DECIMAL(7,4)    NOT NULL,
        MaxPercent          DECIMAL(7,4)    NOT NULL,
        LetterGrade         NVARCHAR(5)     NOT NULL,
        DescriptorEn        NVARCHAR(50)    NOT NULL,
        DescriptorAr        NVARCHAR(50)    NOT NULL,
        GradePoint          DECIMAL(3,2)    NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'assessment.AssessmentTypes', N'U') IS NULL
BEGIN
    CREATE TABLE assessment.AssessmentTypes
    (
        AssessmentTypeId    INT             IDENTITY(1,1) NOT NULL,
        Code                NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(50)    NOT NULL,
        NameAr              NVARCHAR(50)    NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'assessment.AssessmentWeights', N'U') IS NULL
BEGIN
    CREATE TABLE assessment.AssessmentWeights
    (
        AssessmentWeightId  INT             IDENTITY(1,1) NOT NULL,
        CurriculumSubjectId INT             NOT NULL,
        TermId              INT             NOT NULL,
        AssessmentTypeId    INT             NOT NULL,
        WeightPercent       DECIMAL(7,4)    NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'assessment.Assessments', N'U') IS NULL
BEGIN
    CREATE TABLE assessment.Assessments
    (
        AssessmentId        INT             IDENTITY(1,1) NOT NULL,
        TeachingAssignmentId INT            NOT NULL,
        TermId              INT             NOT NULL,
        AssessmentTypeId    INT             NOT NULL,
        TitleEn             NVARCHAR(200)   NOT NULL,
        TitleAr             NVARCHAR(200)   NOT NULL,
        AssessmentDate      DATE            NOT NULL,
        MaxScore            DECIMAL(9,3)    NOT NULL,
        IsPublished         BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'assessment.AssessmentResults', N'U') IS NULL
BEGIN
    CREATE TABLE assessment.AssessmentResults
    (
        AssessmentResultId  BIGINT          IDENTITY(1,1) NOT NULL,
        AssessmentId        INT             NOT NULL,
        EnrollmentId        INT             NOT NULL,
        Score               DECIMAL(9,3)    NULL,
        IsAbsent            BIT             NOT NULL,
        IsExempt            BIT             NOT NULL,
        Comment             NVARCHAR(500)   NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL,
        SysStartTime        DATETIME2(7)    GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
        SysEndTime          DATETIME2(7)    GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
        PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime)
    );
END;
GO

IF OBJECT_ID(N'assessment.ReportCards', N'U') IS NULL
BEGIN
    CREATE TABLE assessment.ReportCards
    (
        ReportCardId        INT             IDENTITY(1,1) NOT NULL,
        EnrollmentId        INT             NOT NULL,
        TermId              INT             NOT NULL,
        VersionNumber       SMALLINT        NOT NULL,
        ReportCardStatus    NVARCHAR(20)    NOT NULL,
        OverallPercent      DECIMAL(9,3)    NULL,
        DaysPresent         SMALLINT        NULL,
        DaysAbsent          SMALLINT        NULL,
        DaysLate            SMALLINT        NULL,
        HomeroomCommentEn   NVARCHAR(1000)  NULL,
        HomeroomCommentAr   NVARCHAR(1000)  NULL,
        GeneratedAt         DATETIME2(3)    NOT NULL,
        PublishedAt         DATETIME2(3)    NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL
    );
END;
GO

IF OBJECT_ID(N'assessment.ReportCardLines', N'U') IS NULL
BEGIN
    CREATE TABLE assessment.ReportCardLines
    (
        ReportCardLineId    BIGINT          IDENTITY(1,1) NOT NULL,
        ReportCardId        INT             NOT NULL,
        CurriculumSubjectId INT             NOT NULL,
        SubjectPercent      DECIMAL(9,3)    NULL,
        LetterGrade         NVARCHAR(5)     NULL,
        IsPassed            BIT             NULL,
        TeacherCommentEn    NVARCHAR(500)   NULL,
        TeacherCommentAr    NVARCHAR(500)   NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

/* =============================================================================
   finance
   ============================================================================= */
IF OBJECT_ID(N'finance.Currencies', N'U') IS NULL
BEGIN
    CREATE TABLE finance.Currencies
    (
        CurrencyId          INT             IDENTITY(1,1) NOT NULL,
        CurrencyCode        NVARCHAR(3)     NOT NULL,
        NameEn              NVARCHAR(50)    NOT NULL,
        NameAr              NVARCHAR(50)    NOT NULL,
        MinorUnits          TINYINT         NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'finance.FeeTypes', N'U') IS NULL
BEGIN
    CREATE TABLE finance.FeeTypes
    (
        FeeTypeId           INT             IDENTITY(1,1) NOT NULL,
        Code                NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        IsTaxable           BIT             NOT NULL,
        TaxPercent          DECIMAL(7,4)    NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'finance.FeeStructures', N'U') IS NULL
BEGIN
    CREATE TABLE finance.FeeStructures
    (
        FeeStructureId      INT             IDENTITY(1,1) NOT NULL,
        AcademicYearId      INT             NOT NULL,
        BranchId            INT             NOT NULL,
        GradeLevelId        INT             NOT NULL,
        ProgramId           INT             NOT NULL,
        CurrencyId          INT             NOT NULL,
        NameEn              NVARCHAR(200)   NOT NULL,
        NameAr              NVARCHAR(200)   NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'finance.FeeStructureItems', N'U') IS NULL
BEGIN
    CREATE TABLE finance.FeeStructureItems
    (
        FeeStructureItemId  INT             IDENTITY(1,1) NOT NULL,
        FeeStructureId      INT             NOT NULL,
        FeeTypeId           INT             NOT NULL,
        Amount              DECIMAL(19,4)   NOT NULL,
        IsMandatory         BIT             NOT NULL,
        IsInstallable       BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        SysStartTime        DATETIME2(7)    GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
        SysEndTime          DATETIME2(7)    GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
        PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime)
    );
END;
GO

IF OBJECT_ID(N'finance.FeeInstallments', N'U') IS NULL
BEGIN
    CREATE TABLE finance.FeeInstallments
    (
        FeeInstallmentId    INT             IDENTITY(1,1) NOT NULL,
        FeeStructureId      INT             NOT NULL,
        InstallmentNumber   TINYINT         NOT NULL,
        DueDate             DATE            NOT NULL,
        InstallmentPercent  DECIMAL(7,4)    NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'finance.DiscountTypes', N'U') IS NULL
BEGIN
    CREATE TABLE finance.DiscountTypes
    (
        DiscountTypeId      INT             IDENTITY(1,1) NOT NULL,
        Code                NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        DefaultPercent      DECIMAL(7,4)    NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

-- FeeTypeId NULL = the discount applies to every installable fee type.
IF OBJECT_ID(N'finance.StudentDiscounts', N'U') IS NULL
BEGIN
    CREATE TABLE finance.StudentDiscounts
    (
        StudentDiscountId   INT             IDENTITY(1,1) NOT NULL,
        EnrollmentId        INT             NOT NULL,
        DiscountTypeId      INT             NOT NULL,
        FeeTypeId           INT             NULL,
        DiscountPercent     DECIMAL(7,4)    NULL,
        DiscountAmount      DECIMAL(19,4)   NULL,
        Reason              NVARCHAR(500)   NULL,
        ApprovedByUserId    INT             NULL,
        ApprovedAt          DATETIME2(3)    NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL
    );
END;
GO

IF OBJECT_ID(N'finance.Sponsors', N'U') IS NULL
BEGIN
    CREATE TABLE finance.Sponsors
    (
        SponsorId           INT             IDENTITY(1,1) NOT NULL,
        SponsorCode         NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(200)   NOT NULL,
        NameAr              NVARCHAR(200)   NOT NULL,
        SponsorType         NVARCHAR(20)    NOT NULL,
        ContactName         NVARCHAR(200)   NULL,
        Phone               NVARCHAR(30)    NULL,
        Email               NVARCHAR(254)   NULL,
        TaxNumber           NVARCHAR(50)    NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

-- EER category (union type): a payer is exactly one Guardian OR one Sponsor.
IF OBJECT_ID(N'finance.Payers', N'U') IS NULL
BEGIN
    CREATE TABLE finance.Payers
    (
        PayerId             INT             IDENTITY(1,1) NOT NULL,
        PayerType           NVARCHAR(10)    NOT NULL,
        GuardianId          INT             NULL,
        SponsorId           INT             NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'finance.StudentPayers', N'U') IS NULL
BEGIN
    CREATE TABLE finance.StudentPayers
    (
        StudentPayerId      INT             IDENTITY(1,1) NOT NULL,
        EnrollmentId        INT             NOT NULL,
        PayerId             INT             NOT NULL,
        ResponsibilityPercent DECIMAL(7,4)  NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'finance.Invoices', N'U') IS NULL
BEGIN
    CREATE TABLE finance.Invoices
    (
        InvoiceId           BIGINT          IDENTITY(1,1) NOT NULL,
        InvoiceNumber       NVARCHAR(30)    NOT NULL,
        BranchId            INT             NOT NULL,
        EnrollmentId        INT             NOT NULL,
        PayerId             INT             NOT NULL,
        FeeInstallmentId    INT             NULL,
        CurrencyId          INT             NOT NULL,
        InvoiceDate         DATE            NOT NULL,
        DueDate             DATE            NOT NULL,
        SubtotalAmount      DECIMAL(19,4)   NOT NULL,
        DiscountAmount      DECIMAL(19,4)   NOT NULL,
        TaxAmount           DECIMAL(19,4)   NOT NULL,
        TotalAmount         DECIMAL(19,4)   NOT NULL,
        PaidAmount          DECIMAL(19,4)   NOT NULL,
        CreditedAmount      DECIMAL(19,4)   NOT NULL,
        InvoiceStatus       NVARCHAR(20)    NOT NULL,
        IssuedAt            DATETIME2(3)    NOT NULL,
        CancelledAt         DATETIME2(3)    NULL,
        CancellationReason  NVARCHAR(500)   NULL,
        Notes               NVARCHAR(500)   NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL
    );
END;
GO

IF OBJECT_ID(N'finance.InvoiceLines', N'U') IS NULL
BEGIN
    CREATE TABLE finance.InvoiceLines
    (
        InvoiceLineId       BIGINT          IDENTITY(1,1) NOT NULL,
        InvoiceId           BIGINT          NOT NULL,
        LineNumber          SMALLINT        NOT NULL,
        FeeTypeId           INT             NOT NULL,
        DescriptionEn       NVARCHAR(200)   NOT NULL,
        DescriptionAr       NVARCHAR(200)   NOT NULL,
        Quantity            DECIMAL(9,3)    NOT NULL,
        UnitAmount          DECIMAL(19,4)   NOT NULL,
        DiscountAmount      DECIMAL(19,4)   NOT NULL,
        TaxAmount           DECIMAL(19,4)   NOT NULL,
        LineTotal           DECIMAL(19,4)   NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'finance.CreditNotes', N'U') IS NULL
BEGIN
    CREATE TABLE finance.CreditNotes
    (
        CreditNoteId        BIGINT          IDENTITY(1,1) NOT NULL,
        CreditNoteNumber    NVARCHAR(30)    NOT NULL,
        InvoiceId           BIGINT          NOT NULL,
        CreditDate          DATE            NOT NULL,
        Amount              DECIMAL(19,4)   NOT NULL,
        Reason              NVARCHAR(500)   NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'finance.PaymentMethods', N'U') IS NULL
BEGIN
    CREATE TABLE finance.PaymentMethods
    (
        PaymentMethodId     INT             IDENTITY(1,1) NOT NULL,
        Code                NVARCHAR(20)    NOT NULL,
        NameEn              NVARCHAR(100)   NOT NULL,
        NameAr              NVARCHAR(100)   NOT NULL,
        RequiresReference   BIT             NOT NULL,
        IsActive            BIT             NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

IF OBJECT_ID(N'finance.Payments', N'U') IS NULL
BEGIN
    CREATE TABLE finance.Payments
    (
        PaymentId           BIGINT          IDENTITY(1,1) NOT NULL,
        ReceiptNumber       NVARCHAR(30)    NOT NULL,
        BranchId            INT             NOT NULL,
        PayerId             INT             NOT NULL,
        PaymentMethodId     INT             NOT NULL,
        CurrencyId          INT             NOT NULL,
        PaymentDate         DATE            NOT NULL,
        Amount              DECIMAL(19,4)   NOT NULL,
        ReferenceNumber     NVARCHAR(100)   NULL,
        PaymentStatus       NVARCHAR(20)    NOT NULL,
        ReceivedByUserId    INT             NULL,
        Notes               NVARCHAR(500)   NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL,
        RowVer              ROWVERSION      NOT NULL
    );
END;
GO

IF OBJECT_ID(N'finance.PaymentAllocations', N'U') IS NULL
BEGIN
    CREATE TABLE finance.PaymentAllocations
    (
        PaymentAllocationId BIGINT          IDENTITY(1,1) NOT NULL,
        PaymentId           BIGINT          NOT NULL,
        InvoiceId           BIGINT          NOT NULL,
        AllocatedAmount     DECIMAL(19,4)   NOT NULL,
        CreatedAt           DATETIME2(3)    NOT NULL,
        CreatedBy           INT             NULL,
        UpdatedAt           DATETIME2(3)    NOT NULL,
        UpdatedBy           INT             NULL
    );
END;
GO

/* =============================================================================
   audit  (append-only logs; history tables of temporal tables are created
           in 05_constraints.sql when SYSTEM_VERSIONING is switched on)
   ============================================================================= */
-- OldValues/NewValues are NVARCHAR(MAX) by design: they hold JSON row images of
-- arbitrary width; ISJSON is enforced by CHECK constraints in 05.
IF OBJECT_ID(N'audit.AuditEvents', N'U') IS NULL
BEGIN
    CREATE TABLE audit.AuditEvents
    (
        AuditEventId        BIGINT          IDENTITY(1,1) NOT NULL,
        EventType           NVARCHAR(50)    NOT NULL,
        SchemaName          NVARCHAR(128)   NOT NULL,
        TableName           NVARCHAR(128)   NOT NULL,
        EntityKey           NVARCHAR(100)   NOT NULL,
        EventAction         NVARCHAR(10)    NOT NULL,
        OldValues           NVARCHAR(MAX)   NULL,
        NewValues           NVARCHAR(MAX)   NULL,
        ProcedureName       NVARCHAR(256)   NULL,
        UserAccountId       INT             NULL,
        HostName            NVARCHAR(128)   NULL,
        OccurredAt          DATETIME2(3)    NOT NULL
    );
END;
GO

IF OBJECT_ID(N'audit.SecurityEvents', N'U') IS NULL
BEGIN
    CREATE TABLE audit.SecurityEvents
    (
        SecurityEventId     BIGINT          IDENTITY(1,1) NOT NULL,
        EventType           NVARCHAR(30)    NOT NULL,
        UserAccountId       INT             NULL,
        UserNameAttempted   NVARCHAR(100)   NULL,
        IpAddress           NVARCHAR(45)    NULL,
        Details             NVARCHAR(1000)  NULL,
        OccurredAt          DATETIME2(3)    NOT NULL
    );
END;
GO
