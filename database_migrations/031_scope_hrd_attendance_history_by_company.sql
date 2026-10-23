/*
  SENADA - Penguncian Riwayat Absensi HRD per perusahaan

  Menutup jalur riwayat absensi HRD lama yang masih memakai company_name.
  Seluruh list, detail, edit, dan log harus memakai company_id yang berasal
  dari akun HRD aktif. Jadwal kerja kustom yang dipakai halaman riwayat juga
  hanya dikembalikan untuk perusahaan HRD peminta.

  Jalankan setelah 023_scope_attendance_rows_by_company.sql.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

/* Jadwal kerja kustom dipakai untuk kalkulasi Belum Absen/Tidak Hadir HRD. */
IF COL_LENGTH('dbo.udt_employee_workdays', 'company_id') IS NULL
    ALTER TABLE dbo.udt_employee_workdays ADD company_id INT NULL;
GO

UPDATE w
SET company_id = ci.company_id
FROM dbo.udt_employee_workdays w
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = w.userid
WHERE w.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_employee_workdays WHERE company_id IS NULL)
    THROW 53100, 'Masih ada jadwal kerja kustom tanpa perusahaan.', 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_employee_workdays_company')
    ALTER TABLE dbo.udt_employee_workdays WITH CHECK
        ADD CONSTRAINT FK_employee_workdays_company
        FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_employee_workdays')
      AND name = 'IX_employee_workdays_company_user'
)
    CREATE INDEX IX_employee_workdays_company_user
        ON dbo.udt_employee_workdays(company_id, userid);
GO

CREATE OR ALTER TRIGGER dbo.trg_employee_workdays_company_guard
ON dbo.udt_employee_workdays
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE w
    SET company_id = ci.company_id
    FROM dbo.udt_employee_workdays w
    INNER JOIN inserted i ON i.userid = w.userid
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = w.userid
    WHERE w.company_id IS NULL;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user ci ON ci.userid = i.userid
        LEFT JOIN dbo.udt_employee_workdays w ON w.userid = i.userid
        WHERE ci.company_id IS NULL OR w.company_id <> ci.company_id
    )
        THROW 53101, 'Perusahaan jadwal kerja tidak sesuai dengan karyawan.', 1;
END;
GO

/* Hanya HRD/Admin/Direktur aktif dari PT tersebut yang dapat membaca semua jadwal. */
CREATE OR ALTER PROCEDURE dbo.udp_employee_workdays_get_all
    @hrd_userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company_id INT;
    SELECT TOP (1) @company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
    WHERE u.userid = @hrd_userid
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0
      AND
      (
          UPPER(ISNULL(u.role, '')) IN ('ADMIN', 'HRD')
          OR UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%'
          OR UPPER(ISNULL(ci.organization, '')) LIKE '%DIREKTUR%'
          OR UPPER(ISNULL(ci.job_position, '')) LIKE '%DIREKTUR%'
      );

    IF @company_id IS NULL
        THROW 53102, 'Akses jadwal kerja karyawan tidak diizinkan.', 1;

    SELECT userid, work_days
    FROM dbo.udt_employee_workdays
    WHERE company_id = @company_id;
END;
GO

/*
  Prosedur endpoint api/hrd/attendance sebelumnya dibuat sebelum multi-PT
  dan memakai company_name. Pertahankan bentuk result-set API lama, tetapi
  ubah semua pembatas tenant ke company_id yang tersimpan di absensi.
*/
DECLARE @HrdList NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.udp_hrd_attendance_list'));
IF @HrdList IS NULL THROW 53103, 'SP udp_hrd_attendance_list tidak ditemukan.', 1;

IF UPPER(@HrdList) LIKE '%CREATE%PROCEDURE%'
BEGIN
    DECLARE @HrdListCreatePos INT = CHARINDEX('CREATE', UPPER(@HrdList));
    SET @HrdList = STUFF(@HrdList, @HrdListCreatePos, 6, 'ALTER');
END;
SET @HrdList = REPLACE(@HrdList, 'DECLARE @companyName NVARCHAR(200);', 'DECLARE @companyId INT;');
SET @HrdList = REPLACE(@HrdList, '@companyName = ci.company_name', '@companyId = ci.company_id');
SET @HrdList = REPLACE(@HrdList, '@companyName IS NULL', '@companyId IS NULL');
SET @HrdList = REPLACE(@HrdList, 'ci.company_name = @companyName', 'ci.company_id = @companyId');
SET @HrdList = REPLACE(@HrdList, 'ci.company_name=@companyName', 'ci.company_id=@companyId');
/* BaseData memakai alias a; ActiveUsers tidak. Tambahkan filter hanya pada BaseData. */
SET @HrdList = REPLACE
(
    @HrdList,
    'WHERE ci.company_id = @companyId' + CHAR(10) + '          AND u.deleted = 0',
    'WHERE ci.company_id = @companyId' + CHAR(10) + '          AND a.company_id = @companyId' + CHAR(10) + '          AND u.deleted = 0'
);
SET @HrdList = REPLACE(@HrdList, 'WHERE c.tanggal = a.attendance_date', 'WHERE c.company_id = @companyId AND c.tanggal = a.attendance_date');
SET @HrdList = REPLACE(@HrdList, 'WHERE c.tanggal = d.tanggal', 'WHERE c.company_id = @companyId AND c.tanggal = d.tanggal');
SET @HrdList = REPLACE(@HrdList, 'WHERE a.user_id = au.userid' + CHAR(13) + CHAR(10) + '                  AND a.attendance_date = d.tanggal', 'WHERE a.user_id = au.userid' + CHAR(13) + CHAR(10) + '                  AND a.company_id = @companyId' + CHAR(13) + CHAR(10) + '                  AND a.attendance_date = d.tanggal');

IF @HrdList LIKE '%companyName%' OR @HrdList NOT LIKE '%a.company_id = @companyId%'
    THROW 53104, 'Migrasi list riwayat HRD gagal mengunci company_id.', 1;
EXEC sys.sp_executesql @HrdList;
GO

DECLARE @HrdDetail NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.udp_hrd_attendance_detail'));
IF @HrdDetail IS NULL THROW 53105, 'SP udp_hrd_attendance_detail tidak ditemukan.', 1;
IF UPPER(@HrdDetail) LIKE '%CREATE%PROCEDURE%'
BEGIN
    DECLARE @HrdDetailCreatePos INT = CHARINDEX('CREATE', UPPER(@HrdDetail));
    SET @HrdDetail = STUFF(@HrdDetail, @HrdDetailCreatePos, 6, 'ALTER');
END;
SET @HrdDetail = REPLACE(@HrdDetail, 'DECLARE @companyName NVARCHAR(200);', 'DECLARE @companyId INT;');
SET @HrdDetail = REPLACE(@HrdDetail, '@companyName = ci.company_name', '@companyId = ci.company_id');
SET @HrdDetail = REPLACE(@HrdDetail, '@companyName IS NULL', '@companyId IS NULL');
SET @HrdDetail = REPLACE(@HrdDetail, 'ci.company_name = @companyName', 'ci.company_id = @companyId');
SET @HrdDetail = REPLACE(@HrdDetail, 'ci.company_name=@companyName', 'ci.company_id=@companyId');
SET @HrdDetail = REPLACE(@HrdDetail, 'AND  ci.company_id = @companyId', 'AND  a.company_id = @companyId' + CHAR(10) + '      AND  ci.company_id = @companyId');
IF @HrdDetail LIKE '%companyName%' OR @HrdDetail NOT LIKE '%a.company_id = @companyId%'
    THROW 53106, 'Migrasi detail riwayat HRD gagal mengunci company_id.', 1;
EXEC sys.sp_executesql @HrdDetail;
GO

DECLARE @HrdEdit NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.udp_hrd_attendance_edit'));
IF @HrdEdit IS NULL THROW 53107, 'SP udp_hrd_attendance_edit tidak ditemukan.', 1;
IF UPPER(@HrdEdit) LIKE '%CREATE%PROCEDURE%'
BEGIN
    DECLARE @HrdEditCreatePos INT = CHARINDEX('CREATE', UPPER(@HrdEdit));
    SET @HrdEdit = STUFF(@HrdEdit, @HrdEditCreatePos, 6, 'ALTER');
END;
SET @HrdEdit = REPLACE(@HrdEdit, 'DECLARE @companyName NVARCHAR(200);', 'DECLARE @companyId INT;');
SET @HrdEdit = REPLACE(@HrdEdit, '@companyName = ci.company_name', '@companyId = ci.company_id');
SET @HrdEdit = REPLACE(@HrdEdit, '@companyName IS NULL', '@companyId IS NULL');
SET @HrdEdit = REPLACE(@HrdEdit, 'ci.company_name = @companyName', 'ci.company_id = @companyId');
SET @HrdEdit = REPLACE(@HrdEdit, 'ci.company_name=@companyName', 'ci.company_id=@companyId');
SET @HrdEdit = REPLACE(@HrdEdit, 'AND  ci.company_id = @companyId', 'AND  a.company_id = @companyId' + CHAR(10) + '          AND  ci.company_id = @companyId');
IF @HrdEdit LIKE '%companyName%' OR @HrdEdit NOT LIKE '%a.company_id = @companyId%'
    THROW 53108, 'Migrasi edit riwayat HRD gagal mengunci company_id.', 1;
EXEC sys.sp_executesql @HrdEdit;
GO

DECLARE @HrdLog NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.udp_hrd_attendance_edit_log'));
IF @HrdLog IS NULL THROW 53109, 'SP udp_hrd_attendance_edit_log tidak ditemukan.', 1;
IF UPPER(@HrdLog) LIKE '%CREATE%PROCEDURE%'
BEGIN
    DECLARE @HrdLogCreatePos INT = CHARINDEX('CREATE', UPPER(@HrdLog));
    SET @HrdLog = STUFF(@HrdLog, @HrdLogCreatePos, 6, 'ALTER');
END;
SET @HrdLog = REPLACE(@HrdLog, 'DECLARE @companyName NVARCHAR(200);', 'DECLARE @companyId INT;');
SET @HrdLog = REPLACE(@HrdLog, '@companyName = ci.company_name', '@companyId = ci.company_id');
SET @HrdLog = REPLACE(@HrdLog, '@companyName IS NULL', '@companyId IS NULL');
SET @HrdLog = REPLACE(@HrdLog, 'ci.company_name = @companyName', 'ci.company_id = @companyId');
SET @HrdLog = REPLACE(@HrdLog, 'ci.company_name=@companyName', 'ci.company_id=@companyId');
SET @HrdLog = REPLACE(@HrdLog, 'WHERE  ci.company_id = @companyId', 'WHERE  a.company_id = @companyId AND ci.company_id = @companyId');
IF @HrdLog LIKE '%companyName%' OR @HrdLog NOT LIKE '%a.company_id = @companyId%'
    THROW 53110, 'Migrasi log riwayat HRD gagal mengunci company_id.', 1;
EXEC sys.sp_executesql @HrdLog;
GO

/* Verifikasi seluruh jalur HRD. */
SELECT p.name, p.modify_date
FROM sys.procedures p
WHERE p.name IN
(
    'udp_hrd_attendance_list', 'udp_hrd_attendance_detail',
    'udp_hrd_attendance_edit', 'udp_hrd_attendance_edit_log',
    'udp_employee_workdays_get_all'
)
ORDER BY p.name;
GO
