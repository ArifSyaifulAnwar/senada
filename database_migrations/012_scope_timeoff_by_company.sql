/*
  SENADA - Isolasi izin / time off per perusahaan

  Jalankan pada ABSENSI sesudah 008_fix_dl_approval_finance.sql.
  Tenant selalu diturunkan dari udt_company_info_user, bukan dari Flutter.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

/* 1. Transaksi izin menyimpan tenant pemilik. */
IF COL_LENGTH('dbo.udt_timeoff', 'company_id') IS NULL
    ALTER TABLE dbo.udt_timeoff ADD company_id INT NULL;
GO

UPDATE t
SET t.company_id = ci.company_id
FROM dbo.udt_timeoff t
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = t.userid
WHERE t.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_timeoff WHERE company_id IS NULL)
    THROW 51200, 'Masih ada izin tanpa company_id. Perbaiki mapping user terlebih dahulu.', 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_timeoff_company')
    ALTER TABLE dbo.udt_timeoff WITH CHECK ADD CONSTRAINT FK_timeoff_company
        FOREIGN KEY (company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.udt_timeoff') AND name = 'IX_timeoff_company_status_date')
    CREATE INDEX IX_timeoff_company_status_date
        ON dbo.udt_timeoff(company_id, status, tanggal_mulai)
        INCLUDE(userid, jenis_timeoff, tanggal_selesai, total_hari);
GO

/* 2. Konfigurasi HR dibuat per PT. Data lama dianggap milik PT yang paling
      banyak memiliki user aktif (pada data awal SENADA: PT SDB). */
IF COL_LENGTH('dbo.udt_timeoff_policy', 'company_id') IS NULL
    ALTER TABLE dbo.udt_timeoff_policy ADD company_id INT NULL;
GO
IF COL_LENGTH('dbo.udt_timeoff_types', 'company_id') IS NULL
    ALTER TABLE dbo.udt_timeoff_types ADD company_id INT NULL;
GO
IF COL_LENGTH('dbo.udt_work_period', 'company_id') IS NULL
    ALTER TABLE dbo.udt_work_period ADD company_id INT NULL;
GO

DECLARE @LegacyCompanyId INT;
SELECT TOP (1) @LegacyCompanyId = ci.company_id
FROM dbo.udt_company_info_user ci
INNER JOIN dbo.udt_users u ON u.userid = ci.userid
WHERE ci.company_id IS NOT NULL AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
GROUP BY ci.company_id
ORDER BY COUNT(*) DESC, ci.company_id;

IF @LegacyCompanyId IS NULL
    THROW 51201, 'Perusahaan utama tidak ditemukan.', 1;

UPDATE dbo.udt_timeoff_policy SET company_id = @LegacyCompanyId WHERE company_id IS NULL;
UPDATE dbo.udt_timeoff_types  SET company_id = @LegacyCompanyId WHERE company_id IS NULL;
UPDATE dbo.udt_work_period    SET company_id = @LegacyCompanyId WHERE company_id IS NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_timeoff_policy_company')
    ALTER TABLE dbo.udt_timeoff_policy WITH CHECK ADD CONSTRAINT FK_timeoff_policy_company
        FOREIGN KEY (company_id) REFERENCES dbo.udt_companies(id);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_timeoff_types_company')
    ALTER TABLE dbo.udt_timeoff_types WITH CHECK ADD CONSTRAINT FK_timeoff_types_company
        FOREIGN KEY (company_id) REFERENCES dbo.udt_companies(id);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_work_period_company')
    ALTER TABLE dbo.udt_work_period WITH CHECK ADD CONSTRAINT FK_work_period_company
        FOREIGN KEY (company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.udt_timeoff_policy') AND name = 'IX_timeoff_policy_company_type')
    CREATE INDEX IX_timeoff_policy_company_type
        ON dbo.udt_timeoff_policy(company_id, jenis_timeoff, is_active);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.udt_timeoff_types') AND name = 'IX_timeoff_types_company')
    CREATE INDEX IX_timeoff_types_company ON dbo.udt_timeoff_types(company_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.udt_work_period') AND name = 'IX_work_period_company_period')
    CREATE INDEX IX_work_period_company_period
        ON dbo.udt_work_period(company_id, tahun, bulan);
GO

/* SP submit dari migration 008 sudah memperoleh @companyId dari pemilik.
   Tambahkan filter tenant pada pemilihan policy tanpa mengubah signature API. */
DECLARE @SubmitDefinition NVARCHAR(MAX) =
    OBJECT_DEFINITION(OBJECT_ID('dbo.udp_timeoff_submit_with_policy'));
DECLARE @OldPolicyPredicate NVARCHAR(300) =
    N'WHERE jenis_timeoff = @jenisTimeoff AND is_active = 1;';
DECLARE @NewPolicyPredicate NVARCHAR(300) =
    N'WHERE jenis_timeoff = @jenisTimeoff AND company_id = @companyId AND is_active = 1;';

IF @SubmitDefinition IS NULL
    THROW 51206, 'SP udp_timeoff_submit_with_policy tidak ditemukan. Jalankan migration 008 dahulu.', 1;

IF CHARINDEX(@NewPolicyPredicate, @SubmitDefinition) = 0
BEGIN
    IF CHARINDEX(@OldPolicyPredicate, @SubmitDefinition) = 0
        THROW 51207, 'Blok policy pada udp_timeoff_submit_with_policy tidak dikenali.', 1;

    SET @SubmitDefinition = REPLACE(
        @SubmitDefinition,
        @OldPolicyPredicate,
        @NewPolicyPredicate
    );
    EXEC sys.sp_executesql @SubmitDefinition;
END;
GO

/* 3. Semua insert/update legacy dipaksa mengikuti perusahaan pemilik.
      Approver dan Finance lintas PT ditolak. */
CREATE OR ALTER TRIGGER dbo.trg_timeoff_company_guard
ON dbo.udt_timeoff
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user owner_ci ON owner_ci.userid = i.userid
        WHERE owner_ci.company_id IS NULL
    )
        THROW 51202, 'Pemilik izin belum memiliki perusahaan resmi.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.udt_company_info_user owner_ci ON owner_ci.userid = i.userid
        CROSS APPLY
        (
            SELECT i.manager_userid actor_id WHERE i.manager_userid IS NOT NULL
            UNION ALL SELECT i.finance_userid WHERE i.finance_userid IS NOT NULL
            UNION ALL SELECT i.hrd_approved_by WHERE i.hrd_approved_by IS NOT NULL
            UNION ALL SELECT i.director_approved_by WHERE i.director_approved_by IS NOT NULL
        ) actor
        LEFT JOIN dbo.udt_company_info_user actor_ci ON actor_ci.userid = actor.actor_id
        WHERE actor_ci.company_id IS NULL OR actor_ci.company_id <> owner_ci.company_id
    )
        THROW 51203, 'Approver izin harus berasal dari perusahaan yang sama.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.udt_company_info_user owner_ci ON owner_ci.userid = i.userid
        LEFT JOIN dbo.udt_timeoff_policy p
            ON p.policy_code = i.policy_code
           AND p.company_id = owner_ci.company_id
        WHERE i.policy_code IS NOT NULL
          AND p.id IS NULL
    )
        THROW 51205, 'Kebijakan izin tidak berasal dari perusahaan pemilik.', 1;

    UPDATE t
    SET company_id = owner_ci.company_id
    FROM dbo.udt_timeoff t
    INNER JOIN inserted i ON i.id = t.id
    INNER JOIN dbo.udt_company_info_user owner_ci ON owner_ci.userid = i.userid
    WHERE t.company_id IS NULL OR t.company_id <> owner_ci.company_id;
END;
GO

/* 4. Statistik dashboard HRD/Admin hanya satu PT. */
CREATE OR ALTER PROCEDURE dbo.udp_timeoff_admin_statistics
    @viewer_user_id VARCHAR(50),
    @year INT = NULL,
    @month INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company_id INT;
    SELECT TOP (1) @company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    WHERE u.userid = @viewer_user_id
      AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
      AND (
          UPPER(LTRIM(RTRIM(ISNULL(u.role, '')))) IN ('HRD', 'ADMIN')
          OR UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%'
          OR UPPER(ISNULL(ci.job_position, '')) LIKE '%DIREKTUR%'
      );

    IF @company_id IS NULL
        THROW 51204, 'Viewer tidak berwenang atau belum memiliki perusahaan.', 1;

    SELECT
        COUNT(1) AS totalSubmissions,
        ISNULL(SUM(CASE WHEN status LIKE 'Pending%' OR status IN ('Menunggu Org','Menunggu Laporan','Menunggu Transfer','Revisi') THEN 1 ELSE 0 END),0) AS pendingCount,
        ISNULL(SUM(CASE WHEN status = 'Approved' THEN 1 ELSE 0 END),0) AS approvedCount,
        ISNULL(SUM(CASE WHEN status = 'Rejected' THEN 1 ELSE 0 END),0) AS rejectedCount,
        ISNULL(SUM(CASE WHEN status IN ('Processed','Selesai') THEN 1 ELSE 0 END),0) AS processedCount,
        ISNULL(SUM(CASE WHEN status LIKE 'Pending%' OR status IN ('Menunggu Org','Menunggu Laporan','Menunggu Transfer','Revisi') THEN total_hari ELSE 0 END),0) AS totalPendingDays,
        ISNULL(SUM(CASE WHEN status = 'Approved' THEN total_hari ELSE 0 END),0) AS totalApprovedDays,
        ISNULL(SUM(CASE WHEN status IN ('Processed','Selesai') THEN total_hari ELSE 0 END),0) AS totalProcessedDays,
        CAST(ISNULL(SUM(CASE WHEN status LIKE 'Pending%' OR status IN ('Menunggu Org','Menunggu Laporan','Menunggu Transfer','Revisi') THEN total_hari ELSE 0 END),0) AS VARCHAR(20)) + ' hari' AS formattedTotalPending,
        CAST(ISNULL(SUM(CASE WHEN status = 'Approved' THEN total_hari ELSE 0 END),0) AS VARCHAR(20)) + ' hari' AS formattedTotalApproved,
        CAST(ISNULL(SUM(CASE WHEN status IN ('Processed','Selesai') THEN total_hari ELSE 0 END),0) AS VARCHAR(20)) + ' hari' AS formattedTotalProcessed
    FROM dbo.udt_timeoff
    WHERE company_id = @company_id
      AND (@year IS NULL OR YEAR(tanggal_mulai) = @year)
      AND (@month IS NULL OR MONTH(tanggal_mulai) = @month);
END;
GO

/* 5. Kebijakan izin dikembalikan sesuai PT user. */
CREATE OR ALTER PROCEDURE dbo.udp_timeoff_policy_get_active
    @user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id = company_id
    FROM dbo.udt_company_info_user
    WHERE userid = @user_id;

    SELECT id, policy_code, jenis_timeoff, uses_quota, quota_type,
           requires_director_approval, notes
    FROM dbo.udt_timeoff_policy
    WHERE company_id = @company_id AND is_active = 1
    ORDER BY jenis_timeoff;
END;
GO

/* Verifikasi tenant dan objek. */
SELECT company_id, COUNT(*) total_timeoff
FROM dbo.udt_timeoff
GROUP BY company_id
ORDER BY company_id;

SELECT name, modify_date
FROM sys.procedures
WHERE name IN ('udp_timeoff_admin_statistics','udp_timeoff_policy_get_active')
ORDER BY name;
GO
