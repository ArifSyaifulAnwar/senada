/*
  SENADA - Tenant permanen pada baris absensi

  Mengunci setiap histori absensi ke company_id saat absensi terjadi.
  company_id tetap nullable di schema untuk kompatibilitas procedure legacy
  yang belum menyertakan kolom saat INSERT; trigger di bawah langsung mengisi
  nilainya dari pemilik user dan menolak nilai tenant yang tidak sesuai.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.udt_attendance', 'company_id') IS NULL
    ALTER TABLE dbo.udt_attendance ADD company_id INT NULL;
GO

/* Backfill historis menggunakan perusahaan pemilik akun saat migrasi. */
UPDATE a
SET company_id = ci.company_id
FROM dbo.udt_attendance a
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = a.user_id
WHERE a.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_attendance WHERE company_id IS NULL)
    THROW 52300, 'Masih ada absensi tanpa company_id. Perbaiki mapping user terlebih dahulu.', 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_attendance_company')
    ALTER TABLE dbo.udt_attendance WITH CHECK
    ADD CONSTRAINT FK_attendance_company
        FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_attendance')
      AND name = 'IX_attendance_company_date_user'
)
    CREATE INDEX IX_attendance_company_date_user
        ON dbo.udt_attendance(company_id, attendance_date DESC, user_id)
        INCLUDE(check_in_time, check_out_time, check_in_status, check_out_status,
                check_in_office_id, check_out_office_id, working_hours_minutes,
                overtime_minutes, created_at);
GO

/*
  Baris baru dari SP lama boleh tidak mengirim company_id; trigger mengisi
  dari user_id. Penggantian user atau company pada histori yang sudah ada
  dilarang supaya absensi tidak dapat pindah tenant.
*/
CREATE OR ALTER TRIGGER dbo.trg_attendance_company_guard
ON dbo.udt_attendance
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON d.id = i.id
        WHERE i.user_id <> d.user_id
           OR (i.company_id IS NOT NULL AND i.company_id <> d.company_id)
    )
        THROW 52301, 'User atau perusahaan pada histori absensi tidak boleh diubah.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user ci ON ci.userid = i.user_id
        WHERE ci.company_id IS NULL
    )
        THROW 52302, 'Pemilik absensi belum memiliki perusahaan resmi.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.udt_company_info_user ci ON ci.userid = i.user_id
        WHERE i.company_id IS NOT NULL
          AND i.company_id <> ci.company_id
          AND NOT EXISTS (SELECT 1 FROM deleted d WHERE d.id = i.id)
    )
        THROW 52303, 'Perusahaan absensi tidak sesuai dengan pemilik akun.', 1;

    UPDATE a
    SET company_id = ci.company_id
    FROM dbo.udt_attendance a
    INNER JOIN inserted i ON i.id = a.id
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = i.user_id
    WHERE a.company_id IS NULL;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.udt_attendance a ON a.id = i.id
        WHERE a.company_id IS NULL
    )
        THROW 52304, 'Company absensi gagal ditentukan.', 1;
END;
GO

/* Riwayat personal dan detail memakai tenant yang tersimpan pada absensi. */
DECLARE @HistoryDefinition NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.udp_attendance_get_history'));
IF @HistoryDefinition IS NULL THROW 52305, 'SP udp_attendance_get_history tidak ditemukan.', 1;
SET @HistoryDefinition = REPLACE(@HistoryDefinition, 'CREATE PROCEDURE [dbo].[udp_attendance_get_history]', 'ALTER PROCEDURE [dbo].[udp_attendance_get_history]');
IF UPPER(@HistoryDefinition) LIKE '%CREATE%PROCEDURE%'
BEGIN
    DECLARE @HistoryCreatePos INT = CHARINDEX('CREATE', UPPER(@HistoryDefinition));
    SET @HistoryDefinition = STUFF(@HistoryDefinition, @HistoryCreatePos, 6, 'ALTER');
END;
SET @HistoryDefinition = REPLACE(@HistoryDefinition,
    'WHERE a.user_id=@user_id',
    'WHERE a.user_id=@user_id AND a.company_id=@company_id');
IF @HistoryDefinition NOT LIKE '%a.company_id=@company_id%'
    THROW 52306, 'Migrasi riwayat absensi gagal menambahkan company_id.', 1;
EXEC sys.sp_executesql @HistoryDefinition;
GO

DECLARE @DetailDefinition NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.udp_attendance_get_detail'));
IF @DetailDefinition IS NULL THROW 52307, 'SP udp_attendance_get_detail tidak ditemukan.', 1;
SET @DetailDefinition = REPLACE(@DetailDefinition, 'CREATE PROCEDURE [dbo].[udp_attendance_get_detail]', 'ALTER PROCEDURE [dbo].[udp_attendance_get_detail]');
IF UPPER(@DetailDefinition) LIKE '%CREATE%PROCEDURE%'
BEGIN
    DECLARE @DetailCreatePos INT = CHARINDEX('CREATE', UPPER(@DetailDefinition));
    SET @DetailDefinition = STUFF(@DetailDefinition, @DetailCreatePos, 6, 'ALTER');
END;
SET @DetailDefinition = REPLACE(@DetailDefinition,
    'WHERE a.id=@id AND a.user_id=@user_id;',
    'WHERE a.id=@id AND a.user_id=@user_id AND a.company_id=@company_id;');
IF @DetailDefinition NOT LIKE '%a.company_id=@company_id%'
    THROW 52308, 'Migrasi detail absensi gagal menambahkan company_id.', 1;
EXEC sys.sp_executesql @DetailDefinition;
GO

/* Dashboard/list HRD/Admin: semua result set hanya membaca baris tenantnya. */
DECLARE @AdminDefinition NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.udp_admin_attendance_get_all'));
IF @AdminDefinition IS NULL THROW 52309, 'SP udp_admin_attendance_get_all tidak ditemukan.', 1;
SET @AdminDefinition = REPLACE(@AdminDefinition, 'CREATE PROCEDURE [dbo].[udp_admin_attendance_get_all]', 'ALTER PROCEDURE [dbo].[udp_admin_attendance_get_all]');
IF UPPER(@AdminDefinition) LIKE '%CREATE%PROCEDURE%'
BEGIN
    DECLARE @AdminCreatePos INT = CHARINDEX('CREATE', UPPER(@AdminDefinition));
    SET @AdminDefinition = STUFF(@AdminDefinition, @AdminCreatePos, 6, 'ALTER');
END;
SET @AdminDefinition = REPLACE(@AdminDefinition,
    'WHERE 1 = 1',
    'WHERE a.company_id = @companyId' + CHAR(13) + CHAR(10) + '        AND 1 = 1');
SET @AdminDefinition = REPLACE(@AdminDefinition,
    'WHERE CAST(a.attendance_date AS DATE) = @summary_date',
    'WHERE a.company_id = @companyId' + CHAR(13) + CHAR(10) + '          AND CAST(a.attendance_date AS DATE) = @summary_date');
IF @AdminDefinition NOT LIKE '%a.company_id = @companyId%'
    THROW 52310, 'Migrasi list absensi gagal menambahkan company_id.', 1;
EXEC sys.sp_executesql @AdminDefinition;
GO

/* Notifikasi belum absen hanya menganggap absensi dari perusahaan yang sama. */
CREATE OR ALTER PROCEDURE dbo.udp_attendance_get_belum_absen_for_notify
    @admin_user_id VARCHAR(50),
    @tanggal DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT TOP(1) @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@admin_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(ISNULL(u.role,'')) IN('ADMIN','HRD') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%');

    SELECT u.userid,u.name,u.phone,ISNULL(ci.organization,'-') department
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci
      ON ci.userid=u.userid AND ci.company_id=@company_id
    WHERE @company_id IS NOT NULL AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND ISNULL(u.phone,'')<>''
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.udt_attendance a
          WHERE a.user_id=u.userid
            AND a.company_id=@company_id
            AND a.attendance_date=@tanggal
      )
    ORDER BY u.name;
END;
GO

/* Verifikasi hasil deploy. */
SELECT company_id, COUNT(*) total_absensi
FROM dbo.udt_attendance
GROUP BY company_id
ORDER BY company_id;

SELECT name,modify_date
FROM sys.procedures
WHERE name IN ('udp_attendance_get_history','udp_attendance_get_detail',
               'udp_admin_attendance_get_all','udp_attendance_get_belum_absen_for_notify')
ORDER BY name;
GO
