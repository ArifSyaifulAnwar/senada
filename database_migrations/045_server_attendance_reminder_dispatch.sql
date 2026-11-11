/*
  SENADA - Pengiriman push pengingat belum absen dari server.

  Procedure ini dikonsumsi job server setiap menit. Setiap baris yang keluar
  sudah "diklaim" di tabel delivery, sehingga perangkat Android, iOS, dan Web
  tidak menerima pengingat ganda pada hari yang sama.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF OBJECT_ID('dbo.udt_user_attendance_reminder_preference', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.udt_user_attendance_reminder_preference
    (
        userid VARCHAR(50) NOT NULL CONSTRAINT PK_user_attendance_reminder_preference PRIMARY KEY,
        is_enabled BIT NOT NULL CONSTRAINT DF_user_attendance_reminder_preference_enabled DEFAULT (1),
        updated_at DATETIME2(0) NOT NULL CONSTRAINT DF_user_attendance_reminder_preference_updated DEFAULT SYSUTCDATETIME()
    );
END;
GO

IF OBJECT_ID('dbo.udt_attendance_reminder_delivery', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.udt_attendance_reminder_delivery
    (
        company_id INT NOT NULL,
        userid VARCHAR(50) NOT NULL,
        reminder_date DATE NOT NULL,
        claimed_at DATETIME2(0) NOT NULL CONSTRAINT DF_attendance_reminder_delivery_claimed DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_attendance_reminder_delivery PRIMARY KEY(company_id, userid, reminder_date),
        CONSTRAINT FK_attendance_reminder_delivery_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_attendance_reminder_user_preference_set
    @userid VARCHAR(50),
    @is_enabled BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.udt_users WHERE userid=@userid AND active=1 AND ISNULL(deleted,0)=0)
        THROW 54500, 'Akun aktif tidak ditemukan.', 1;

    MERGE dbo.udt_user_attendance_reminder_preference AS target
    USING (SELECT @userid userid) AS source ON source.userid=target.userid
    WHEN MATCHED THEN UPDATE SET is_enabled=@is_enabled, updated_at=SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT(userid,is_enabled) VALUES(@userid,@is_enabled);
END;
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

CREATE OR ALTER PROCEDURE dbo.udp_attendance_reminder_setting_get_for_user
    @userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    INNER JOIN dbo.udt_companies c ON c.id=ci.company_id AND c.is_active=1
    WHERE u.userid=@userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL THROW 54400, 'Akun aktif belum terhubung ke perusahaan.', 1;

    SELECT ISNULL(s.start_time,CAST('08:00' AS TIME)) StartTime,
           ISNULL(s.grace_minutes,10) GraceMinutes,
           CAST(CASE WHEN ISNULL(s.is_enabled,1)=1 AND ISNULL(p.is_enabled,1)=1 THEN 1 ELSE 0 END AS BIT) IsEnabled
    FROM dbo.udt_companies c
    LEFT JOIN dbo.udt_company_attendance_reminder_setting s ON s.company_id=c.id
    LEFT JOIN dbo.udt_user_attendance_reminder_preference p ON p.userid=@userid
    WHERE c.id=@company_id;
END;
GO
