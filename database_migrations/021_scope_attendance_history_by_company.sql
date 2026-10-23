/*
  SENADA - Riwayat Absensi multi-perusahaan

  Aturan akses:
  - Karyawan hanya dapat membaca riwayat dan detail miliknya sendiri.
  - HRD/Admin hanya dapat membaca riwayat, rekap, daftar karyawan, kantor,
    serta ekspor dari company_id akun mereka.
  - Tenant diturunkan dari udt_company_info_user, bukan company_name dari klien.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

/* Index mendukung list dan rekap per perusahaan tanpa menyimpan tenant ganda
   di tabel attendance; company_id berasal dari pemilik user. */
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_company_info_user')
      AND name = 'IX_company_info_user_company_userid_attendance'
)
    CREATE INDEX IX_company_info_user_company_userid_attendance
        ON dbo.udt_company_info_user(company_id, userid)
        INCLUDE(employeeID, organization, job_position, company_name);
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_attendance')
      AND name = 'IX_attendance_user_date_history'
)
    CREATE INDEX IX_attendance_user_date_history
        ON dbo.udt_attendance(user_id, attendance_date DESC, id DESC)
        INCLUDE(check_in_time, check_out_time, check_in_status, check_out_status,
                check_in_office_id, check_out_office_id, working_hours_minutes,
                overtime_minutes, created_at);
GO

/* Karyawan: caller dan pemilik data harus identik. */
CREATE OR ALTER PROCEDURE dbo.udp_attendance_get_history
    @user_id NVARCHAR(50),
    @start_date DATETIME = NULL,
    @end_date DATETIME = NULL,
    @status_filter NVARCHAR(20) = NULL,
    @time_range NVARCHAR(20) = NULL,
    @page INT = 1,
    @page_size INT = 1000,
    @request_user_id NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @request_user_id = ISNULL(NULLIF(LTRIM(RTRIM(@request_user_id)), ''), @user_id);
    IF @user_id IS NULL OR LTRIM(RTRIM(@user_id)) = '' OR @request_user_id <> @user_id
        THROW 52100, 'Riwayat absensi hanya dapat diakses oleh pemilik akun.', 1;

    DECLARE @company_id INT;
    SELECT @company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies co ON co.id = ci.company_id AND co.is_active = 1
    WHERE u.userid = @user_id AND u.active = 1 AND ISNULL(u.deleted, 0) = 0;
    IF @company_id IS NULL THROW 52101, 'Akun tidak aktif atau belum terhubung ke perusahaan.', 1;

    IF @page < 1 SET @page = 1;
    IF @page_size < 1 SET @page_size = 10;
    IF @page_size > 1000 SET @page_size = 1000;
    DECLARE @offset INT = (@page - 1) * @page_size;
    DECLARE @actual_start_date DATETIME, @actual_end_date DATETIME;

    IF @start_date IS NULL AND @end_date IS NULL AND @time_range IS NOT NULL
    BEGIN
        SET @actual_end_date = DATEADD(DAY, 1, CONVERT(DATE, GETDATE()));
        SET @actual_start_date = CASE @time_range
            WHEN '1 Hari' THEN CONVERT(DATE, GETDATE())
            WHEN '1_day' THEN CONVERT(DATE, GETDATE())
            WHEN '7 Hari Terakhir' THEN DATEADD(DAY, -7, CONVERT(DATE, GETDATE()))
            WHEN '7_days' THEN DATEADD(DAY, -7, CONVERT(DATE, GETDATE()))
            WHEN '30 Hari Terakhir' THEN DATEADD(DAY, -30, CONVERT(DATE, GETDATE()))
            WHEN '30_days' THEN DATEADD(DAY, -30, CONVERT(DATE, GETDATE()))
            ELSE DATEADD(YEAR, -1, CONVERT(DATE, GETDATE())) END;
    END
    ELSE
    BEGIN
        SET @actual_start_date = ISNULL(@start_date, DATEADD(YEAR, -1, CONVERT(DATE, GETDATE())));
        SET @actual_end_date = ISNULL(@end_date, DATEADD(DAY, 1, CONVERT(DATE, GETDATE())));
    END;

    SELECT a.* INTO #filtered
    FROM dbo.udt_attendance a
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=a.user_id AND ci.company_id=@company_id
    WHERE a.user_id=@user_id
      AND a.attendance_date>=@actual_start_date AND a.attendance_date<@actual_end_date
      AND (@status_filter IS NULL OR LTRIM(RTRIM(@status_filter))='' OR @status_filter='Semua'
           OR (@status_filter='Tepat Waktu' AND a.check_in_status IN ('on_time','early','Tepat Waktu'))
           OR (@status_filter='Terlambat' AND a.check_in_status IN ('late','very_late','Terlambat','Sangat Terlambat'))
           OR (@status_filter='Cuti' AND a.check_in_time IS NULL AND a.check_out_time IS NULL));
    SELECT a.id,a.user_id,a.attendance_date,a.check_in_time,a.check_out_time,
           ISNULL(a.check_in_status,'') check_in_status,ISNULL(a.check_out_status,'') check_out_status,
           ISNULL(oi.office_name,ISNULL(oo.office_name,'Tidak Diketahui')) office_name,
           ISNULL(a.notes,'') notes,ISNULL(a.working_hours_minutes,0) working_hours_minutes,
           ISNULL(a.overtime_minutes,0) overtime_minutes,a.check_in_face_confidence,
           a.check_out_face_confidence,a.created_at,a.updated_at
    FROM #filtered a
    LEFT JOIN dbo.udt_office_locations oi ON oi.id=a.check_in_office_id AND oi.company_id=@company_id
    LEFT JOIN dbo.udt_office_locations oo ON oo.id=a.check_out_office_id AND oo.company_id=@company_id
    ORDER BY a.attendance_date DESC,a.id DESC
    OFFSET @offset ROWS FETCH NEXT @page_size ROWS ONLY;

    SELECT COUNT(*) TotalCount FROM #filtered;
    SELECT ISNULL(SUM(CASE WHEN check_in_time IS NOT NULL OR check_out_time IS NOT NULL THEN 1 ELSE 0 END),0) MasukKantor,
           ISNULL(SUM(CASE WHEN check_in_status IN ('on_time','early','Tepat Waktu') THEN 1 ELSE 0 END),0) TepatWaktu,
           ISNULL(SUM(CASE WHEN check_in_status IN ('late','very_late','Terlambat','Sangat Terlambat') THEN 1 ELSE 0 END),0) Terlambat,
           ISNULL(SUM(CASE WHEN check_in_time IS NULL AND check_out_time IS NULL THEN 1 ELSE 0 END),0) CutiKaryawan
    FROM #filtered;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_attendance_get_detail
    @id INT,
    @user_id NVARCHAR(50),
    @request_user_id NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @request_user_id=ISNULL(NULLIF(LTRIM(RTRIM(@request_user_id)),''),@user_id);
    IF @request_user_id<>@user_id THROW 52102, 'Detail absensi hanya dapat diakses oleh pemilik akun.', 1;

    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL THROW 52103, 'Akun tidak aktif atau belum terhubung ke perusahaan.', 1;

    SELECT a.id,a.user_id,a.attendance_date,a.check_in_time,a.check_out_time,
           a.check_in_latitude,a.check_in_longitude,a.check_out_latitude,a.check_out_longitude,
           a.check_in_office_id,a.check_out_office_id,a.check_in_status,a.check_out_status,
           a.check_in_face_confidence,a.check_out_face_confidence,a.working_hours_minutes,
           a.overtime_minutes,a.notes,a.created_at,a.updated_at,
           ISNULL(oi.office_name,ISNULL(oo.office_name,'Tidak Diketahui')) office_name,
           oi.office_name check_in_office_name,oo.office_name check_out_office_name,
           oi.latitude check_in_office_latitude,oi.longitude check_in_office_longitude,
           oo.latitude check_out_office_latitude,oo.longitude check_out_office_longitude
    FROM dbo.udt_attendance a
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=a.user_id AND ci.company_id=@company_id
    LEFT JOIN dbo.udt_office_locations oi ON oi.id=a.check_in_office_id AND oi.company_id=@company_id
    LEFT JOIN dbo.udt_office_locations oo ON oo.id=a.check_out_office_id AND oo.company_id=@company_id
    WHERE a.id=@id AND a.user_id=@user_id;
END;
GO

/* Admin/HRD: ubah SP list eksisting, tetap mempertahankan seluruh result set
   dan kalkulasi Excel/dashboard, tetapi tenant sekarang company_id. */
DECLARE @AdminListDefinition NVARCHAR(MAX)=OBJECT_DEFINITION(OBJECT_ID('dbo.udp_admin_attendance_get_all'));
IF @AdminListDefinition IS NULL THROW 52104, 'SP udp_admin_attendance_get_all tidak ditemukan.', 1;

SET @AdminListDefinition=REPLACE(@AdminListDefinition,
    'CREATE PROCEDURE [dbo].[udp_admin_attendance_get_all]',
    'ALTER PROCEDURE [dbo].[udp_admin_attendance_get_all]');
SET @AdminListDefinition=REPLACE(@AdminListDefinition,
    'FROM dbo.udt_users
        WHERE userid = @admin_user_id
          AND role IN (''admin'', ''hrd'', ''Admin'', ''HRD'')
          AND active = 1
          AND deleted = 0',
    'FROM dbo.udt_users access_u
        INNER JOIN dbo.udt_company_info_user access_ci ON access_ci.userid = access_u.userid
        WHERE access_u.userid = @admin_user_id
          AND access_u.active = 1
          AND ISNULL(access_u.deleted, 0) = 0
          AND (UPPER(ISNULL(access_u.role, '''')) IN (''ADMIN'', ''HRD'')
               OR UPPER(ISNULL(access_ci.organization, '''')) LIKE ''%HRD%''
               OR UPPER(ISNULL(access_ci.organization, '''')) LIKE ''%DIREKTUR%''
               OR UPPER(ISNULL(access_ci.job_position, '''')) LIKE ''%DIREKTUR%'')');
SET @AdminListDefinition=REPLACE(@AdminListDefinition,
    'DECLARE @companyName NVARCHAR(200);', 'DECLARE @companyId INT;');
SET @AdminListDefinition=REPLACE(@AdminListDefinition,
    '@companyName = ci.company_name', '@companyId = ci.company_id');
SET @AdminListDefinition=REPLACE(@AdminListDefinition,
    '@companyName IS NULL', '@companyId IS NULL');
SET @AdminListDefinition=REPLACE(@AdminListDefinition,
    'ciu.company_name = @companyName', 'ciu.company_id = @companyId');
SET @AdminListDefinition=REPLACE(@AdminListDefinition,
    'ON a.check_in_office_id  = oi.id', 'ON a.check_in_office_id  = oi.id AND oi.company_id = @companyId');
SET @AdminListDefinition=REPLACE(@AdminListDefinition,
    'ON a.check_out_office_id = oo.id', 'ON a.check_out_office_id = oo.id AND oo.company_id = @companyId');

IF @AdminListDefinition LIKE '%@companyName%'
    THROW 52105, 'Migrasi list absensi gagal mengganti company_name.', 1;
EXEC sys.sp_executesql @AdminListDefinition;
GO

CREATE OR ALTER PROCEDURE dbo.udp_admin_get_employees
    @admin_user_id NVARCHAR(50),
    @search_term NVARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT TOP(1) @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@admin_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(ISNULL(u.role,'')) IN('ADMIN','HRD') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%');
    IF @company_id IS NULL THROW 52106, 'Akses riwayat absensi tidak diizinkan.', 1;

    SELECT u.userid,u.name,ci.employeeID employee_id,ci.organization department,
           ci.job_position position,u.mail,u.phone,u.active
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci
      ON ci.userid=u.userid AND ci.company_id=@company_id
    WHERE ISNULL(u.deleted,0)=0
      AND (@search_term IS NULL OR u.name LIKE '%'+@search_term+'%'
           OR ci.employeeID LIKE '%'+@search_term+'%' OR ci.organization LIKE '%'+@search_term+'%')
    ORDER BY u.name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_admin_get_offices
    @admin_user_id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT TOP(1) @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@admin_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(ISNULL(u.role,'')) IN('ADMIN','HRD') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%');
    IF @company_id IS NULL THROW 52107, 'Akses lokasi kantor tidak diizinkan.', 1;

    SELECT id,office_name,latitude,longitude,radius_meters,is_active,created_at,
           CASE WHEN is_active=1 THEN 'Aktif' ELSE 'Tidak Aktif' END status_text
    FROM dbo.udt_office_locations
    WHERE company_id=@company_id AND is_active=1
    ORDER BY office_name;
END;
GO

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
      AND NOT EXISTS(SELECT 1 FROM dbo.udt_attendance a
                     WHERE a.user_id=u.userid AND a.attendance_date=@tanggal)
    ORDER BY u.name;
END;
GO

SELECT p.name,p.modify_date
FROM sys.procedures p
WHERE p.name IN ('udp_attendance_get_history','udp_attendance_get_detail',
                 'udp_admin_attendance_get_all','udp_admin_get_employees',
                 'udp_admin_get_offices','udp_attendance_get_belum_absen_for_notify')
ORDER BY p.name;
GO
