/* SENADA - Kartu ringkasan Home HRD/Admin per perusahaan. */
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.udt_attendance_summary_card','company_id') IS NULL
    ALTER TABLE dbo.udt_attendance_summary_card ADD company_id INT NULL;
GO

DECLARE @legacy_company_id INT;
SELECT TOP(1) @legacy_company_id=ci.company_id
FROM dbo.udt_company_info_user ci INNER JOIN dbo.udt_users u ON u.userid=ci.userid
WHERE u.active=1 AND ISNULL(u.deleted,0)=0 AND ci.company_id IS NOT NULL
GROUP BY ci.company_id ORDER BY COUNT(*) DESC,ci.company_id;
IF @legacy_company_id IS NULL THROW 53700,'Perusahaan awal tidak ditemukan.',1;

UPDATE c SET company_id=ISNULL(owner_ci.company_id,@legacy_company_id)
FROM dbo.udt_attendance_summary_card c
LEFT JOIN dbo.udt_company_info_user owner_ci ON owner_ci.userid=c.user_id
WHERE c.company_id IS NULL;
GO

IF EXISTS(SELECT 1 FROM dbo.udt_attendance_summary_card WHERE company_id IS NULL)
    THROW 53701,'Masih ada kartu ringkasan tanpa perusahaan.',1;
GO

ALTER TABLE dbo.udt_attendance_summary_card ALTER COLUMN company_id INT NOT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_attendance_summary_card_company')
 ALTER TABLE dbo.udt_attendance_summary_card WITH CHECK ADD CONSTRAINT FK_attendance_summary_card_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_attendance_summary_card') AND name='IX_attendance_summary_card_company_order')
 CREATE INDEX IX_attendance_summary_card_company_order ON dbo.udt_attendance_summary_card(company_id,urutan,id);
GO

CREATE OR ALTER PROCEDURE dbo.udp_attendance_summary_card_get_all
 @request_user_id VARCHAR(50)
AS
BEGIN
 SET NOCOUNT ON; SET DATEFIRST 1;
 DECLARE @company_id INT,@tahun INT=YEAR(GETDATE()),@bulan INT=MONTH(GETDATE()),@mulai DATE,@selesai DATE,@total INT=0;
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@request_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0;
 IF @company_id IS NULL THROW 53702,'Akun tidak aktif atau belum terhubung ke perusahaan.',1;

 /* PT baru menerima salinan kartu sebagai konfigurasi awal sendiri. */
 IF NOT EXISTS(SELECT 1 FROM dbo.udt_attendance_summary_card WHERE company_id=@company_id)
 BEGIN
   DECLARE @template_company_id INT;
   SELECT TOP(1) @template_company_id=company_id FROM dbo.udt_attendance_summary_card ORDER BY company_id;
   INSERT dbo.udt_attendance_summary_card(user_id,icon,icon_color,title,main_text,sub_text,urutan,created_at,company_id)
   SELECT NULL,icon,icon_color,title,main_text,sub_text,urutan,GETDATE(),@company_id
   FROM dbo.udt_attendance_summary_card WHERE company_id=@template_company_id AND user_id IS NULL;
 END;

 SELECT TOP(1) @mulai=tanggal_mulai,@selesai=tanggal_selesai FROM dbo.udt_work_period
 WHERE company_id=@company_id AND tahun=@tahun AND bulan=@bulan AND deleted=0 ORDER BY id DESC;
 IF @mulai IS NULL OR @selesai IS NULL
 BEGIN SET @total=0; END
 ELSE
 BEGIN
  ;WITH dates AS (SELECT @mulai d UNION ALL SELECT DATEADD(DAY,1,d) FROM dates WHERE d<@selesai)
  SELECT @total=COUNT(*) FROM dates d WHERE DATEPART(WEEKDAY,d.d) NOT IN(6,7)
   AND NOT EXISTS(SELECT 1 FROM dbo.udt_company_calendar c WHERE c.company_id=@company_id AND CAST(c.tanggal AS DATE)=d.d AND UPPER(c.tipe)='LIBUR') OPTION(MAXRECURSION 500);
 END;
 UPDATE dbo.udt_attendance_summary_card SET main_text=CAST(@total AS VARCHAR(50)),sub_text=CASE WHEN @mulai IS NULL THEN 'Belum Setting' ELSE 'Hari Kerja' END
 WHERE company_id=@company_id AND title='Total Hari' AND user_id IS NULL;
 IF NOT EXISTS(SELECT 1 FROM dbo.udt_attendance_summary_card WHERE company_id=@company_id AND title='Total Hari' AND user_id IS NULL)
  INSERT dbo.udt_attendance_summary_card(user_id,icon,icon_color,title,main_text,sub_text,urutan,created_at,company_id)
  VALUES(NULL,'calendar','blue','Total Hari',CAST(@total AS VARCHAR(50)),CASE WHEN @mulai IS NULL THEN 'Belum Setting' ELSE 'Hari Kerja' END,4,GETDATE(),@company_id);
 SELECT id,icon,icon_color,title,main_text,sub_text,urutan FROM dbo.udt_attendance_summary_card WHERE company_id=@company_id ORDER BY urutan,id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_attendance_summary_card_update
 @id INT,@main_text NVARCHAR(100),@sub_text NVARCHAR(100)=NULL,@request_user_id VARCHAR(50)
AS
BEGIN
 SET NOCOUNT ON; DECLARE @company_id INT;
 SELECT TOP(1) @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
 WHERE u.userid=@request_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0
  AND (UPPER(ISNULL(u.role,'')) IN('HRD','ADMIN') OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%');
 IF @company_id IS NULL THROW 53703,'Anda tidak memiliki akses mengubah ringkasan perusahaan.',1;
 UPDATE dbo.udt_attendance_summary_card SET main_text=@main_text,sub_text=ISNULL(@sub_text,sub_text) WHERE id=@id AND company_id=@company_id;
 SELECT @@ROWCOUNT affected_rows;
END;
GO

SELECT company_id,COUNT(*) total_kartu FROM dbo.udt_attendance_summary_card GROUP BY company_id ORDER BY company_id;
GO
