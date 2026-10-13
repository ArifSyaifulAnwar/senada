/*
  SENADA - Perbaikan routing approval Dinas Luar

  Alur:
  - Karyawan biasa -> Head divisi tujuan -> Head HRD -> Finance (jika ada biaya).
  - Head divisi     -> Head HRD -> Finance (jika ada biaya).
  - Head HRD        -> Finance (jika ada biaya), tanpa self approval.
  - Uang kantor dan reimbursement wajib memilih Finance perusahaan yang sama.
  - Tanpa biaya tidak melalui Finance.
*/
USE [ABSENSI];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.udp_timeoff_resolve_dl_first_approver
    @userId VARCHAR(50),
    @jenisPekerjaan NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @companyId INT;
    SELECT @companyId = company_id
    FROM dbo.udt_company_info_user
    WHERE userid = @userId;

    DECLARE @target NVARCHAR(150) =
        REPLACE(UPPER(LTRIM(RTRIM(ISNULL(@jenisPekerjaan, N'')))), N' ', N'');

    SELECT TOP (1)
        ci.userid AS approver_userid,
        u.name AS approver_name,
        ci.organization AS approver_organization,
        ci.job_position AS approver_position,
        ci.job_level AS approver_level
    FROM dbo.udt_company_info_user ci
    INNER JOIN dbo.udt_users u
        ON u.userid = ci.userid
       AND u.active = 1
       AND ISNULL(u.deleted, 0) = 0
    WHERE ci.company_id = @companyId
      AND ci.userid <> @userId
      AND (
            UPPER(ISNULL(ci.job_position, N'')) LIKE N'%HEAD%'
            OR UPPER(ISNULL(ci.job_level, N'')) = N'HEAD'
          )
      AND (
            REPLACE(UPPER(ISNULL(ci.organization, N'')), N' ', N'') = @target
            OR REPLACE(UPPER(ISNULL(ci.job_position, N'')), N' ', N'') LIKE N'%' + @target + N'%'
          )
    ORDER BY
        CASE
            WHEN REPLACE(UPPER(ISNULL(ci.organization, N'')), N' ', N'') = @target THEN 0
            ELSE 1
        END,
        ci.userid;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_timeoff_submit_with_policy
    @userid VARCHAR(50),
    @jenisTimeoff NVARCHAR(100),
    @tanggalMulai DATE,
    @tanggalSelesai DATE,
    @totalHari INT,
    @catatan NVARCHAR(500) = NULL,
    @filePath NVARCHAR(500) = NULL,
    @fileName NVARCHAR(255) = NULL,
    @fileSize BIGINT = NULL,
    @fileType NVARCHAR(100) = NULL,
    @jenisPekerjaan NVARCHAR(100) = NULL,
    @rabType NVARCHAR(100) = NULL,
    @nominalUangKantor DECIMAL(18,2) = NULL,
    @reimbursementItems NVARCHAR(MAX) = NULL,
    @financeUserId VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @rabType = NULLIF(LOWER(LTRIM(RTRIM(@rabType))), N'');
    SET @financeUserId = NULLIF(LTRIM(RTRIM(@financeUserId)), '');

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @tanggalMulai > @tanggalSelesai
            THROW 50400, 'Tanggal mulai tidak boleh lebih besar dari tanggal selesai.', 1;

        SET @totalHari = DATEDIFF(DAY, @tanggalMulai, @tanggalSelesai) + 1;

        DECLARE @companyId INT, @pengajuOrg NVARCHAR(200),
                @pengajuJobPos NVARCHAR(200), @pengajuJobLevel NVARCHAR(100),
                @pengajuRole VARCHAR(50);

        SELECT TOP (1)
            @companyId = ci.company_id,
            @pengajuOrg = ci.organization,
            @pengajuJobPos = ci.job_position,
            @pengajuJobLevel = ci.job_level,
            @pengajuRole = u.role
        FROM dbo.udt_company_info_user ci
        INNER JOIN dbo.udt_users u ON u.userid = ci.userid
        INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
        WHERE ci.userid = @userid
          AND u.active = 1 AND ISNULL(u.deleted, 0) = 0;

        IF @companyId IS NULL
            THROW 50401, 'User tidak aktif atau belum terdaftar pada perusahaan.', 1;

        DECLARE @policyCode NVARCHAR(50), @usesQuota BIT, @quotaType NVARCHAR(50),
                @requiresDirector BIT, @tahun INT = YEAR(@tanggalMulai), @quotaSisa INT;

        SELECT TOP (1)
            @policyCode = policy_code, @usesQuota = uses_quota,
            @quotaType = quota_type, @requiresDirector = requires_director_approval
        FROM dbo.udt_timeoff_policy
        WHERE jenis_timeoff = @jenisTimeoff AND is_active = 1;

        IF @policyCode IS NULL
            THROW 50402, 'Jenis izin tidak ditemukan di kebijakan HRD.', 1;

        IF ISNULL(@usesQuota, 0) = 1
        BEGIN
            SELECT @quotaSisa = quota_sisa
            FROM dbo.udt_timeoff_user_quota
            WHERE userid = @userid AND tahun = @tahun AND quota_type = @quotaType;
            IF @quotaSisa IS NULL THROW 50403, 'Kuota izin belum disetting HRD.', 1;
            IF @quotaSisa < @totalHari THROW 50404, 'Kuota izin tidak mencukupi.', 1;
        END;

        DECLARE @initialStatus NVARCHAR(30), @initialHrdStatus NVARCHAR(30),
                @initialDirStatus NVARCHAR(30), @managerUserId VARCHAR(50),
                @managerApprovalStatus NVARCHAR(30), @orgTarget NVARCHAR(100),
                @headName NVARCHAR(200), @headJobPosition NVARCHAR(200),
                @pengajuIsHead BIT = 0, @pengajuIsHeadHrd BIT = 0,
                @hrdHeadUserId VARCHAR(50), @hrdHeadName NVARCHAR(200),
                @hrdHeadJobPos NVARCHAR(200);

        IF UPPER(ISNULL(@pengajuJobPos, N'')) LIKE N'%HEAD%'
           OR UPPER(ISNULL(@pengajuJobLevel, N'')) = N'HEAD'
            SET @pengajuIsHead = 1;

        IF @jenisTimeoff = N'Dinas Luar'
        BEGIN
            SET @orgTarget = NULLIF(LTRIM(RTRIM(@jenisPekerjaan)), N'');
            IF @orgTarget IS NULL THROW 50405, 'Divisi tujuan wajib dipilih.', 1;
            IF @rabType NOT IN (N'reimbursement', N'uang_kantor') AND @rabType IS NOT NULL
                THROW 50406, 'Jenis biaya Dinas Luar tidak valid.', 1;

            IF @rabType IS NULL SET @financeUserId = NULL;
            IF @rabType IS NOT NULL
            BEGIN
                IF @financeUserId IS NULL
                    THROW 50407, 'Finance pemeriksa wajib dipilih.', 1;
                IF NOT EXISTS (
                    SELECT 1
                    FROM dbo.udt_company_info_user fci
                    INNER JOIN dbo.udt_users fu ON fu.userid = fci.userid
                    WHERE fci.userid = @financeUserId
                      AND fci.company_id = @companyId
                      AND fu.active = 1 AND ISNULL(fu.deleted, 0) = 0
                      AND (UPPER(ISNULL(fci.organization, N'')) LIKE N'%FINANCE%'
                           OR UPPER(ISNULL(fci.job_position, N'')) LIKE N'%FINANCE%')
                ) THROW 50408, 'Finance tidak aktif atau berasal dari perusahaan lain.', 1;
            END;

            SELECT TOP (1)
                @hrdHeadUserId = ci.userid,
                @hrdHeadName = u.name,
                @hrdHeadJobPos = ci.job_position
            FROM dbo.udt_company_info_user ci
            INNER JOIN dbo.udt_users u ON u.userid = ci.userid
            WHERE ci.company_id = @companyId
              AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
              AND (UPPER(ISNULL(ci.organization, N'')) LIKE N'%HRD%'
                   OR UPPER(ISNULL(ci.job_position, N'')) LIKE N'%HRD%')
              AND (UPPER(ISNULL(ci.job_position, N'')) LIKE N'%HEAD%'
                   OR UPPER(ISNULL(ci.job_level, N'')) = N'HEAD')
            ORDER BY CASE WHEN UPPER(ISNULL(ci.job_position, N'')) LIKE N'%HEAD%HRD%' THEN 0 ELSE 1 END,
                     ci.userid;

            IF @hrdHeadUserId IS NULL THROW 50409, 'Head HRD perusahaan belum dikonfigurasi.', 1;
            IF @userid = @hrdHeadUserId SET @pengajuIsHeadHrd = 1;

            IF @pengajuIsHeadHrd = 1
            BEGIN
                SET @managerApprovalStatus = N'Skipped';
                SET @initialHrdStatus = N'Skipped';
                SET @initialStatus = CASE WHEN @rabType IS NULL THEN N'Menunggu Laporan' ELSE N'Pending Finance' END;
            END
            ELSE IF @pengajuIsHead = 1
            BEGIN
                SET @managerUserId = @hrdHeadUserId;
                SET @headName = @hrdHeadName;
                SET @headJobPosition = @hrdHeadJobPos;
                SET @managerApprovalStatus = N'Pending';
                SET @initialHrdStatus = N'Waiting';
                SET @initialStatus = N'Menunggu Org';
            END
            ELSE
            BEGIN
                CREATE TABLE #HeadApprover
                (approver_userid VARCHAR(50), approver_name NVARCHAR(200),
                 approver_organization NVARCHAR(200), approver_position NVARCHAR(200),
                 approver_level NVARCHAR(100));
                INSERT INTO #HeadApprover
                EXEC dbo.udp_timeoff_resolve_dl_first_approver @userid, @orgTarget;
                SELECT TOP (1) @managerUserId = approver_userid,
                    @headName = approver_name, @headJobPosition = approver_position
                FROM #HeadApprover;
                DROP TABLE #HeadApprover;
                IF @managerUserId IS NULL
                    THROW 50410, 'Head untuk divisi yang dipilih belum dikonfigurasi.', 1;
                SET @managerApprovalStatus = N'Pending';
                SET @initialHrdStatus = N'Waiting';
                SET @initialStatus = N'Menunggu Org';
            END;
        END
        ELSE
        BEGIN
            IF UPPER(ISNULL(@pengajuRole, '')) IN ('HRD', 'ADMIN')
            BEGIN
                SET @initialStatus = CASE WHEN ISNULL(@requiresDirector,0)=1 THEN N'Pending Director' ELSE N'Approved' END;
                SET @initialHrdStatus = N'Skipped';
                SET @initialDirStatus = CASE WHEN ISNULL(@requiresDirector,0)=1 THEN N'Waiting' END;
            END
            ELSE
            BEGIN
                SET @initialStatus = N'Pending HRD'; SET @initialHrdStatus = N'Pending';
                SET @initialDirStatus = CASE WHEN ISNULL(@requiresDirector,0)=1 THEN N'Waiting' END;
            END;
        END;

        IF @initialStatus = N'Approved' AND ISNULL(@usesQuota,0)=1
            UPDATE dbo.udt_timeoff_user_quota
            SET quota_terpakai = quota_terpakai + @totalHari, updated_at = GETDATE()
            WHERE userid=@userid AND tahun=@tahun AND quota_type=@quotaType;

        INSERT dbo.udt_timeoff
        (userid,jenis_timeoff,tanggal_mulai,tanggal_selesai,total_hari,catatan,status,
         created_at,updated_at,file_path,file_name,file_size,file_type,jenis_pekerjaan,
         rab_type,nominal_uang_kantor,policy_code,uses_quota,quota_type,
         requires_director_approval,hrd_approval_status,director_approval_status,
         manager_userid,manager_approval_status,org_target,finance_userid,
         finance_approval_status,quota_deducted,head_name,head_job_position,pengaju_is_head)
        VALUES
        (@userid,@jenisTimeoff,@tanggalMulai,@tanggalSelesai,@totalHari,@catatan,@initialStatus,
         GETDATE(),GETDATE(),@filePath,@fileName,@fileSize,@fileType,@jenisPekerjaan,
         @rabType,@nominalUangKantor,@policyCode,@usesQuota,@quotaType,@requiresDirector,
         @initialHrdStatus,@initialDirStatus,@managerUserId,@managerApprovalStatus,@orgTarget,
         @financeUserId,CASE WHEN @rabType IS NOT NULL THEN N'Pending' END,
         CASE WHEN @initialStatus=N'Approved' AND ISNULL(@usesQuota,0)=1 THEN 1 ELSE 0 END,
         @headName,@headJobPosition,@pengajuIsHead);

        DECLARE @newId INT = CONVERT(INT,SCOPE_IDENTITY());
        IF @initialStatus=N'Approved'
            EXEC dbo.udp_timeoff_attendance_sync @timeoff_id=@newId,@is_reject=0;

        IF @reimbursementItems IS NOT NULL AND LEN(@reimbursementItems)>2
            INSERT dbo.udt_timeoff_reimburse_items(timeoff_id,nama_item,nominal,keterangan)
            SELECT @newId,JSON_VALUE(j.value,'$.nama_item'),
                   ISNULL(TRY_CONVERT(DECIMAL(18,2),JSON_VALUE(j.value,'$.nominal')),0),
                   JSON_VALUE(j.value,'$.keterangan')
            FROM OPENJSON(@reimbursementItems) j
            WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value,'$.nama_item'))),'') IS NOT NULL;

        COMMIT;
        SELECT 1 success,
            CASE @initialStatus
              WHEN N'Menunggu Org' THEN N'Pengajuan berhasil. Menunggu persetujuan ' + ISNULL(@headName,N'Head Divisi') + N'.'
              WHEN N'Pending Finance' THEN N'Pengajuan berhasil. Menunggu persetujuan Finance yang dipilih.'
              WHEN N'Menunggu Laporan' THEN N'Pengajuan disetujui. Silakan upload laporan.'
              ELSE N'Pengajuan berhasil.' END message,
            @newId id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SELECT 0 success,N'Error: '+ERROR_MESSAGE() message,NULL id;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_timeoff_org_review
 @id INT,@reviewer_userid VARCHAR(50),@status VARCHAR(20),@rejection_reason NVARCHAR(500)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @currentStatus NVARCHAR(30),@owner VARCHAR(50),@rabType NVARCHAR(100),
          @finance VARCHAR(50),@companyId INT,@reviewerIsHeadHrd BIT=0,
          @headName NVARCHAR(200),@headJob NVARCHAR(200),@newStatus NVARCHAR(30);
  SELECT @currentStatus=status,@owner=userid,@rabType=rab_type,@finance=finance_userid
  FROM dbo.udt_timeoff WITH(UPDLOCK,HOLDLOCK)
  WHERE id=@id AND jenis_timeoff=N'Dinas Luar' AND manager_userid=@reviewer_userid
    AND manager_approval_status=N'Pending';
  IF @currentStatus IS NULL THROW 50420,'Pengajuan bukan milik approver ini atau sudah diproses.',1;
  IF @currentStatus<>N'Menunggu Org' THROW 50421,'Status pengajuan tidak sesuai.',1;
  IF @status NOT IN ('Approved','Rejected') THROW 50422,'Status approval tidak valid.',1;

  SELECT @companyId=company_id FROM dbo.udt_company_info_user WHERE userid=@owner;
  SELECT @headName=u.name,@headJob=ci.job_position,
         @reviewerIsHeadHrd=CASE WHEN (UPPER(ISNULL(ci.organization,N'')) LIKE N'%HRD%'
              OR UPPER(ISNULL(ci.job_position,N'')) LIKE N'%HRD%')
             AND (UPPER(ISNULL(ci.job_position,N'')) LIKE N'%HEAD%'
              OR UPPER(ISNULL(ci.job_level,N''))=N'HEAD') THEN 1 ELSE 0 END
  FROM dbo.udt_company_info_user ci JOIN dbo.udt_users u ON u.userid=ci.userid
  WHERE ci.userid=@reviewer_userid AND ci.company_id=@companyId
    AND u.active=1 AND ISNULL(u.deleted,0)=0;
  IF @headName IS NULL THROW 50423,'Approver tidak aktif atau berbeda perusahaan.',1;

  IF @status='Rejected'
  BEGIN
   UPDATE dbo.udt_timeoff SET manager_approval_status=N'Rejected',manager_approved_at=GETDATE(),
    manager_rejection_reason=@rejection_reason,status=N'Rejected',rejection_reason=@rejection_reason,
    updated_at=GETDATE() WHERE id=@id;
   COMMIT; SELECT CAST(1 AS BIT) success,N'Pengajuan ditolak.' message,N'Rejected' new_status,
    @rabType rab_type,@finance finance_userid; RETURN;
  END;

  IF @reviewerIsHeadHrd=1
  BEGIN
   /* Kompatibilitas data lama: sebelum form memiliki pilihan Finance. */
   IF @rabType IS NOT NULL AND @finance IS NULL
   BEGIN
    SELECT TOP(1) @finance=ci.userid
    FROM dbo.udt_company_info_user ci
    INNER JOIN dbo.udt_users fu ON fu.userid=ci.userid
    OUTER APPLY
    (
     SELECT COUNT(1) direct_reports
     FROM dbo.udt_company_info_user subordinate
     WHERE subordinate.company_id=ci.company_id
      AND subordinate.manager=ci.userid
      AND UPPER(ISNULL(subordinate.organization,N'')) LIKE N'%FINANCE%'
    ) hierarchy
    WHERE ci.company_id=@companyId
     AND fu.active=1 AND ISNULL(fu.deleted,0)=0
     AND (UPPER(ISNULL(ci.organization,N'')) LIKE N'%FINANCE%'
          OR UPPER(ISNULL(ci.job_position,N'')) LIKE N'%FINANCE%')
    ORDER BY CASE WHEN UPPER(ISNULL(ci.job_position,N'')) LIKE N'%HEAD%'
                       OR UPPER(ISNULL(ci.job_level,N''))=N'HEAD' THEN 0 ELSE 1 END,
             hierarchy.direct_reports DESC,ci.userid;
    IF @finance IS NULL THROW 50424,'Head Finance perusahaan belum dikonfigurasi.',1;
   END;
   SET @newStatus=CASE WHEN @rabType IS NULL THEN N'Menunggu Laporan' ELSE N'Pending Finance' END;
  END
  ELSE SET @newStatus=N'Pending HRD';

  UPDATE dbo.udt_timeoff SET manager_approval_status=N'Approved',manager_approved_at=GETDATE(),
   manager_rejection_reason=NULL,head_name=@headName,head_job_position=@headJob,
   hrd_approval_status=CASE WHEN @reviewerIsHeadHrd=1 THEN N'Approved' ELSE N'Pending' END,
   hrd_approved_by=CASE WHEN @reviewerIsHeadHrd=1 THEN @reviewer_userid END,
   hrd_approved_at=CASE WHEN @reviewerIsHeadHrd=1 THEN GETDATE() END,
   finance_userid=CASE WHEN @reviewerIsHeadHrd=1 AND @rabType IS NOT NULL THEN @finance ELSE finance_userid END,
   finance_approval_status=CASE WHEN @reviewerIsHeadHrd=1 AND @rabType IS NOT NULL THEN N'Pending' ELSE finance_approval_status END,
   status=@newStatus,updated_at=GETDATE() WHERE id=@id;
  COMMIT;
  SELECT CAST(1 AS BIT) success,
   CASE WHEN @newStatus=N'Pending HRD' THEN N'Disetujui Head Divisi. Menunggu Head HRD.'
        WHEN @newStatus=N'Pending Finance' THEN N'Disetujui Head HRD. Menunggu Finance yang dipilih.'
        ELSE N'Disetujui Head HRD. Silakan upload laporan.' END message,
   @newStatus new_status,@rabType rab_type,@finance finance_userid;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  SELECT CAST(0 AS BIT) success,N'Error: '+ERROR_MESSAGE() message,NULL new_status,NULL rab_type,NULL finance_userid;
 END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_timeoff_finance_review
 @id INT,@finance_userid VARCHAR(50),@status VARCHAR(20),@rejection_reason NVARCHAR(500)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @current NVARCHAR(30),@assigned VARCHAR(50),@owner VARCHAR(50),@companyId INT,
          @laporanStatus NVARCHAR(30),@laporanHrdStatus NVARCHAR(30),@nextStatus NVARCHAR(30);
  SELECT @current=status,@assigned=finance_userid,@owner=userid,
         @laporanStatus=laporan_status,@laporanHrdStatus=laporan_hrd_status
  FROM dbo.udt_timeoff WITH(UPDLOCK,HOLDLOCK)
  WHERE id=@id AND jenis_timeoff=N'Dinas Luar';
  IF @current IS NULL THROW 50430,'Pengajuan Dinas Luar tidak ditemukan.',1;
  IF @current<>N'Pending Finance' THROW 50431,'Pengajuan belum berada pada tahap Finance.',1;
  IF @assigned<>@finance_userid THROW 50432,'Pengajuan ini ditujukan kepada Finance lain.',1;
  SELECT @companyId=company_id FROM dbo.udt_company_info_user WHERE userid=@owner;
  IF NOT EXISTS(SELECT 1 FROM dbo.udt_company_info_user ci JOIN dbo.udt_users u ON u.userid=ci.userid
     WHERE ci.userid=@finance_userid AND ci.company_id=@companyId AND u.active=1
       AND ISNULL(u.deleted,0)=0 AND (UPPER(ISNULL(ci.organization,N'')) LIKE N'%FINANCE%'
       OR UPPER(ISNULL(ci.job_position,N'')) LIKE N'%FINANCE%'))
   THROW 50433,'Finance tidak aktif atau berbeda perusahaan.',1;
  IF @status NOT IN('Approved','Rejected') THROW 50434,'Status approval tidak valid.',1;
  IF @status='Rejected'
   UPDATE dbo.udt_timeoff SET finance_approval_status=N'Rejected',finance_approved_by=@finance_userid,
    finance_approved_at=GETDATE(),finance_rejection_reason=@rejection_reason,status=N'Revisi',
    rejection_reason=@rejection_reason,updated_at=GETDATE() WHERE id=@id;
  ELSE
  BEGIN
   /* Data legacy mungkin sudah menyelesaikan laporan sebelum tahap Finance tersedia. */
   SET @nextStatus=CASE
    WHEN @laporanStatus=N'Submitted' AND @laporanHrdStatus=N'Approved' THEN N'Menunggu Transfer'
    ELSE N'Menunggu Laporan'
   END;
   UPDATE dbo.udt_timeoff SET finance_approval_status=N'Approved',finance_approved_by=@finance_userid,
    finance_approved_at=GETDATE(),finance_rejection_reason=NULL,status=@nextStatus,updated_at=GETDATE()
   WHERE id=@id;
  END;
  COMMIT;
  SELECT 1 success,CASE WHEN @status='Approved' AND @nextStatus=N'Menunggu Transfer'
   THEN N'Disetujui Finance. Silakan upload bukti transfer pembayaran.'
   WHEN @status='Approved' THEN N'Disetujui Finance. Laporan sekarang dapat diunggah.'
   ELSE N'Dikembalikan untuk revisi keuangan.' END message;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  SELECT 0 success,N'Error: '+ERROR_MESSAGE() message;
 END CATCH;
END;
GO

/* ========================================================================== */
/* VERIFIKASI LAPORAN HRD: data legacy berbiaya tetap wajib melewati Finance */
/* ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.udp_timeoff_dl_hrd_verify_laporan
 @id INT,@hrd_userid VARCHAR(50),@status VARCHAR(20),@rejection_reason NVARCHAR(500)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @current NVARCHAR(30),@owner VARCHAR(50),@companyId INT,@rabType NVARCHAR(100),
          @finance VARCHAR(50),@financeStatus NVARCHAR(30),@nextStatus NVARCHAR(30);

  SELECT @current=t.status,@owner=t.userid,@rabType=NULLIF(LTRIM(RTRIM(t.rab_type)),''),
         @finance=NULLIF(LTRIM(RTRIM(t.finance_userid)),''),@financeStatus=t.finance_approval_status
  FROM dbo.udt_timeoff t WITH(UPDLOCK,HOLDLOCK)
  WHERE t.id=@id AND t.jenis_timeoff=N'Dinas Luar';

  IF @current IS NULL THROW 50460,'Pengajuan Dinas Luar tidak ditemukan.',1;
  IF @current<>N'Pending Laporan HRD' THROW 50461,'Laporan belum berada pada tahap verifikasi HRD.',1;
  SELECT TOP(1) @companyId=company_id FROM dbo.udt_company_info_user WHERE userid=@owner;

  IF NOT EXISTS(
   SELECT 1 FROM dbo.udt_company_info_user ci
   JOIN dbo.udt_users u ON u.userid=ci.userid
   WHERE ci.userid=@hrd_userid AND ci.company_id=@companyId
    AND u.active=1 AND ISNULL(u.deleted,0)=0
    AND (UPPER(ISNULL(ci.organization,N'')) LIKE N'%HRD%'
         OR UPPER(ISNULL(ci.job_position,N'')) LIKE N'%HRD%')
    AND (UPPER(ISNULL(ci.job_position,N'')) LIKE N'%HEAD%'
         OR UPPER(ISNULL(ci.job_level,N''))=N'HEAD'))
   THROW 50462,'Verifikasi laporan hanya dapat dilakukan Head HRD perusahaan yang sama.',1;

  IF @status NOT IN('Approved','Rejected') THROW 50463,'Status verifikasi tidak valid.',1;
  IF @status='Rejected'
  BEGIN
   UPDATE dbo.udt_timeoff SET laporan_hrd_status=N'Rejected',laporan_hrd_approved_by=@hrd_userid,
    laporan_hrd_approved_at=GETDATE(),laporan_hrd_rejection=@rejection_reason,
    laporan_hrd_approval_status=N'Rejected',laporan_hrd_rejection_reason=@rejection_reason,
    status=N'Laporan Ditolak',updated_at=GETDATE() WHERE id=@id;
   COMMIT;
   SELECT 1 success,N'Laporan ditolak oleh HRD.' message;
   RETURN;
  END;

  IF @rabType IS NOT NULL AND ISNULL(@financeStatus,'')<>N'Approved'
  BEGIN
   IF @finance IS NULL
   BEGIN
    SELECT TOP(1) @finance=ci.userid
    FROM dbo.udt_company_info_user ci
    JOIN dbo.udt_users u ON u.userid=ci.userid
    OUTER APPLY(
     SELECT COUNT(1) direct_reports
     FROM dbo.udt_company_info_user subordinate
     WHERE subordinate.company_id=ci.company_id AND subordinate.manager=ci.userid
    ) hierarchy
    WHERE ci.company_id=@companyId AND u.active=1 AND ISNULL(u.deleted,0)=0
     AND (UPPER(ISNULL(ci.organization,N'')) LIKE N'%FINANCE%'
          OR UPPER(ISNULL(ci.job_position,N'')) LIKE N'%FINANCE%')
    ORDER BY CASE WHEN UPPER(ISNULL(ci.job_position,N'')) LIKE N'%HEAD%'
                       OR UPPER(ISNULL(ci.job_level,N''))=N'HEAD' THEN 0 ELSE 1 END,
             hierarchy.direct_reports DESC,ci.userid;
   END;
   IF @finance IS NULL THROW 50464,'Head Finance perusahaan belum dikonfigurasi.',1;
   SET @nextStatus=N'Pending Finance';
  END
  ELSE IF @rabType IS NOT NULL SET @nextStatus=N'Menunggu Transfer';
  ELSE SET @nextStatus=N'Approved';

  UPDATE dbo.udt_timeoff SET laporan_hrd_status=N'Approved',laporan_hrd_approved_by=@hrd_userid,
   laporan_hrd_approved_at=GETDATE(),laporan_hrd_rejection=NULL,
   laporan_hrd_approval_status=N'Approved',laporan_hrd_rejection_reason=NULL,
   finance_userid=CASE WHEN @nextStatus=N'Pending Finance' THEN @finance ELSE finance_userid END,
   finance_approval_status=CASE WHEN @nextStatus=N'Pending Finance' THEN N'Pending' ELSE finance_approval_status END,
   status=@nextStatus,updated_at=GETDATE()
  WHERE id=@id;

  COMMIT;
  SELECT 1 success,CASE WHEN @nextStatus=N'Pending Finance'
   THEN N'Laporan disetujui HRD. Menunggu persetujuan Finance.'
   WHEN @nextStatus=N'Menunggu Transfer'
   THEN N'Laporan disetujui HRD. Menunggu Finance mengupload bukti transfer.'
   ELSE N'Laporan disetujui HRD. Dinas Luar selesai.' END message;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  SELECT 0 success,N'Error: '+ERROR_MESSAGE() message;
 END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_timeoff_hrd_review
 @id INT,@status VARCHAR(20),@hrdUserId VARCHAR(50),@rejectionReason NVARCHAR(500)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @current NVARCHAR(30),@jenis NVARCHAR(100),@owner VARCHAR(50),
   @requiresDirector BIT,@usesQuota BIT,@quotaType NVARCHAR(50),@totalHari INT,
   @tahun INT,@rabType NVARCHAR(100),@finance VARCHAR(50),@companyId INT;
  SELECT @current=status,@jenis=jenis_timeoff,@owner=userid,
   @requiresDirector=requires_director_approval,@usesQuota=uses_quota,@quotaType=quota_type,
   @totalHari=total_hari,@tahun=YEAR(tanggal_mulai),@rabType=rab_type,@finance=finance_userid
  FROM dbo.udt_timeoff WITH(UPDLOCK,HOLDLOCK) WHERE id=@id;
  IF @current IS NULL THROW 50440,'Pengajuan tidak ditemukan.',1;
  IF @current<>N'Pending HRD' THROW 50441,'Pengajuan belum berada pada tahap Head HRD.',1;

  IF EXISTS
  (
   SELECT 1
   FROM dbo.udt_timeoff
   WHERE id=@id
     AND manager_userid=@hrdUserId
     AND manager_approval_status=N'Approved'
  ) THROW 50445,'Approver tahap pertama tidak boleh menyetujui tahap Head HRD.',1;

  SELECT @companyId=company_id FROM dbo.udt_company_info_user WHERE userid=@owner;
  IF NOT EXISTS(
   SELECT 1 FROM dbo.udt_company_info_user ci
   INNER JOIN dbo.udt_users u ON u.userid=ci.userid
   WHERE ci.userid=@hrdUserId AND ci.company_id=@companyId
    AND u.active=1 AND ISNULL(u.deleted,0)=0
    AND (UPPER(ISNULL(ci.organization,N'')) LIKE N'%HRD%'
         OR UPPER(ISNULL(ci.job_position,N'')) LIKE N'%HRD%')
    AND (UPPER(ISNULL(ci.job_position,N'')) LIKE N'%HEAD%'
         OR UPPER(ISNULL(ci.job_level,N''))=N'HEAD')
  ) THROW 50442,'Hanya Head HRD aktif dari perusahaan yang sama yang dapat menyetujui.',1;

  IF @status NOT IN('Approved','Rejected') THROW 50443,'Status approval tidak valid.',1;
  IF @status='Rejected'
  BEGIN
   UPDATE dbo.udt_timeoff SET status=CASE WHEN @jenis=N'Dinas Luar' THEN N'Revisi' ELSE N'Rejected' END,
    hrd_approval_status=N'Rejected',hrd_approved_by=@hrdUserId,hrd_approved_at=GETDATE(),
    hrd_rejection_reason=@rejectionReason,rejection_reason=@rejectionReason,updated_at=GETDATE()
   WHERE id=@id;
   COMMIT; SELECT 1 success,CASE WHEN @jenis=N'Dinas Luar' THEN N'Dikembalikan untuk revisi.'
    ELSE N'Pengajuan ditolak HRD.' END message; RETURN;
  END;

  IF @jenis=N'Dinas Luar'
  BEGIN
   IF @rabType IS NOT NULL AND @finance IS NULL
   BEGIN
    /* Kompatibilitas data lama yang dibuat sebelum Finance bisa dipilih. */
    SELECT TOP(1) @finance=ci.userid
    FROM dbo.udt_company_info_user ci
    INNER JOIN dbo.udt_users fu ON fu.userid=ci.userid
    OUTER APPLY
    (
     SELECT COUNT(1) direct_reports
     FROM dbo.udt_company_info_user subordinate
     WHERE subordinate.company_id=ci.company_id
      AND subordinate.manager=ci.userid
      AND UPPER(ISNULL(subordinate.organization,N'')) LIKE N'%FINANCE%'
    ) hierarchy
    WHERE ci.company_id=@companyId
     AND fu.active=1 AND ISNULL(fu.deleted,0)=0
     AND (UPPER(ISNULL(ci.organization,N'')) LIKE N'%FINANCE%'
          OR UPPER(ISNULL(ci.job_position,N'')) LIKE N'%FINANCE%')
    ORDER BY CASE WHEN UPPER(ISNULL(ci.job_position,N'')) LIKE N'%HEAD%'
                       OR UPPER(ISNULL(ci.job_level,N''))=N'HEAD' THEN 0 ELSE 1 END,
             hierarchy.direct_reports DESC,ci.userid;
    IF @finance IS NULL THROW 50444,'Head Finance perusahaan belum dikonfigurasi.',1;
   END;
   DECLARE @newStatus NVARCHAR(30)=CASE WHEN @rabType IS NULL THEN N'Menunggu Laporan' ELSE N'Pending Finance' END;
   UPDATE dbo.udt_timeoff SET status=@newStatus,hrd_approval_status=N'Approved',
    hrd_approved_by=@hrdUserId,hrd_approved_at=GETDATE(),hrd_rejection_reason=NULL,
    finance_userid=CASE WHEN @rabType IS NOT NULL THEN @finance ELSE NULL END,
    finance_approval_status=CASE WHEN @rabType IS NOT NULL THEN N'Pending' END,
    updated_at=GETDATE() WHERE id=@id;
   COMMIT; SELECT 1 success,CASE WHEN @newStatus=N'Pending Finance'
    THEN N'Disetujui Head HRD. Menunggu Finance yang dipilih.'
    ELSE N'Disetujui Head HRD. Silakan upload laporan.' END message; RETURN;
  END;

  IF ISNULL(@requiresDirector,0)=1
   UPDATE dbo.udt_timeoff SET status=N'Pending Director',hrd_approval_status=N'Approved',
    hrd_approved_by=@hrdUserId,hrd_approved_at=GETDATE(),updated_at=GETDATE() WHERE id=@id;
  ELSE
  BEGIN
   UPDATE dbo.udt_timeoff SET status=N'Approved',hrd_approval_status=N'Approved',
    hrd_approved_by=@hrdUserId,hrd_approved_at=GETDATE(),approved_by=@hrdUserId,
    approved_at=GETDATE(),updated_at=GETDATE() WHERE id=@id;
   IF ISNULL(@usesQuota,0)=1
   BEGIN
    UPDATE dbo.udt_timeoff_user_quota SET quota_terpakai=quota_terpakai+@totalHari,
     updated_at=GETDATE() WHERE userid=@owner AND tahun=@tahun AND quota_type=@quotaType;
    UPDATE dbo.udt_timeoff SET quota_deducted=1 WHERE id=@id;
   END;
   EXEC dbo.udp_timeoff_attendance_sync @timeoff_id=@id,@is_reject=0;
  END;
  COMMIT; SELECT 1 success,CASE WHEN ISNULL(@requiresDirector,0)=1
   THEN N'Disetujui HRD. Menunggu Direktur.' ELSE N'Pengajuan disetujui.' END message;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  SELECT 0 success,N'Error: '+ERROR_MESSAGE() message;
 END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_timeoff_get_pending_hrd_verify
 @hrd_userid VARCHAR(50)
AS
BEGIN
 SET NOCOUNT ON;

 DECLARE @companyId INT;
 SELECT TOP(1) @companyId=ci.company_id
 FROM dbo.udt_company_info_user ci
 INNER JOIN dbo.udt_users u ON u.userid=ci.userid
 WHERE ci.userid=@hrd_userid
  AND u.active=1 AND ISNULL(u.deleted,0)=0
  AND (UPPER(ISNULL(ci.organization,N'')) LIKE N'%HRD%'
       OR UPPER(ISNULL(ci.job_position,N'')) LIKE N'%HRD%')
  AND (UPPER(ISNULL(ci.job_position,N'')) LIKE N'%HEAD%'
       OR UPPER(ISNULL(ci.job_level,N''))=N'HEAD');

 SELECT t.id,t.userid,ISNULL(emp.name,ISNULL(u.name,'')) user_name,
  ISNULL(emp.job_position,'') user_job,t.jenis_timeoff,t.tanggal_mulai,
  t.tanggal_selesai,t.total_hari,t.catatan,t.status,t.created_at,
  t.jenis_pekerjaan,t.rab_type,t.nominal_uang_kantor,t.org_target,
  t.laporan_file_name,t.anggaran_file_name,t.head_name,
  CASE WHEN t.status=N'Pending HRD' THEN DATEDIFF(DAY,t.created_at,GETDATE())
       ELSE ISNULL(DATEDIFF(DAY,t.laporan_submitted_at,GETDATE()),0) END days_waiting
 FROM dbo.udt_timeoff t
 LEFT JOIN dbo.udt_users u ON u.userid=t.userid
 INNER JOIN dbo.udt_company_info_user emp
  ON emp.userid=t.userid AND emp.company_id=@companyId
 WHERE @companyId IS NOT NULL
  AND t.jenis_timeoff=N'Dinas Luar'
  AND t.status IN(N'Pending HRD',N'Menunggu Verifikasi HRD',N'Pending Laporan HRD')
  /* Tahap kedua tidak pernah boleh kembali kepada approver tahap pertama. */
  AND NOT(t.status=N'Pending HRD' AND t.manager_userid=@hrd_userid)
 ORDER BY t.created_at ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_timeoff_get_pending_finance
 @finance_userid VARCHAR(50)
AS
BEGIN
 SET NOCOUNT ON;
 SELECT t.id,t.userid,ISNULL(emp.name,ISNULL(u.name,'')) user_name,
  ISNULL(emp.job_position,'') user_job,t.jenis_timeoff,t.tanggal_mulai,t.tanggal_selesai,
  t.total_hari,t.catatan,t.status,t.created_at,t.jenis_pekerjaan,t.rab_type,
  t.nominal_uang_kantor,t.org_target,t.file_name,t.file_size,t.file_type,
  t.manager_userid,t.manager_approval_status,t.hrd_approval_status,t.hrd_approved_by,
  t.hrd_approved_at,t.finance_userid,t.finance_approval_status,
  DATEDIFF(DAY,t.created_at,GETDATE()) days_waiting
 FROM dbo.udt_timeoff t
 LEFT JOIN dbo.udt_users u ON u.userid=t.userid
 LEFT JOIN dbo.udt_company_info_user emp ON emp.userid=t.userid
 WHERE t.jenis_timeoff=N'Dinas Luar' AND t.status=N'Pending Finance'
   AND t.finance_approval_status=N'Pending' AND t.finance_userid=@finance_userid
 ORDER BY t.created_at DESC;
END;
GO

SELECT p.name procedure_name,p.modify_date
FROM sys.procedures p
WHERE p.name IN('udp_timeoff_resolve_dl_first_approver','udp_timeoff_submit_with_policy',
 'udp_timeoff_org_review','udp_timeoff_hrd_review','udp_timeoff_finance_review',
 'udp_timeoff_dl_hrd_verify_laporan','udp_timeoff_get_pending_finance',
 'udp_timeoff_get_pending_hrd_verify')
ORDER BY p.name;
GO
