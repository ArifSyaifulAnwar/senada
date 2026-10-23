/*
  SENADA - Filter periode aktivitas harian

  Aktivitas tetap dibatasi company_id pemilik akun. Parameter tanggal hanya
  mempersempit data yang sudah berhak dibaca, baik untuk user maupun HRD.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetDailyActivitiesByUser
    @UserId VARCHAR(50),
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartDate IS NOT NULL AND @EndDate IS NOT NULL AND @StartDate > @EndDate
        THROW 53900, 'Tanggal awal tidak boleh melebihi tanggal akhir.', 1;

    DECLARE @company_id INT;
    SELECT @company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    WHERE u.userid = @UserId AND u.active = 1 AND ISNULL(u.deleted, 0) = 0;

    IF @company_id IS NULL
        THROW 53901, 'User tidak aktif atau belum terhubung ke perusahaan.', 1;

    SELECT a.id,a.activity_date,a.description,a.category_id,c.category_key,
           c.label category_label,c.icon_name,a.office_location_id,ol.office_name,
           a.location_text,a.start_time,a.end_time,a.status,a.review_notes,a.created_at
    FROM dbo.udt_daily_activity a
    INNER JOIN dbo.udt_daily_activity_category c ON c.id=a.category_id
    LEFT JOIN dbo.udt_office_locations ol ON ol.id=a.office_location_id AND ol.company_id=a.company_id
    WHERE a.userid=@UserId AND a.company_id=@company_id
      AND (@StartDate IS NULL OR a.activity_date >= @StartDate)
      AND (@EndDate IS NULL OR a.activity_date <= @EndDate)
    ORDER BY a.activity_date DESC,a.created_at DESC;

    SELECT att.id,att.activity_id,att.name,att.filetype,att.uploaded_at
    FROM dbo.udt_daily_activity_attachment att
    INNER JOIN dbo.udt_daily_activity a ON a.id=att.activity_id
    WHERE a.userid=@UserId AND a.company_id=@company_id
      AND (@StartDate IS NULL OR a.activity_date >= @StartDate)
      AND (@EndDate IS NULL OR a.activity_date <= @EndDate)
    ORDER BY att.uploaded_at;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetAllDailyActivitiesByCompany_HRD
    @RequestUserId VARCHAR(50),
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @AccessDenied BIT OUTPUT,
    @Message VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @AccessDenied = 0;
    SET @Message = NULL;

    IF @StartDate IS NOT NULL AND @EndDate IS NOT NULL AND @StartDate > @EndDate
        THROW 53902, 'Tanggal awal tidak boleh melebihi tanggal akhir.', 1;

    DECLARE @company_id INT,@has_access BIT=0;
    SELECT TOP(1) @company_id=ci.company_id,
      @has_access=CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(u.role,'')))) IN('HRD','ADMIN')
        OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
        OR UPPER(ISNULL(ci.organization,'')) LIKE '%DIREKTUR%'
        OR UPPER(ISNULL(ci.job_position,'')) LIKE '%DIREKTUR%' THEN 1 ELSE 0 END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    INNER JOIN dbo.udt_companies co ON co.id=ci.company_id AND co.is_active=1
    WHERE u.userid=@RequestUserId AND u.active=1 AND ISNULL(u.deleted,0)=0;

    IF @company_id IS NULL OR @has_access=0
    BEGIN
      SET @AccessDenied=1;
      SET @Message='Anda tidak memiliki akses untuk melihat aktivitas karyawan lain';
    END;

    SELECT a.id Id,a.userid UserId,u.name EmployeeName,ci.job_position JobPosition,
      ci.organization Organization,a.activity_date ActivityDate,a.description Description,
      a.category_id CategoryId,cat.category_key CategoryKey,cat.label CategoryLabel,
      cat.icon_name IconName,a.office_location_id OfficeLocationId,ol.office_name OfficeName,
      a.location_text LocationText,a.start_time StartTime,a.end_time EndTime,a.status Status,
      a.review_notes ReviewNotes,a.created_at CreatedAt
    FROM dbo.udt_daily_activity a
    INNER JOIN dbo.udt_users u ON u.userid=a.userid AND u.active=1 AND ISNULL(u.deleted,0)=0
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=a.userid AND ci.company_id=a.company_id
    INNER JOIN dbo.udt_daily_activity_category cat ON cat.id=a.category_id
    LEFT JOIN dbo.udt_office_locations ol ON ol.id=a.office_location_id AND ol.company_id=a.company_id
    WHERE @AccessDenied=0 AND a.company_id=@company_id
      AND (@StartDate IS NULL OR a.activity_date >= @StartDate)
      AND (@EndDate IS NULL OR a.activity_date <= @EndDate)
    ORDER BY a.activity_date DESC,a.created_at DESC;

    SELECT att.id Id,att.activity_id ActivityId,att.name Name,att.filetype FileType,att.uploaded_at UploadedAt
    FROM dbo.udt_daily_activity_attachment att
    INNER JOIN dbo.udt_daily_activity a ON a.id=att.activity_id
    WHERE @AccessDenied=0 AND a.company_id=@company_id
      AND (@StartDate IS NULL OR a.activity_date >= @StartDate)
      AND (@EndDate IS NULL OR a.activity_date <= @EndDate)
    ORDER BY att.uploaded_at;
END;
GO

SELECT name,modify_date
FROM sys.procedures
WHERE name IN ('usp_GetDailyActivitiesByUser','usp_GetAllDailyActivitiesByCompany_HRD')
ORDER BY name;
GO
