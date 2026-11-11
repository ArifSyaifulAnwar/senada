/*
  SENADA - Jadwal pengingat absen per perusahaan.
  Default dibuat 08:00 dengan pengingat 10 menit setelah jam masuk.
  HRD/Admin dapat mengganti jadwal per PT melalui procedure di bawah; user
  tidak pernah mengirim atau menentukan company_id sendiri.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF OBJECT_ID('dbo.udt_company_attendance_reminder_setting', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.udt_company_attendance_reminder_setting
    (
        company_id INT NOT NULL CONSTRAINT PK_company_attendance_reminder_setting PRIMARY KEY,
        start_time TIME(0) NOT NULL CONSTRAINT DF_company_attendance_reminder_start DEFAULT ('08:00'),
        grace_minutes INT NOT NULL CONSTRAINT DF_company_attendance_reminder_grace DEFAULT (10),
        is_enabled BIT NOT NULL CONSTRAINT DF_company_attendance_reminder_enabled DEFAULT (1),
        updated_at DATETIME2(0) NOT NULL CONSTRAINT DF_company_attendance_reminder_updated DEFAULT SYSUTCDATETIME(),
        updated_by VARCHAR(50) NULL,
        CONSTRAINT FK_company_attendance_reminder_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id),
        CONSTRAINT CK_company_attendance_reminder_grace CHECK (grace_minutes BETWEEN 0 AND 120)
    );
END;
GO

INSERT dbo.udt_company_attendance_reminder_setting(company_id)
SELECT c.id
FROM dbo.udt_companies c
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.udt_company_attendance_reminder_setting s WHERE s.company_id=c.id
);
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
           ISNULL(s.is_enabled,1) IsEnabled
    FROM dbo.udt_companies c
    LEFT JOIN dbo.udt_company_attendance_reminder_setting s ON s.company_id=c.id
    WHERE c.id=@company_id;
END;
GO

/* Jalankan ini saat jam masuk PT perlu dibedakan, contoh: EXEC ... '08:30', 10. */
CREATE OR ALTER PROCEDURE dbo.udp_attendance_reminder_setting_set_by_company
    @actor_userid VARCHAR(50), @start_time TIME(0), @grace_minutes INT = 10, @is_enabled BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @grace_minutes NOT BETWEEN 0 AND 120 THROW 54401, 'Grace minutes harus 0 sampai 120.', 1;
    DECLARE @company_id INT,@allowed BIT=0;
    SELECT @company_id=ci.company_id,
      @allowed=CASE WHEN UPPER(ISNULL(u.role,'')) IN('HRD','ADMIN') THEN 1 ELSE 0 END
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@actor_userid AND u.active=1 AND ISNULL(u.deleted,0)=0;
    IF @company_id IS NULL OR @allowed=0 THROW 54402, 'Tidak berhak mengubah pengingat perusahaan.', 1;

    MERGE dbo.udt_company_attendance_reminder_setting AS target
    USING (SELECT @company_id company_id) AS source ON source.company_id=target.company_id
    WHEN MATCHED THEN UPDATE SET start_time=@start_time,grace_minutes=@grace_minutes,is_enabled=@is_enabled,
      updated_at=SYSUTCDATETIME(),updated_by=@actor_userid
    WHEN NOT MATCHED THEN INSERT(company_id,start_time,grace_minutes,is_enabled,updated_by)
      VALUES(@company_id,@start_time,@grace_minutes,@is_enabled,@actor_userid);
END;
GO
