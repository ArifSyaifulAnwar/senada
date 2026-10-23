/*
  SENADA - Jadwal Doa Karyawan per perusahaan

  Sebelumnya satu tanggal hanya mempunyai satu jadwal global. Dengan company_id,
  setiap PT dapat mengelola jadwalnya sendiri dan anggota lintas PT ditolak.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.udt_doa_karyawan', 'company_id') IS NULL
    ALTER TABLE dbo.udt_doa_karyawan ADD company_id INT NULL;
GO

UPDATE d
SET company_id = ci.company_id
FROM dbo.udt_doa_karyawan d
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = d.hrd_user_id
WHERE d.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_doa_karyawan WHERE company_id IS NULL)
    THROW 53500, 'Masih ada jadwal doa tanpa perusahaan. Perbaiki HRD pembuatnya terlebih dahulu.', 1;
GO

ALTER TABLE dbo.udt_doa_karyawan ALTER COLUMN company_id INT NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_doa_karyawan_company')
    ALTER TABLE dbo.udt_doa_karyawan WITH CHECK
    ADD CONSTRAINT FK_doa_karyawan_company FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_doa_karyawan') AND name='IX_doa_karyawan_company_tanggal')
    CREATE INDEX IX_doa_karyawan_company_tanggal
        ON dbo.udt_doa_karyawan(company_id, tanggal, created_at DESC);
GO

CREATE OR ALTER TRIGGER dbo.trg_doa_karyawan_company_guard
ON dbo.udt_doa_karyawan
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user hrd ON hrd.userid=i.hrd_user_id
        LEFT JOIN dbo.udt_company_info_user leader ON leader.userid=i.pemimpin_doa_id
        WHERE hrd.company_id IS NULL OR leader.company_id IS NULL
           OR hrd.company_id<>i.company_id OR leader.company_id<>i.company_id
    )
        THROW 53501, 'HRD dan pemimpin doa wajib berasal dari perusahaan yang sama.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_doa_peserta_company_guard
ON dbo.udt_doa_peserta
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.udt_doa_karyawan d ON d.id=i.doa_id
        LEFT JOIN dbo.udt_company_info_user participant ON participant.userid=i.userid
        WHERE participant.company_id IS NULL OR participant.company_id<>d.company_id
    )
        THROW 53502, 'Peserta doa harus berasal dari perusahaan yang sama.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_doa_dropdown_karyawan_by_hrd
    @hrdUserId     NVARCHAR(50),
    @search        NVARCHAR(100) = NULL,
    @excludeUserId NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT TOP(1) @company_id=ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@hrdUserId AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(ISNULL(u.role,''))='HRD' OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%');

    SELECT u.userid,u.name,u.mail,ci.employeeID,ci.organization,ci.job_position
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid AND ci.company_id=@company_id
    WHERE @company_id IS NOT NULL AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (@excludeUserId IS NULL OR u.userid<>@excludeUserId)
      AND (@search IS NULL OR u.name LIKE '%'+@search+'%' OR ci.employeeID LIKE '%'+@search+'%')
    ORDER BY u.name,u.userid;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_doa_get_by_tanggal
    @hrd_user_id VARCHAR(50),
    @tanggal DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT TOP(1) @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@hrd_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(ISNULL(u.role,''))='HRD' OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%');

    SELECT d.id,d.tanggal,d.pemimpin_doa_id,pemimpin.name AS pemimpin_doa_name,d.catatan,d.created_at,
      (SELECT p.userid,u.name FROM dbo.udt_doa_peserta p INNER JOIN dbo.udt_users u ON u.userid=p.userid
       WHERE p.doa_id=d.id FOR JSON PATH) AS peserta_json
    FROM dbo.udt_doa_karyawan d
    INNER JOIN dbo.udt_users pemimpin ON pemimpin.userid=d.pemimpin_doa_id
    WHERE d.company_id=@company_id AND d.tanggal=@tanggal
    ORDER BY d.created_at DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_doa_save
    @hrd_user_id VARCHAR(50), @tanggal DATE, @pemimpin_doa_id VARCHAR(50),
    @peserta_ids NVARCHAR(MAX), @catatan NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @hrd_user_id=NULLIF(LTRIM(RTRIM(@hrd_user_id)), '');
    SET @pemimpin_doa_id=NULLIF(LTRIM(RTRIM(@pemimpin_doa_id)), '');
    SET @catatan=NULLIF(LTRIM(RTRIM(@catatan)), '');
    IF @tanggal IS NULL OR @hrd_user_id IS NULL OR @pemimpin_doa_id IS NULL OR ISJSON(@peserta_ids)<>1
        THROW 53503, 'Data jadwal doa tidak valid.', 1;

    DECLARE @company_id INT;
    SELECT TOP(1) @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@hrd_user_id AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(ISNULL(u.role,''))='HRD' OR UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%' OR UPPER(ISNULL(ci.job_position,'')) LIKE '%HRD%');
    IF @company_id IS NULL THROW 53504, 'HRD tidak aktif atau belum terhubung ke perusahaan.', 1;
    IF NOT EXISTS(SELECT 1 FROM dbo.udt_company_info_user WHERE userid=@pemimpin_doa_id AND company_id=@company_id)
        THROW 53505, 'Pemimpin doa tidak berasal dari perusahaan Anda.', 1;

    DECLARE @peserta TABLE(userid VARCHAR(50) NOT NULL PRIMARY KEY);
    INSERT @peserta(userid)
    SELECT DISTINCT CONVERT(VARCHAR(50),LTRIM(RTRIM([value]))) FROM OPENJSON(@peserta_ids)
    WHERE NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(50),[value]))),'') IS NOT NULL;
    IF EXISTS(SELECT 1 FROM @peserta p LEFT JOIN dbo.udt_company_info_user ci ON ci.userid=p.userid WHERE ci.company_id IS NULL OR ci.company_id<>@company_id)
        THROW 53506, 'Peserta doa tidak berasal dari perusahaan Anda.', 1;

    BEGIN TRY
      BEGIN TRANSACTION;
      DECLARE @doa_id INT,@is_replace BIT=0;
      SELECT @doa_id=id FROM dbo.udt_doa_karyawan WITH(UPDLOCK,HOLDLOCK) WHERE company_id=@company_id AND tanggal=@tanggal;
      IF @doa_id IS NULL
      BEGIN
        INSERT dbo.udt_doa_karyawan(tanggal,pemimpin_doa_id,hrd_user_id,catatan,created_at,updated_at,company_id)
        VALUES(@tanggal,@pemimpin_doa_id,@hrd_user_id,@catatan,GETDATE(),GETDATE(),@company_id);
        SET @doa_id=CONVERT(INT,SCOPE_IDENTITY());
      END
      ELSE
      BEGIN
        SET @is_replace=1;
        UPDATE dbo.udt_doa_karyawan SET pemimpin_doa_id=@pemimpin_doa_id,hrd_user_id=@hrd_user_id,catatan=@catatan,updated_at=GETDATE() WHERE id=@doa_id;
        DELETE dbo.udt_doa_peserta WHERE doa_id=@doa_id;
      END;
      INSERT dbo.udt_doa_peserta(doa_id,userid,created_at) SELECT @doa_id,userid,GETDATE() FROM @peserta;
      COMMIT;
      SELECT CAST(1 AS BIT) success,CASE WHEN @is_replace=1 THEN 'Data doa berhasil diperbarui.' ELSE 'Data doa berhasil disimpan.' END message,@doa_id doa_id;
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT>0 ROLLBACK;
      SELECT CAST(0 AS BIT) success,ERROR_MESSAGE() message,CAST(NULL AS INT) doa_id;
    END CATCH;
END;
GO

SELECT company_id,COUNT(*) total_jadwal FROM dbo.udt_doa_karyawan GROUP BY company_id ORDER BY company_id;
GO
