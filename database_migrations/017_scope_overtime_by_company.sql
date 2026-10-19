/*
  SENADA - Isolasi modul lembur per perusahaan

  Hasil:
  - setiap pengajuan menyimpan company_id pemilik;
  - karyawan hanya membaca/mengubah pengajuan miliknya;
  - HRD/Admin hanya melihat dan memproses lembur dari PT sendiri;
  - statistik, daftar karyawan, export, dan nomor dokumen terpisah per PT;
  - approver dan pengaju wajib berasal dari company_id yang sama.

  Jalankan pada ABSENSI setelah seluruh user aktif memiliki company_id.
*/

USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

/* ========================================================================== */
/* 1. Tenant permanen pada transaksi lembur                                   */
/* ========================================================================== */
IF COL_LENGTH('dbo.udt_overtime', 'company_id') IS NULL
    ALTER TABLE dbo.udt_overtime ADD company_id INT NULL;
GO

UPDATE o
SET o.company_id = ci.company_id
FROM dbo.udt_overtime o
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = o.userid
WHERE o.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_overtime WHERE company_id IS NULL)
    THROW 51700, 'Masih ada data lembur tanpa company_id. Perbaiki mapping user terlebih dahulu.', 1;
GO

ALTER TABLE dbo.udt_overtime ALTER COLUMN company_id INT NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_overtime_company')
    ALTER TABLE dbo.udt_overtime WITH CHECK
    ADD CONSTRAINT FK_overtime_company FOREIGN KEY(company_id)
        REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_overtime')
      AND name = 'IX_overtime_company_status_date'
)
    CREATE INDEX IX_overtime_company_status_date
        ON dbo.udt_overtime(company_id, status, tanggal_overtime)
        INCLUDE(userid, total_jam, created_at);
GO

CREATE OR ALTER TRIGGER dbo.trg_overtime_company_guard
ON dbo.udt_overtime
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user owner_ci ON owner_ci.userid = i.userid
        WHERE owner_ci.company_id IS NULL OR owner_ci.company_id <> i.company_id
    )
        THROW 51701, 'Perusahaan lembur tidak sesuai dengan perusahaan karyawan.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user approver_ci ON approver_ci.userid = i.approved_by
        WHERE i.approved_by IS NOT NULL
          AND (approver_ci.company_id IS NULL OR approver_ci.company_id <> i.company_id)
    )
        THROW 51702, 'Approver lembur harus berasal dari perusahaan yang sama.', 1;
END;
GO

/* ========================================================================== */
/* 2. Submit, riwayat, edit, dan hapus milik karyawan                         */
/* ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.udp_overtime_insert
    @userid           VARCHAR(50),
    @tanggal_overtime DATE,
    @jam_mulai        TIME,
    @jam_selesai      TIME,
    @total_jam        DECIMAL(4,2),
    @catatan          VARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @company_id INT;
    SELECT TOP (1) @company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
    WHERE u.userid = @userid AND u.active = 1 AND ISNULL(u.deleted, 0) = 0;

    IF @company_id IS NULL
        THROW 51703, 'User tidak aktif atau belum terhubung ke perusahaan.', 1;

    DECLARE @durasi_menit INT = CASE
        WHEN @jam_selesai > @jam_mulai THEN DATEDIFF(MINUTE, @jam_mulai, @jam_selesai)
        WHEN @jam_selesai < @jam_mulai THEN
            DATEDIFF(MINUTE, @jam_mulai, CAST('23:59:59.9999999' AS TIME)) + 1
            + DATEDIFF(MINUTE, CAST('00:00:00' AS TIME), @jam_selesai)
        ELSE 0 END;

    IF @durasi_menit <= 0 OR @durasi_menit > 720
        THROW 51704, 'Durasi lembur harus lebih dari 0 dan maksimal 12 jam.', 1;

    IF ABS(CAST(@total_jam AS DECIMAL(6,2))
           - CAST(@durasi_menit AS DECIMAL(10,2)) / 60.0) > 0.10
        THROW 51705, 'Total jam lembur tidak sesuai dengan jam mulai dan jam selesai.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.udt_overtime
        WHERE company_id = @company_id AND userid = @userid
          AND tanggal_overtime = @tanggal_overtime
          AND status IN ('Pending', 'Approved')
    )
        THROW 51706, 'Sudah ada pengajuan lembur untuk tanggal ini.', 1;

    INSERT dbo.udt_overtime
    (
        company_id, userid, tanggal_overtime, jam_mulai, jam_selesai,
        total_jam, catatan, status, created_at, updated_at
    )
    VALUES
    (
        @company_id, @userid, @tanggal_overtime, @jam_mulai, @jam_selesai,
        @total_jam, NULLIF(LTRIM(RTRIM(@catatan)), ''), 'Pending', GETDATE(), GETDATE()
    );

    SELECT CONVERT(INT, SCOPE_IDENTITY()) AS NewId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_overtime_get_by_user
    @userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id = company_id FROM dbo.udt_company_info_user WHERE userid = @userid;

    SELECT o.id,o.userid,u.name user_name,o.tanggal_overtime,o.jam_mulai,
           o.jam_selesai,o.total_jam,o.catatan,o.status,o.created_at,o.updated_at,
           o.approved_by,approver.name approver_name,o.approved_at,o.rejection_reason
    FROM dbo.udt_overtime o
    INNER JOIN dbo.udt_users u ON u.userid = o.userid
    LEFT JOIN dbo.udt_users approver ON approver.userid = o.approved_by
    WHERE o.company_id = @company_id AND o.userid = @userid
    ORDER BY o.tanggal_overtime DESC,o.created_at DESC;

    SELECT COUNT(*) TotalCount
    FROM dbo.udt_overtime
    WHERE company_id = @company_id AND userid = @userid;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_overtime_update
    @id INT,@userid VARCHAR(50),@tanggal_overtime DATE,@jam_mulai TIME,
    @jam_selesai TIME,@total_jam DECIMAL(4,2),@catatan VARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@userid;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.udt_overtime
        WHERE id=@id AND company_id=@company_id AND userid=@userid AND status='Pending'
    )
        THROW 51707, 'Data lembur tidak ditemukan, bukan milik Anda, atau sudah diproses.', 1;

    DECLARE @durasi_menit INT=CASE
        WHEN @jam_selesai>@jam_mulai THEN DATEDIFF(MINUTE,@jam_mulai,@jam_selesai)
        WHEN @jam_selesai<@jam_mulai THEN
            DATEDIFF(MINUTE,@jam_mulai,CAST('23:59:59.9999999' AS TIME))+1
            +DATEDIFF(MINUTE,CAST('00:00:00' AS TIME),@jam_selesai)
        ELSE 0 END;
    IF @durasi_menit<=0 OR @durasi_menit>720
        THROW 51708, 'Durasi lembur harus lebih dari 0 dan maksimal 12 jam.', 1;
    IF ABS(CAST(@total_jam AS DECIMAL(6,2))-CAST(@durasi_menit AS DECIMAL(10,2))/60.0)>0.10
        THROW 51709, 'Total jam lembur tidak sesuai.', 1;
    IF EXISTS
    (
        SELECT 1 FROM dbo.udt_overtime
        WHERE company_id=@company_id AND userid=@userid
          AND tanggal_overtime=@tanggal_overtime AND status IN ('Pending','Approved') AND id<>@id
    )
        THROW 51710, 'Sudah ada pengajuan lembur untuk tanggal ini.', 1;

    UPDATE dbo.udt_overtime
    SET tanggal_overtime=@tanggal_overtime,jam_mulai=@jam_mulai,
        jam_selesai=@jam_selesai,total_jam=@total_jam,
        catatan=NULLIF(LTRIM(RTRIM(@catatan)),''),updated_at=GETDATE()
    WHERE id=@id AND company_id=@company_id AND userid=@userid AND status='Pending';
    SELECT @@ROWCOUNT AffectedRows;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_overtime_delete
    @id INT,@userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@userid;
    DELETE dbo.udt_overtime
    WHERE id=@id AND company_id=@company_id AND userid=@userid AND status='Pending';
    IF @@ROWCOUNT=0
        THROW 51711, 'Data lembur tidak ditemukan, bukan milik Anda, atau sudah diproses.', 1;
    SELECT 1 AffectedRows;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_overtime_get_summary
    @userid VARCHAR(50)=NULL,@year INT=NULL,@month INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@userid)),'') IS NULL
        THROW 51712, 'UserId wajib diisi.', 1;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@userid;
    SET @year=ISNULL(@year,YEAR(GETDATE()));
    SET @month=ISNULL(@month,MONTH(GETDATE()));
    SELECT COUNT(*) TotalPengajuan,
           ISNULL(SUM(CASE WHEN status='Pending' THEN 1 ELSE 0 END),0) Pending,
           ISNULL(SUM(CASE WHEN status='Approved' THEN 1 ELSE 0 END),0) Approved,
           ISNULL(SUM(CASE WHEN status='Rejected' THEN 1 ELSE 0 END),0) Rejected,
           ISNULL(SUM(CASE WHEN status='Approved' THEN total_jam ELSE 0 END),0) TotalJamDisetujui,
           ISNULL(AVG(CASE WHEN status='Approved' THEN total_jam END),0) RataRataJam
    FROM dbo.udt_overtime
    WHERE company_id=@company_id AND userid=@userid
      AND YEAR(tanggal_overtime)=@year AND MONTH(tanggal_overtime)=@month;
END;
GO

/* List legacy untuk halaman approval lama, tetap wajib membawa viewer. */
CREATE OR ALTER PROCEDURE dbo.udp_overtime_get_all
    @status VARCHAR(20)=NULL,@page INT=1,@pageSize INT=10,
    @viewer_userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@viewer_userid AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(u.role) IN ('ADMIN','HRD') OR UPPER(ci.organization) LIKE '%HRD%');
    IF @company_id IS NULL THROW 51713,'Viewer tidak berwenang atau belum memiliki perusahaan.',1;
    DECLARE @offset INT=(CASE WHEN @page<1 THEN 1 ELSE @page END-1)*@pageSize;
    SELECT o.id,o.userid,u.name user_name,o.tanggal_overtime,o.jam_mulai,o.jam_selesai,
           o.total_jam,o.catatan,o.status,o.created_at,o.updated_at,o.approved_by,
           approver.name approver_name,o.approved_at,o.rejection_reason
    FROM dbo.udt_overtime o
    INNER JOIN dbo.udt_users u ON u.userid=o.userid
    LEFT JOIN dbo.udt_users approver ON approver.userid=o.approved_by
    WHERE o.company_id=@company_id AND (@status IS NULL OR o.status=@status)
    ORDER BY o.created_at DESC OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;
    SELECT COUNT(*) TotalCount FROM dbo.udt_overtime
    WHERE company_id=@company_id AND (@status IS NULL OR status=@status);
END;
GO

/* Internal lookup; bila viewer diberikan, wajib satu perusahaan. */
CREATE OR ALTER PROCEDURE dbo.udp_overtime_get_by_id
    @id INT,@viewer_userid VARCHAR(50)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT o.* FROM dbo.udt_overtime o
    LEFT JOIN dbo.udt_company_info_user viewer ON viewer.userid=@viewer_userid
    WHERE o.id=@id AND (@viewer_userid IS NULL OR viewer.company_id=o.company_id);
END;
GO

/* ========================================================================== */
/* 3. Dashboard dan operasi HRD/Admin                                         */
/* ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.udp_overtime_admin_statistics
    @adminId VARCHAR(50),@year INT=0,@month INT=0,
    @startDate DATE=NULL,@endDate DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@adminId AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(u.role) IN ('ADMIN','HRD') OR UPPER(ci.organization) LIKE '%HRD%'
           OR UPPER(ci.job_position) LIKE '%DIREKTUR%');
    IF @company_id IS NULL THROW 51714,'Admin/HRD tidak berwenang atau belum memiliki perusahaan.',1;
    DECLARE @useRange BIT=CASE WHEN @startDate IS NOT NULL OR @endDate IS NOT NULL THEN 1 ELSE 0 END;
    SELECT COUNT(*) totalSubmissions,
      ISNULL(SUM(CASE WHEN status='Pending' THEN 1 ELSE 0 END),0) pendingCount,
      ISNULL(SUM(CASE WHEN status='Approved' THEN 1 ELSE 0 END),0) approvedCount,
      ISNULL(SUM(CASE WHEN status='Rejected' THEN 1 ELSE 0 END),0) rejectedCount,
      CAST(ISNULL(SUM(CASE WHEN status='Pending' THEN total_jam ELSE 0 END),0) AS DECIMAL(10,2)) totalPendingHours,
      CAST(ISNULL(SUM(CASE WHEN status='Approved' THEN total_jam ELSE 0 END),0) AS DECIMAL(10,2)) totalApprovedHours,
      CAST(ISNULL(SUM(CASE WHEN status='Rejected' THEN total_jam ELSE 0 END),0) AS DECIMAL(10,2)) totalRejectedHours,
      CAST(CAST(ISNULL(SUM(CASE WHEN status='Pending' THEN total_jam ELSE 0 END),0) AS DECIMAL(10,2)) AS VARCHAR(30))+' jam' formattedTotalPending,
      CAST(CAST(ISNULL(SUM(CASE WHEN status='Approved' THEN total_jam ELSE 0 END),0) AS DECIMAL(10,2)) AS VARCHAR(30))+' jam' formattedTotalApproved,
      CAST(CAST(ISNULL(SUM(CASE WHEN status='Rejected' THEN total_jam ELSE 0 END),0) AS DECIMAL(10,2)) AS VARCHAR(30))+' jam' formattedTotalRejected
    FROM dbo.udt_overtime
    WHERE company_id=@company_id AND
      ((@useRange=1 AND (@startDate IS NULL OR tanggal_overtime>=@startDate) AND (@endDate IS NULL OR tanggal_overtime<=@endDate))
       OR (@useRange=0 AND (@year=0 OR YEAR(tanggal_overtime)=@year) AND (@month=0 OR MONTH(tanggal_overtime)=@month)));
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_overtime_admin_getall
    @adminId VARCHAR(50),@status VARCHAR(20)=NULL,@userId VARCHAR(50)=NULL,
    @yearFilter INT=NULL,@monthFilter INT=NULL,@startDate DATE=NULL,@endDate DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@adminId AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(u.role) IN ('ADMIN','HRD') OR UPPER(ci.organization) LIKE '%HRD%'
           OR UPPER(ci.job_position) LIKE '%DIREKTUR%');
    IF @company_id IS NULL BEGIN SELECT 0 success,'Akses ditolak atau perusahaan belum terhubung.' message;RETURN;END;
    IF @userId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM dbo.udt_company_info_user WHERE userid=@userId AND company_id=@company_id)
       BEGIN SELECT 0 success,'Karyawan filter berasal dari perusahaan lain.' message;RETURN;END;
    DECLARE @useRange BIT=CASE WHEN @startDate IS NOT NULL OR @endDate IS NOT NULL THEN 1 ELSE 0 END;
    SELECT o.id,o.userid,ISNULL(u.name,'Unknown User') userName,ISNULL(u.mail,'') userEmail,
      ISNULL(u.phone,'') userPhone,ISNULL(ci.job_position,ISNULL(u.jobs,'')) userJob,
      o.tanggal_overtime tanggalOvertime,o.jam_mulai jamMulai,o.jam_selesai jamSelesai,
      ISNULL(o.total_jam,0) totalJam,ISNULL(o.catatan,'') catatan,ISNULL(o.status,'Pending') status,
      o.created_at submittedAt,ISNULL(o.updated_at,o.created_at) updated_at,
      ISNULL(o.approved_by,'') approvedBy,ISNULL(o.approved_by_name,'') approvedByName,
      o.approved_at approvedAt,ISNULL(o.rejection_reason,'') rejectionReason,
      DATEDIFF(DAY,o.created_at,GETDATE()) daysSinceSubmitted,
      CASE WHEN o.status='Pending' THEN 1 ELSE 0 END canBeModified
    FROM dbo.udt_overtime o
    INNER JOIN dbo.udt_users u ON u.userid=o.userid
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=o.userid AND ci.company_id=@company_id
    WHERE o.company_id=@company_id AND (@status IS NULL OR o.status=@status)
      AND (@userId IS NULL OR o.userid=@userId)
      AND ((@useRange=1 AND (@startDate IS NULL OR o.tanggal_overtime>=@startDate) AND (@endDate IS NULL OR o.tanggal_overtime<=@endDate))
       OR (@useRange=0 AND (@yearFilter IS NULL OR YEAR(o.tanggal_overtime)=@yearFilter) AND (@monthFilter IS NULL OR MONTH(o.tanggal_overtime)=@monthFilter)))
    ORDER BY CASE WHEN o.status='Pending' THEN 0 ELSE 1 END,o.created_at DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_overtime_admin_review
    @id INT,@status VARCHAR(20),@approvedBy VARCHAR(100),@approvedById VARCHAR(50),
    @rejectionReason VARCHAR(500)=NULL,@adminId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;SET XACT_ABORT ON;
    IF @status NOT IN ('Approved','Rejected') BEGIN SELECT 0 success,'Status tidak valid.' message;RETURN;END;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@adminId AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(u.role) IN ('ADMIN','HRD') OR UPPER(ci.organization) LIKE '%HRD%');
    IF @company_id IS NULL BEGIN SELECT 0 success,'Reviewer tidak berwenang.' message;RETURN;END;
    IF @approvedById<>@adminId BEGIN SELECT 0 success,'Identitas approver tidak sesuai.' message;RETURN;END;
    UPDATE dbo.udt_overtime
    SET status=@status,approved_by=@adminId,approved_by_name=@approvedBy,
        approved_at=GETDATE(),rejection_reason=CASE WHEN @status='Rejected' THEN @rejectionReason END,
        updated_at=GETDATE()
    WHERE id=@id AND company_id=@company_id AND status='Pending';
    IF @@ROWCOUNT<>1 BEGIN SELECT 0 success,'Lembur tidak ditemukan, berbeda perusahaan, atau sudah diproses.' message;RETURN;END;
    SELECT 1 success,CASE WHEN @status='Approved' THEN 'Overtime berhasil disetujui' ELSE 'Overtime berhasil ditolak' END message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_overtime_update_status
    @id INT,@status VARCHAR(20),@approved_by VARCHAR(50),@rejection_reason VARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id
    FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@approved_by AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(u.role) IN ('ADMIN','HRD') OR UPPER(ci.organization) LIKE '%HRD%');
    IF @company_id IS NULL THROW 51715,'Approver tidak ditemukan atau tidak berwenang.',1;
    IF @status NOT IN ('Approved','Rejected') THROW 51716,'Status harus Approved atau Rejected.',1;
    UPDATE dbo.udt_overtime SET status=@status,approved_by=@approved_by,approved_at=GETDATE(),
      updated_at=GETDATE(),rejection_reason=CASE WHEN @status='Rejected' THEN @rejection_reason END
    WHERE id=@id AND company_id=@company_id AND status='Pending';
    IF @@ROWCOUNT<>1 THROW 51717,'Data lembur tidak ditemukan, berbeda perusahaan, atau sudah diproses.',1;
    SELECT 1 AffectedRows;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_overtime_admin_bulk_action
    @ids VARCHAR(MAX),@action VARCHAR(20),@approvedBy VARCHAR(100),
    @rejectionReason VARCHAR(500)=NULL,@adminId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;SET XACT_ABORT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@adminId AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(u.role) IN ('ADMIN','HRD') OR UPPER(ci.organization) LIKE '%HRD%');
    IF @company_id IS NULL BEGIN SELECT 0 success,'Admin/HRD tidak berwenang.' message;RETURN;END;
    IF LOWER(@action) NOT IN ('approve','reject') BEGIN SELECT 0 success,'Aksi tidak valid.' message;RETURN;END;
    DECLARE @target TABLE(id INT PRIMARY KEY);
    INSERT @target(id) SELECT DISTINCT TRY_CONVERT(INT,value) FROM STRING_SPLIT(@ids,',') WHERE TRY_CONVERT(INT,value) IS NOT NULL;
    IF NOT EXISTS(SELECT 1 FROM @target) BEGIN SELECT 0 success,'Tidak ada ID lembur valid.' message;RETURN;END;
    IF EXISTS(SELECT 1 FROM @target t LEFT JOIN dbo.udt_overtime o ON o.id=t.id AND o.company_id=@company_id WHERE o.id IS NULL OR o.status<>'Pending')
       BEGIN SELECT 0 success,'Ada lembur berbeda perusahaan, tidak ditemukan, atau sudah diproses.' message;RETURN;END;
    DECLARE @status VARCHAR(20)=CASE WHEN LOWER(@action)='approve' THEN 'Approved' ELSE 'Rejected' END;
    UPDATE o SET status=@status,approved_by=@adminId,approved_by_name=@approvedBy,
      approved_at=GETDATE(),rejection_reason=CASE WHEN @status='Rejected' THEN @rejectionReason END,updated_at=GETDATE()
    FROM dbo.udt_overtime o INNER JOIN @target t ON t.id=o.id WHERE o.company_id=@company_id AND o.status='Pending';
    SELECT 1 success,CAST(@@ROWCOUNT AS VARCHAR(12))+' overtime berhasil diproses' message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_overtime_admin_delete
    @id INT,@adminId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@adminId AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(u.role) IN ('ADMIN','HRD') OR UPPER(ci.organization) LIKE '%HRD%');
    DELETE dbo.udt_overtime WHERE id=@id AND company_id=@company_id AND status='Pending';
    IF @@ROWCOUNT<>1 BEGIN SELECT 0 success,'Lembur tidak ditemukan, berbeda perusahaan, atau tidak pending.' message;RETURN;END;
    SELECT 1 success,'Overtime berhasil dihapus' message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_overtime_admin_users_summary
    @adminId VARCHAR(50),@year INT=NULL,@month INT=NULL,@startDate DATE=NULL,@endDate DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@adminId AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(u.role) IN ('ADMIN','HRD') OR UPPER(ci.organization) LIKE '%HRD%' OR UPPER(ci.job_position) LIKE '%DIREKTUR%');
    IF @company_id IS NULL THROW 51718,'Admin/HRD tidak berwenang.',1;
    DECLARE @useRange BIT=CASE WHEN @startDate IS NOT NULL OR @endDate IS NOT NULL THEN 1 ELSE 0 END;
    SELECT u.userid userId,ISNULL(u.name,'Unknown User') name,ISNULL(u.mail,'') email,
      ISNULL(u.phone,'') phone,ISNULL(ci.job_position,ISNULL(u.jobs,'')) jobs,
      COUNT(o.id) totalOvertime,SUM(CASE WHEN o.status='Pending' THEN 1 ELSE 0 END) pendingCount,
      SUM(CASE WHEN o.status='Approved' THEN 1 ELSE 0 END) approvedCount,
      SUM(CASE WHEN o.status='Rejected' THEN 1 ELSE 0 END) rejectedCount,
      ISNULL(SUM(CASE WHEN o.status='Approved' THEN o.total_jam ELSE 0 END),0) totalApprovedHours,
      ISNULL(SUM(o.total_jam),0) totalRequestedHours,
      CAST(ISNULL(SUM(CASE WHEN o.status='Approved' THEN o.total_jam ELSE 0 END),0) AS VARCHAR(30))+' jam' formattedTotalHours
    FROM dbo.udt_overtime o INNER JOIN dbo.udt_users u ON u.userid=o.userid
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=o.userid AND ci.company_id=@company_id
    WHERE o.company_id=@company_id AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND ((@useRange=1 AND (@startDate IS NULL OR o.tanggal_overtime>=@startDate) AND (@endDate IS NULL OR o.tanggal_overtime<=@endDate))
       OR (@useRange=0 AND (@year IS NULL OR YEAR(o.tanggal_overtime)=@year) AND (@month IS NULL OR MONTH(o.tanggal_overtime)=@month)))
    GROUP BY u.userid,u.name,u.mail,u.phone,u.jobs,ci.job_position ORDER BY COUNT(o.id) DESC,u.name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_overtime_admin_export
    @adminId VARCHAR(50),@startDate DATE=NULL,@endDate DATE=NULL,
    @status VARCHAR(20)=NULL,@userId VARCHAR(50)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=ci.company_id FROM dbo.udt_users u INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@adminId AND u.active=1 AND ISNULL(u.deleted,0)=0
      AND (UPPER(u.role) IN ('ADMIN','HRD') OR UPPER(ci.organization) LIKE '%HRD%' OR UPPER(ci.job_position) LIKE '%DIREKTUR%');
    IF @company_id IS NULL THROW 51719,'Admin/HRD tidak berwenang.',1;
    SELECT o.id ID,u.name [Nama Karyawan],u.mail Email,ci.job_position Jabatan,
      CONVERT(VARCHAR,o.tanggal_overtime,105) [Tanggal Overtime],CONVERT(VARCHAR,o.jam_mulai,108) [Jam Mulai],
      CONVERT(VARCHAR,o.jam_selesai,108) [Jam Selesai],o.total_jam [Total Jam],o.catatan Catatan,
      o.status Status,CONVERT(VARCHAR,o.created_at,120) [Tanggal Pengajuan],o.approved_by_name [Disetujui Oleh],
      CONVERT(VARCHAR,o.approved_at,120) [Tanggal Persetujuan],o.rejection_reason [Alasan Penolakan]
    FROM dbo.udt_overtime o INNER JOIN dbo.udt_users u ON u.userid=o.userid
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=o.userid AND ci.company_id=@company_id
    WHERE o.company_id=@company_id AND (@startDate IS NULL OR o.tanggal_overtime>=@startDate)
      AND (@endDate IS NULL OR o.tanggal_overtime<=@endDate) AND (@status IS NULL OR o.status=@status)
      AND (@userId IS NULL OR o.userid=@userId) ORDER BY o.created_at DESC;
END;
GO

/* ========================================================================== */
/* 4. Nomor dokumen lembur berjalan sendiri pada setiap PT                    */
/* ========================================================================== */
IF COL_LENGTH('dbo.udt_overtime_dokumen_nomor','company_id') IS NULL
    ALTER TABLE dbo.udt_overtime_dokumen_nomor ADD company_id INT NULL;
GO
UPDATE d SET company_id=o.company_id FROM dbo.udt_overtime_dokumen_nomor d
INNER JOIN dbo.udt_overtime o ON o.id=d.overtime_id WHERE d.company_id IS NULL;
GO
IF EXISTS(SELECT 1 FROM dbo.udt_overtime_dokumen_nomor WHERE company_id IS NULL)
    THROW 51720,'Masih ada nomor dokumen lembur tanpa company_id.',1;
GO
ALTER TABLE dbo.udt_overtime_dokumen_nomor ALTER COLUMN company_id INT NOT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_overtime_doc_company')
    ALTER TABLE dbo.udt_overtime_dokumen_nomor WITH CHECK ADD CONSTRAINT FK_overtime_doc_company
    FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_overtime_dokumen_nomor') AND name='IX_overtime_doc_company_period')
    CREATE INDEX IX_overtime_doc_company_period ON dbo.udt_overtime_dokumen_nomor(company_id,tahun,bulan,nomor_urut);
GO

CREATE OR ALTER PROCEDURE dbo.udp_overtime_assign_doc_number
    @overtime_id INT,@tanggal_overtime DATE,@nomor_urut INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;SET XACT_ABORT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id,@tanggal_overtime=tanggal_overtime FROM dbo.udt_overtime WHERE id=@overtime_id;
    IF @company_id IS NULL THROW 51721,'Data lembur tidak ditemukan.',1;
    DECLARE @bulan INT=MONTH(@tanggal_overtime),@tahun INT=YEAR(@tanggal_overtime);
    DECLARE @lockResource VARCHAR(100)='overtime_doc_'+CAST(@company_id AS VARCHAR(12))+'_'+CAST(@bulan AS VARCHAR(2))+'_'+CAST(@tahun AS VARCHAR(4));
    BEGIN TRANSACTION;
    EXEC sys.sp_getapplock @Resource=@lockResource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
    IF NOT EXISTS(SELECT 1 FROM dbo.udt_overtime_dokumen_nomor WHERE overtime_id=@overtime_id)
      INSERT dbo.udt_overtime_dokumen_nomor(company_id,overtime_id,bulan,tahun,tanggal_overtime,nomor_urut,exported_at)
      VALUES(@company_id,@overtime_id,@bulan,@tahun,@tanggal_overtime,0,NULL);
    ;WITH numbered AS
    (
      SELECT id,ROW_NUMBER() OVER(ORDER BY tanggal_overtime,created_at,id) rn
      FROM dbo.udt_overtime_dokumen_nomor
      WHERE company_id=@company_id AND bulan=@bulan AND tahun=@tahun AND exported_at IS NULL
    )
    UPDATE d SET nomor_urut=n.rn+ISNULL((SELECT MAX(nomor_urut) FROM dbo.udt_overtime_dokumen_nomor
      WHERE company_id=@company_id AND bulan=@bulan AND tahun=@tahun AND exported_at IS NOT NULL),0)
    FROM dbo.udt_overtime_dokumen_nomor d INNER JOIN numbered n ON n.id=d.id;
    SELECT @nomor_urut=nomor_urut FROM dbo.udt_overtime_dokumen_nomor WHERE overtime_id=@overtime_id;
    COMMIT TRANSACTION;
END;
GO

/* Verifikasi. */
SELECT company_id,status,COUNT(*) total,ISNULL(SUM(total_jam),0) total_jam
FROM dbo.udt_overtime GROUP BY company_id,status ORDER BY company_id,status;
SELECT name,modify_date FROM sys.procedures WHERE name LIKE 'udp_overtime%'
ORDER BY name;
GO
