/*
  SENADA - Izin aktif bukan "belum absen".

  Selama rentang izin mencakup hari ini dan pengajuan belum ditolak/dibatalkan,
  karyawan dikecualikan dari daftar belum absen, pengingat manual HRD, serta
  push otomatis +10 menit. Status Pending tetap dihitung sebagai izin aktif.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.udp_attendance_reminder_claim_due
    @now DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @today DATE=CAST(@now AS DATE);
    /* ISO: Senin=1 ... Minggu=7, tidak bergantung SET DATEFIRST. */
    DECLARE @iso_day INT=(DATEDIFF(DAY, CONVERT(DATE,'19000101',112), @today)%7)+1;

    ;WITH due AS
    (
        SELECT ci.company_id,u.userid,u.name,setting.grace_minutes
        FROM dbo.udt_users u
        INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
        INNER JOIN dbo.udt_companies company ON company.id=ci.company_id AND company.is_active=1
        INNER JOIN dbo.udt_company_attendance_reminder_setting setting ON setting.company_id=ci.company_id
        LEFT JOIN dbo.udt_user_attendance_reminder_preference pref ON pref.userid=u.userid
        LEFT JOIN dbo.udt_employee_workdays workdays ON workdays.userid=u.userid AND workdays.company_id=ci.company_id
        WHERE u.active=1 AND ISNULL(u.deleted,0)=0
          AND setting.is_enabled=1 AND ISNULL(pref.is_enabled,1)=1
          AND CAST(@now AS TIME) >= DATEADD(MINUTE,setting.grace_minutes,setting.start_time)
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.udt_attendance a
              WHERE a.company_id=ci.company_id AND a.user_id=u.userid AND CAST(a.attendance_date AS DATE)=@today
          )
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.udt_timeoff t
              WHERE t.company_id=ci.company_id AND t.userid=u.userid
                AND @today BETWEEN CAST(t.tanggal_mulai AS DATE) AND CAST(t.tanggal_selesai AS DATE)
                AND UPPER(LTRIM(RTRIM(ISNULL(t.status,'')))) NOT IN
                    ('REJECTED','DITOLAK','CANCELLED','CANCELED','DIBATALKAN')
          )
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.udt_company_calendar holiday
              WHERE holiday.company_id=ci.company_id AND CAST(holiday.tanggal AS DATE)=@today
                AND UPPER(LTRIM(RTRIM(ISNULL(holiday.tipe,''))))='LIBUR'
          )
          AND (@iso_day NOT IN (6,7) OR EXISTS
          (
              SELECT 1 FROM dbo.udt_company_calendar forced_workday
              WHERE forced_workday.company_id=ci.company_id AND CAST(forced_workday.tanggal AS DATE)=@today
                AND UPPER(LTRIM(RTRIM(ISNULL(forced_workday.tipe,''))))='KERJA'
          ))
          AND (workdays.userid IS NULL OR CHARINDEX(','+CONVERT(VARCHAR(2),@iso_day)+',', ','+REPLACE(workdays.work_days,' ','')+',')>0)
    )
    MERGE dbo.udt_attendance_reminder_delivery WITH (HOLDLOCK) AS target
    USING due AS source
      ON target.company_id=source.company_id AND target.userid=source.userid AND target.reminder_date=@today
    WHEN NOT MATCHED THEN
      INSERT(company_id,userid,reminder_date) VALUES(source.company_id,source.userid,@today)
    OUTPUT inserted.company_id,inserted.userid,source.name,source.grace_minutes,inserted.reminder_date;
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
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.udt_attendance a
          WHERE a.user_id=u.userid AND a.company_id=@company_id AND CAST(a.attendance_date AS DATE)=@tanggal
      )
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.udt_timeoff t
          WHERE t.company_id=@company_id AND t.userid=u.userid
            AND @tanggal BETWEEN CAST(t.tanggal_mulai AS DATE) AND CAST(t.tanggal_selesai AS DATE)
            AND UPPER(LTRIM(RTRIM(ISNULL(t.status,'')))) NOT IN
                ('REJECTED','DITOLAK','CANCELLED','CANCELED','DIBATALKAN')
      )
    ORDER BY u.name;
END;
GO

SELECT name, modify_date
FROM sys.procedures
WHERE name IN ('udp_attendance_reminder_claim_due','udp_attendance_get_belum_absen_for_notify')
ORDER BY name;
GO
