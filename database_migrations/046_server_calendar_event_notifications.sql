/*
  SENADA - Notifikasi kalender terjadwal.

  Pengingat dikirim 10 menit sebelum jam masuk perusahaan untuk event LIBUR
  pada hari tersebut dan ulang tahun rekan kerja aktif pada PT yang sama.
  Delivery diklaim terlebih dahulu agar job yang berjalan tiap menit tidak
  mengirim push ganda ke satu penerima.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF OBJECT_ID('dbo.udt_calendar_event_notification_delivery', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.udt_calendar_event_notification_delivery
    (
        company_id INT NOT NULL,
        userid VARCHAR(50) NOT NULL,
        event_date DATE NOT NULL,
        event_key VARCHAR(100) NOT NULL,
        claimed_at DATETIME2(0) NOT NULL
            CONSTRAINT DF_calendar_event_notification_claimed DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_calendar_event_notification_delivery
            PRIMARY KEY(company_id, userid, event_date, event_key),
        CONSTRAINT FK_calendar_event_notification_delivery_company
            FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_calendar_event_notification_claim_due
    @now DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @today DATE=CAST(@now AS DATE);

    ;WITH calendar_events AS
    (
        SELECT c.company_id,
               CONCAT('LIBUR_', c.id) event_key,
               CAST('holiday' AS VARCHAR(20)) event_type,
               COALESCE(NULLIF(LTRIM(RTRIM(c.keterangan)),''),'Hari Libur') event_name
        FROM dbo.udt_company_calendar c
        INNER JOIN dbo.udt_companies co ON co.id=c.company_id AND co.is_active=1
        WHERE CAST(c.tanggal AS DATE)=@today
          AND UPPER(LTRIM(RTRIM(ISNULL(c.tipe,''))))='LIBUR'

        UNION ALL

        SELECT ci.company_id,
               CONCAT('BIRTHDAY_', u.userid) event_key,
               CAST('birthday' AS VARCHAR(20)) event_type,
               u.name event_name
        FROM dbo.udt_users u
        INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
        INNER JOIN dbo.udt_companies co ON co.id=ci.company_id AND co.is_active=1
        WHERE u.active=1 AND ISNULL(u.deleted,0)=0 AND u.birth_date IS NOT NULL
          AND MONTH(u.birth_date)=MONTH(@today)
          AND
          (
              DAY(u.birth_date)=DAY(@today)
              OR (MONTH(u.birth_date)=2 AND DAY(u.birth_date)=29
                  AND MONTH(@today)=2 AND DAY(@today)=28
                  AND DATEPART(DAY, EOMONTH(@today))=28)
          )
    ), due AS
    (
        SELECT ev.company_id, recipient.userid, ev.event_key, ev.event_type, ev.event_name
        FROM calendar_events ev
        LEFT JOIN dbo.udt_company_attendance_reminder_setting setting
            ON setting.company_id=ev.company_id
        INNER JOIN dbo.udt_users recipient
            ON recipient.active=1 AND ISNULL(recipient.deleted,0)=0
        INNER JOIN dbo.udt_company_info_user recipient_company
            ON recipient_company.userid=recipient.userid
           AND recipient_company.company_id=ev.company_id
        WHERE CAST(@now AS TIME) >= DATEADD(MINUTE,-10,ISNULL(setting.start_time,CAST('08:00' AS TIME)))
          AND CAST(@now AS TIME) < ISNULL(setting.start_time,CAST('08:00' AS TIME))
    )
    MERGE dbo.udt_calendar_event_notification_delivery WITH (HOLDLOCK) AS target
    USING due AS source
      ON target.company_id=source.company_id
     AND target.userid=source.userid
     AND target.event_date=@today
     AND target.event_key=source.event_key
    WHEN NOT MATCHED THEN
      INSERT(company_id,userid,event_date,event_key)
      VALUES(source.company_id,source.userid,@today,source.event_key)
    OUTPUT inserted.userid, inserted.event_date, source.event_type, source.event_name, source.event_key;
END;
GO

SELECT name, modify_date
FROM sys.procedures
WHERE name='udp_calendar_event_notification_claim_due';
GO
