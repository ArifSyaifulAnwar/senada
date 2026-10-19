/*
  SENADA - Mapping lokasi dan halaman persetujuan per perusahaan

  Hasil:
  - pengajuan absen luar radius menyimpan company_id milik user;
  - Head HRD hanya melihat/memproses pengajuan dari PT sendiri;
  - PT yang belum memiliki lokasi aktif tetap masuk alur luar radius;
  - daftar persetujuan Dinas Luar dan Asset dikunci ke company_id viewer.

  Jalankan setelah 014_scope_live_attendance_office_by_company.sql.
*/

USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

/* ========================================================================== */
/* 1. Tenant permanen pada pengajuan luar radius                              */
/* ========================================================================== */
IF COL_LENGTH('dbo.udt_attendance_outside_radius', 'company_id') IS NULL
    ALTER TABLE dbo.udt_attendance_outside_radius ADD company_id INT NULL;
GO

UPDATE r
SET r.company_id = ci.company_id
FROM dbo.udt_attendance_outside_radius r
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = r.user_id
WHERE r.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.udt_attendance_outside_radius WHERE company_id IS NULL)
    THROW 51600, 'Masih ada pengajuan luar radius tanpa company_id.', 1;
GO

ALTER TABLE dbo.udt_attendance_outside_radius
    ALTER COLUMN company_id INT NOT NULL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_attendance_outside_radius_company'
)
    ALTER TABLE dbo.udt_attendance_outside_radius WITH CHECK
    ADD CONSTRAINT FK_attendance_outside_radius_company
        FOREIGN KEY(company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.udt_attendance_outside_radius')
      AND name = 'IX_attendance_outside_radius_company_status'
)
    CREATE INDEX IX_attendance_outside_radius_company_status
        ON dbo.udt_attendance_outside_radius(company_id, status, submitted_at)
        INCLUDE(user_id, attendance_type, nearest_office_id);
GO

CREATE OR ALTER TRIGGER dbo.trg_attendance_outside_radius_company_guard
ON dbo.udt_attendance_outside_radius
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user ci ON ci.userid = i.user_id
        WHERE ci.company_id IS NULL OR ci.company_id <> i.company_id
    )
        THROW 51601, 'Perusahaan pengajuan tidak sesuai dengan pemilik akun.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_office_locations o ON o.id = i.nearest_office_id
        WHERE i.nearest_office_id IS NOT NULL
          AND (o.company_id IS NULL OR o.company_id <> i.company_id)
    )
        THROW 51602, 'Lokasi kantor berasal dari perusahaan lain.', 1;
END;
GO

/* ========================================================================== */
/* 2. Submit: company_id selalu diturunkan dari user                           */
/* ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.udp_attendance_outside_radius_submit
    @user_id              VARCHAR(50),
    @attendance_type      VARCHAR(20),
    @latitude             DECIMAL(10,7),
    @longitude            DECIMAL(10,7),
    @distance_from_office DECIMAL(10,2) = NULL,
    @nearest_office_id    INT = NULL,
    @face_image           VARBINARY(MAX) = NULL,
    @det_score            DECIMAL(5,4) = NULL,
    @liveness_score       DECIMAL(5,4) = NULL,
    @best_distance        DECIMAL(5,4) = NULL,
    @result_code          INT OUTPUT,
    @result_message       NVARCHAR(500) OUTPUT,
    @request_id           INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @user_id = NULLIF(LTRIM(RTRIM(@user_id)), '');
    SET @attendance_type = LOWER(NULLIF(LTRIM(RTRIM(@attendance_type)), ''));
    SET @request_id = NULL;

    DECLARE @company_id INT;
    SELECT TOP (1) @company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
    WHERE u.userid = @user_id
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    IF @company_id IS NULL
    BEGIN
        SET @result_code = -10;
        SET @result_message = N'User tidak aktif atau belum terhubung ke perusahaan.';
        RETURN;
    END;

    IF @attendance_type NOT IN ('checkin', 'checkout')
    BEGIN
        SET @result_code = -11;
        SET @result_message = N'Jenis absensi tidak valid.';
        RETURN;
    END;

    IF @nearest_office_id IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1 FROM dbo.udt_office_locations
           WHERE id = @nearest_office_id
             AND company_id = @company_id
             AND is_active = 1
       )
    BEGIN
        SET @result_code = -12;
        SET @result_message = N'Lokasi kantor tidak sesuai dengan perusahaan user.';
        RETURN;
    END;

    IF EXISTS
    (
        SELECT 1 FROM dbo.udt_attendance_outside_radius
        WHERE company_id = @company_id
          AND user_id = @user_id
          AND attendance_type = @attendance_type
          AND status = 'Pending'
          AND CONVERT(DATE, submitted_at) = CONVERT(DATE, GETDATE())
    )
    BEGIN
        SET @result_code = -1;
        SET @result_message = N'Anda sudah memiliki pengajuan luar radius yang menunggu Head HRD.';
        RETURN;
    END;

    IF @attendance_type = 'checkin' AND EXISTS
    (
        SELECT 1 FROM dbo.udt_attendance
        WHERE user_id = @user_id
          AND attendance_date = CONVERT(DATE, GETDATE())
          AND check_in_time IS NOT NULL
    )
    BEGIN
        SET @result_code = -2;
        SET @result_message = N'Anda sudah melakukan check in hari ini.';
        RETURN;
    END;

    IF @attendance_type = 'checkout' AND EXISTS
    (
        SELECT 1 FROM dbo.udt_attendance
        WHERE user_id = @user_id
          AND attendance_date = CONVERT(DATE, GETDATE())
          AND check_out_time IS NOT NULL
    )
    BEGIN
        SET @result_code = -3;
        SET @result_message = N'Anda sudah melakukan check out hari ini.';
        RETURN;
    END;

    INSERT INTO dbo.udt_attendance_outside_radius
    (
        company_id, user_id, attendance_type, latitude, longitude,
        distance_from_office, nearest_office_id, face_image,
        det_score, liveness_score, best_distance, status, submitted_at
    )
    VALUES
    (
        @company_id, @user_id, @attendance_type, @latitude, @longitude,
        @distance_from_office, @nearest_office_id, @face_image,
        @det_score, @liveness_score, @best_distance, 'Pending', GETDATE()
    );

    SET @request_id = CONVERT(INT, SCOPE_IDENTITY());
    SET @result_code = 1;
    SET @result_message = N'Absensi luar radius berhasil diajukan, menunggu persetujuan Head HRD.';
END;
GO

/* ========================================================================== */
/* 3. List: viewer hanya dapat membaca PT sendiri                              */
/* ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.udp_attendance_outside_radius_list
    @viewer_user_id VARCHAR(50),
    @status         VARCHAR(20) = NULL,
    @user_id        VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company_id INT;
    DECLARE @is_head_hrd BIT = 0;

    SELECT TOP (1)
        @company_id = ci.company_id,
        @is_head_hrd = CASE
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%'
             AND (UPPER(ISNULL(ci.job_position, '')) LIKE '%HEAD%'
                  OR UPPER(ISNULL(ci.job_level, '')) = 'HEAD')
            THEN 1 ELSE 0 END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    WHERE u.userid = @viewer_user_id
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    IF @company_id IS NULL
        THROW 51603, 'Viewer tidak aktif atau belum terhubung ke perusahaan.', 1;

    SELECT
        r.id,
        r.user_id,
        u.name AS user_name,
        u.mail AS user_email,
        r.attendance_type,
        r.latitude,
        r.longitude,
        r.distance_from_office,
        r.nearest_office_id,
        o.office_name AS nearest_office_name,
        r.det_score,
        r.liveness_score,
        r.best_distance,
        r.status,
        r.submitted_at,
        r.reviewed_by,
        r.reviewed_at,
        r.review_notes,
        r.linked_attendance_id
    FROM dbo.udt_attendance_outside_radius r
    INNER JOIN dbo.udt_users u ON u.userid = r.user_id
    LEFT JOIN dbo.udt_office_locations o
        ON o.id = r.nearest_office_id
       AND o.company_id = r.company_id
    WHERE r.company_id = @company_id
      AND (@status IS NULL OR r.status = @status)
      AND
      (
          (@is_head_hrd = 1 AND (@user_id IS NULL OR r.user_id = @user_id))
          OR
          (@is_head_hrd = 0 AND r.user_id = @viewer_user_id)
      )
    ORDER BY r.submitted_at DESC;
END;
GO

/* ========================================================================== */
/* 4. Approve/reject: actor dan pengaju wajib satu perusahaan                  */
/* ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.udp_attendance_outside_radius_approve
    @id             INT,
    @reviewed_by    VARCHAR(50),
    @review_notes   NVARCHAR(500) = NULL,
    @result_code    INT OUTPUT,
    @result_message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @reviewer_company_id INT;
        SELECT TOP (1) @reviewer_company_id = ci.company_id
        FROM dbo.udt_users u
        INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
        WHERE u.userid = @reviewed_by
          AND u.active = 1
          AND ISNULL(u.deleted, 0) = 0
          AND UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%'
          AND (UPPER(ISNULL(ci.job_position, '')) LIKE '%HEAD%'
               OR UPPER(ISNULL(ci.job_level, '')) = 'HEAD');

        IF @reviewer_company_id IS NULL
        BEGIN
            SET @result_code = -2;
            SET @result_message = N'Hanya Head HRD aktif yang dapat menyetujui pengajuan.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        DECLARE
            @user_id VARCHAR(50),
            @attendance_type VARCHAR(20),
            @latitude DECIMAL(10,7),
            @longitude DECIMAL(10,7),
            @office_id INT,
            @face_conf DECIMAL(5,4),
            @submitted_at DATETIME;

        SELECT
            @user_id = r.user_id,
            @attendance_type = r.attendance_type,
            @latitude = r.latitude,
            @longitude = r.longitude,
            @office_id = r.nearest_office_id,
            @face_conf = r.det_score,
            @submitted_at = r.submitted_at
        FROM dbo.udt_attendance_outside_radius r WITH (UPDLOCK, ROWLOCK)
        WHERE r.id = @id
          AND r.company_id = @reviewer_company_id
          AND r.status = 'Pending';

        IF @user_id IS NULL
        BEGIN
            SET @result_code = -4;
            SET @result_message = N'Pengajuan tidak ditemukan, berbeda perusahaan, atau sudah diproses.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        DECLARE @attendance_date DATE = CONVERT(DATE, @submitted_at);
        DECLARE @attendance_id INT;
        DECLARE @approval_note NVARCHAR(500) =
            N'Disetujui Head HRD (' + @reviewed_by + N') - Absen Luar Radius'
            + CASE WHEN NULLIF(LTRIM(RTRIM(@review_notes)), '') IS NOT NULL
                   THEN N': ' + @review_notes ELSE N'' END;

        IF EXISTS
        (
            SELECT 1 FROM dbo.udt_attendance
            WHERE user_id = @user_id AND attendance_date = @attendance_date
        )
        BEGIN
            IF @attendance_type = 'checkin'
                UPDATE dbo.udt_attendance
                SET check_in_time = @submitted_at,
                    check_in_latitude = @latitude,
                    check_in_longitude = @longitude,
                    check_in_office_id = @office_id,
                    check_in_status = 'Luar Radius - Disetujui Head HRD',
                    check_in_face_confidence = @face_conf,
                    attendance_mode = 'outside_radius',
                    notes = ISNULL(notes + ' | ', '') + @approval_note,
                    updated_at = GETDATE()
                WHERE user_id = @user_id AND attendance_date = @attendance_date;
            ELSE
                UPDATE dbo.udt_attendance
                SET check_out_time = @submitted_at,
                    check_out_latitude = @latitude,
                    check_out_longitude = @longitude,
                    check_out_office_id = @office_id,
                    check_out_status = 'Luar Radius - Disetujui Head HRD',
                    check_out_face_confidence = @face_conf,
                    working_hours_minutes = CASE
                        WHEN check_in_time IS NULL THEN working_hours_minutes
                        ELSE DATEDIFF(MINUTE, check_in_time, @submitted_at)
                    END,
                    attendance_mode = 'outside_radius',
                    notes = ISNULL(notes + ' | ', '') + @approval_note,
                    updated_at = GETDATE()
                WHERE user_id = @user_id AND attendance_date = @attendance_date;

            SELECT @attendance_id = id
            FROM dbo.udt_attendance
            WHERE user_id = @user_id AND attendance_date = @attendance_date;
        END
        ELSE
        BEGIN
            IF @attendance_type = 'checkin'
                INSERT INTO dbo.udt_attendance
                (
                    user_id, attendance_date, check_in_time,
                    check_in_latitude, check_in_longitude, check_in_office_id,
                    check_in_status, check_in_face_confidence,
                    attendance_mode, notes, created_at, updated_at
                )
                VALUES
                (
                    @user_id, @attendance_date, @submitted_at,
                    @latitude, @longitude, @office_id,
                    'Luar Radius - Disetujui Head HRD', @face_conf,
                    'outside_radius', @approval_note, GETDATE(), GETDATE()
                );
            ELSE
                INSERT INTO dbo.udt_attendance
                (
                    user_id, attendance_date, check_out_time,
                    check_out_latitude, check_out_longitude, check_out_office_id,
                    check_out_status, check_out_face_confidence,
                    attendance_mode, notes, created_at, updated_at
                )
                VALUES
                (
                    @user_id, @attendance_date, @submitted_at,
                    @latitude, @longitude, @office_id,
                    'Luar Radius - Disetujui Head HRD', @face_conf,
                    'outside_radius', @approval_note, GETDATE(), GETDATE()
                );

            SET @attendance_id = CONVERT(INT, SCOPE_IDENTITY());
        END;

        UPDATE dbo.udt_attendance_outside_radius
        SET status = 'Approved',
            reviewed_by = @reviewed_by,
            reviewed_at = GETDATE(),
            review_notes = @review_notes,
            linked_attendance_id = @attendance_id
        WHERE id = @id
          AND company_id = @reviewer_company_id
          AND status = 'Pending';

        SET @result_code = 1;
        SET @result_message = N'Absensi luar radius berhasil disetujui dan tercatat.';
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @result_code = -99;
        SET @result_message = N'Terjadi kesalahan: ' + ERROR_MESSAGE();
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_attendance_outside_radius_reject
    @id             INT,
    @reviewed_by    VARCHAR(50),
    @review_notes   NVARCHAR(500) = NULL,
    @result_code    INT OUTPUT,
    @result_message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @reviewer_company_id INT;
    SELECT TOP (1) @reviewer_company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    WHERE u.userid = @reviewed_by
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0
      AND UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%'
      AND (UPPER(ISNULL(ci.job_position, '')) LIKE '%HEAD%'
           OR UPPER(ISNULL(ci.job_level, '')) = 'HEAD');

    IF @reviewer_company_id IS NULL
    BEGIN
        SET @result_code = -2;
        SET @result_message = N'Hanya Head HRD aktif yang dapat menolak pengajuan.';
        RETURN;
    END;

    UPDATE dbo.udt_attendance_outside_radius
    SET status = 'Rejected',
        reviewed_by = @reviewed_by,
        reviewed_at = GETDATE(),
        review_notes = @review_notes
    WHERE id = @id
      AND company_id = @reviewer_company_id
      AND status = 'Pending';

    IF @@ROWCOUNT <> 1
    BEGIN
        SET @result_code = -4;
        SET @result_message = N'Pengajuan tidak ditemukan, berbeda perusahaan, atau sudah diproses.';
        RETURN;
    END;

    SET @result_code = 1;
    SET @result_message = N'Absensi luar radius ditolak. Karyawan harus melakukan absen ulang.';
END;
GO

/* ========================================================================== */
/* 5. Tanpa lokasi aktif = jalur luar radius, bukan error konfigurasi          */
/* ========================================================================== */
DECLARE @FaceDefinition NVARCHAR(MAX) =
    OBJECT_DEFINITION(OBJECT_ID('dbo.udp_verify_face_attendance_python'));

IF @FaceDefinition IS NULL
    THROW 51604, 'SP udp_verify_face_attendance_python tidak ditemukan.', 1;

IF @FaceDefinition LIKE '%SET @result_message = N''Tidak ada kantor aktif'';%'
BEGIN
    SET @FaceDefinition = REPLACE
    (
        @FaceDefinition,
        'SET @result_message = N''Tidak ada kantor aktif'';',
        'SET @result_message = N''Anda berada di luar radius kantor karena lokasi kantor perusahaan belum tersedia'';'
    );

    IF UPPER(LTRIM(@FaceDefinition)) LIKE 'CREATE%PROCEDURE%'
       AND UPPER(LTRIM(@FaceDefinition)) NOT LIKE 'CREATE OR ALTER%'
    BEGIN
        DECLARE @CreatePos INT = CHARINDEX('CREATE', UPPER(@FaceDefinition));
        SET @FaceDefinition = STUFF(@FaceDefinition, @CreatePos, 6, 'ALTER');
    END;

    EXEC sys.sp_executesql @FaceDefinition;
END;
GO

/* ========================================================================== */
/* 6. Semua daftar approval Dinas Luar dikunci ke perusahaan actor            */
/* ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.udp_timeoff_get_pending_org_review
    @reviewer_userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id = company_id FROM dbo.udt_company_info_user WHERE userid = @reviewer_userid;

    SELECT t.id,t.userid,ISNULL(emp.name,ISNULL(u.name,'')) AS user_name,
           ISNULL(emp.job_position,'') AS user_job,t.jenis_timeoff,
           t.tanggal_mulai,t.tanggal_selesai,t.total_hari,t.catatan,t.status,
           t.created_at,t.jenis_pekerjaan,t.rab_type,t.nominal_uang_kantor,
           t.org_target,DATEDIFF(DAY,t.created_at,GETDATE()) AS days_waiting
    FROM dbo.udt_timeoff t
    LEFT JOIN dbo.udt_users u ON u.userid=t.userid
    INNER JOIN dbo.udt_company_info_user emp
        ON emp.userid=t.userid AND emp.company_id=@company_id
    WHERE t.company_id=@company_id
      AND t.jenis_timeoff=N'Dinas Luar'
      AND t.status=N'Menunggu Org'
      AND t.manager_userid=@reviewer_userid
      AND t.manager_approval_status=N'Pending'
    ORDER BY t.created_at DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_timeoff_get_pending_finance
    @finance_userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@finance_userid;

    SELECT t.id,t.userid,ISNULL(emp.name,ISNULL(u.name,'')) user_name,
           ISNULL(emp.job_position,'') user_job,t.jenis_timeoff,t.tanggal_mulai,
           t.tanggal_selesai,t.total_hari,t.catatan,t.status,t.created_at,
           t.jenis_pekerjaan,t.rab_type,t.nominal_uang_kantor,t.org_target,
           t.file_name,t.file_size,t.file_type,t.manager_userid,
           t.manager_approval_status,t.hrd_approval_status,t.hrd_approved_by,
           t.hrd_approved_at,t.finance_userid,t.finance_approval_status,
           DATEDIFF(DAY,t.created_at,GETDATE()) days_waiting
    FROM dbo.udt_timeoff t
    LEFT JOIN dbo.udt_users u ON u.userid=t.userid
    INNER JOIN dbo.udt_company_info_user emp
        ON emp.userid=t.userid AND emp.company_id=@company_id
    WHERE t.company_id=@company_id
      AND t.jenis_timeoff=N'Dinas Luar'
      AND t.status=N'Pending Finance'
      AND t.finance_approval_status=N'Pending'
      AND t.finance_userid=@finance_userid
    ORDER BY t.created_at DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_timeoff_get_pending_head_verify
    @head_userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@head_userid;

    SELECT t.id,t.userid,ISNULL(emp.name,ISNULL(u.name,'')) user_name,
           ISNULL(emp.job_position,'') user_job,t.jenis_timeoff,t.tanggal_mulai,
           t.tanggal_selesai,t.total_hari,t.catatan,t.status,t.created_at,
           t.jenis_pekerjaan,t.rab_type,t.nominal_uang_kantor,t.org_target,
           t.laporan_file_name,t.anggaran_file_name,
           DATEDIFF(DAY,t.laporan_submitted_at,GETDATE()) days_waiting
    FROM dbo.udt_timeoff t
    LEFT JOIN dbo.udt_users u ON u.userid=t.userid
    INNER JOIN dbo.udt_company_info_user emp
        ON emp.userid=t.userid AND emp.company_id=@company_id
    WHERE t.company_id=@company_id
      AND t.jenis_timeoff=N'Dinas Luar'
      AND t.status=N'Pending Laporan Head'
      AND t.laporan_head_userid=@head_userid
    ORDER BY t.laporan_submitted_at ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_timeoff_get_pending_transfer
    @finance_userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id=company_id FROM dbo.udt_company_info_user WHERE userid=@finance_userid;

    SELECT t.id,t.userid,ISNULL(emp.name,ISNULL(u.name,'')) user_name,
           ISNULL(emp.job_position,'') user_job,t.jenis_timeoff,t.tanggal_mulai,
           t.tanggal_selesai,t.total_hari,t.catatan,t.status,t.created_at,
           t.jenis_pekerjaan,t.rab_type,t.nominal_uang_kantor,t.org_target,
           t.head_name,DATEDIFF(DAY,t.laporan_hrd_approved_at,GETDATE()) days_waiting
    FROM dbo.udt_timeoff t
    LEFT JOIN dbo.udt_users u ON u.userid=t.userid
    INNER JOIN dbo.udt_company_info_user emp
        ON emp.userid=t.userid AND emp.company_id=@company_id
    WHERE t.company_id=@company_id
      AND t.jenis_timeoff=N'Dinas Luar'
      AND t.status=N'Menunggu Transfer'
      AND t.finance_userid=@finance_userid
    ORDER BY t.laporan_hrd_approved_at ASC;
END;
GO

/* Asset masih memakai company_name pada versi lama; ubah menjadi company_id. */
CREATE OR ALTER PROCEDURE dbo.udp_asset_request_get_pending
    @hrd_userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company_id INT;
    DECLARE @is_head_hrd BIT = 0;
    SELECT TOP (1)
        @company_id=ci.company_id,
        @is_head_hrd=CASE
            WHEN UPPER(ISNULL(ci.organization,'')) LIKE '%HRD%'
             AND (UPPER(ISNULL(ci.job_position,'')) LIKE '%HEAD%'
                  OR UPPER(ISNULL(ci.job_level,''))='HEAD')
            THEN 1 ELSE 0 END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid=u.userid
    WHERE u.userid=@hrd_userid AND u.active=1 AND ISNULL(u.deleted,0)=0;

    IF @company_id IS NULL OR @is_head_hrd=0
    BEGIN
        SELECT TOP 0 CAST(NULL AS INT) id,CAST(NULL AS VARCHAR(50)) userid,
            CAST(NULL AS NVARCHAR(200)) user_name,CAST(NULL AS NVARCHAR(200)) user_job,
            CAST(NULL AS INT) asset_item_id,CAST(NULL AS NVARCHAR(200)) nama_barang,
            CAST(NULL AS INT) stok_tersedia,CAST(NULL AS NVARCHAR(20)) kategori,
            CAST(NULL AS INT) jumlah,CAST(NULL AS NVARCHAR(500)) catatan,
            CAST(NULL AS NVARCHAR(20)) status,CAST(NULL AS DATETIME) tanggal_pengajuan,
            CAST(NULL AS INT) days_waiting;
        RETURN;
    END;

    SELECT r.id,r.userid,u.name user_name,cu.job_position user_job,
           r.asset_item_id,ai.nama_barang,ai.stok stok_tersedia,r.kategori,
           r.jumlah,r.catatan,r.status,r.created_at tanggal_pengajuan,
           DATEDIFF(DAY,r.created_at,GETDATE()) days_waiting
    FROM dbo.udt_asset_requests r
    INNER JOIN dbo.udt_asset_items ai ON ai.id=r.asset_item_id
    INNER JOIN dbo.udt_company_info_user cu
        ON cu.userid=r.userid AND cu.company_id=@company_id
    LEFT JOIN dbo.udt_users u ON u.userid=r.userid
    WHERE r.status='Pending'
      AND EXISTS
      (
          SELECT 1 FROM dbo.udt_companies c
          WHERE c.id=@company_id AND c.company_name=ai.company_name
      )
    ORDER BY r.created_at ASC;
END;
GO

/* Verifikasi singkat. */
SELECT company_id,status,COUNT(*) total
FROM dbo.udt_attendance_outside_radius
GROUP BY company_id,status
ORDER BY company_id,status;

SELECT name,modify_date
FROM sys.procedures
WHERE name IN
(
    'udp_attendance_outside_radius_submit',
    'udp_attendance_outside_radius_list',
    'udp_attendance_outside_radius_approve',
    'udp_attendance_outside_radius_reject',
    'udp_timeoff_get_pending_org_review',
    'udp_timeoff_get_pending_finance',
    'udp_timeoff_get_pending_head_verify',
    'udp_timeoff_get_pending_hrd_verify',
    'udp_timeoff_get_pending_transfer',
    'udp_asset_request_get_pending'
)
ORDER BY name;
GO

