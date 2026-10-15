/*
  SENADA - Isolasi reimbursement per perusahaan

  Jalankan pada ABSENSI sebelum API/Flutter versi ini dipublikasikan.
  company_id selalu diturunkan dari udt_company_info_user; client tidak boleh
  menentukan tenant sendiri.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

/* 1. Simpan tenant pada transaksi dan kategori. */
IF COL_LENGTH('dbo.reimbursements', 'company_id') IS NULL
    ALTER TABLE dbo.reimbursements ADD company_id INT NULL;
GO

UPDATE r
SET r.company_id = ci.company_id
FROM dbo.reimbursements r
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = r.user_id
WHERE r.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.reimbursements WHERE company_id IS NULL)
    THROW 51100, 'Masih ada reimbursement tanpa company_id. Perbaiki mapping user terlebih dahulu.', 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_reimbursements_company')
    ALTER TABLE dbo.reimbursements WITH CHECK ADD CONSTRAINT FK_reimbursements_company
        FOREIGN KEY (company_id) REFERENCES dbo.udt_companies(id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.reimbursements') AND name = 'IX_reimbursements_company_status_date')
    CREATE INDEX IX_reimbursements_company_status_date
        ON dbo.reimbursements(company_id, status, expense_date)
        INCLUDE(user_id, amount);
GO

IF COL_LENGTH('dbo.reimbursement_categories', 'company_id') IS NULL
    ALTER TABLE dbo.reimbursement_categories ADD company_id INT NULL;
GO

/*
  Kategori lama dibiarkan company_id NULL sebagai template bawaan semua PT.
  Kategori tambahan milik PT tertentu harus diisi company_id perusahaan itu.
*/

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.reimbursement_categories') AND name = 'IX_reimbursement_categories_company')
    CREATE INDEX IX_reimbursement_categories_company
        ON dbo.reimbursement_categories(company_id, name);
GO

/* 2. Lindungi insert/update legacy: tenant transaksi selalu mengikuti pemilik. */
CREATE OR ALTER TRIGGER dbo.trg_reimbursements_company_guard
ON dbo.reimbursements
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.udt_company_info_user ci ON ci.userid = i.user_id
        WHERE ci.company_id IS NULL
    )
        THROW 51101, 'Pemilik reimbursement belum memiliki perusahaan resmi.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.udt_company_info_user owner_ci ON owner_ci.userid = i.user_id
        LEFT JOIN dbo.udt_company_info_user finance_ci ON finance_ci.userid = i.finance_target_user_id
        WHERE i.finance_target_user_id IS NOT NULL
          AND (finance_ci.company_id IS NULL OR owner_ci.company_id <> finance_ci.company_id)
    )
        THROW 51102, 'Finance tujuan harus berasal dari perusahaan yang sama.', 1;

    UPDATE r
    SET company_id = ci.company_id
    FROM dbo.reimbursements r
    INNER JOIN inserted i ON i.id = r.id
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = i.user_id
    WHERE r.company_id IS NULL OR r.company_id <> ci.company_id;
END;
GO

/* 3. Finance yang tampil hanya Finance aktif dari PT peminta. */
CREATE OR ALTER PROCEDURE dbo.udp_get_finance_users
    @requester_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company_id INT;
    SELECT @company_id = company_id
    FROM dbo.udt_company_info_user
    WHERE userid = @requester_user_id;

    SELECT
        u.userid AS userId,
        u.name AS name,
        ci.job_position AS jobPosition,
        ci.job_level AS jobLevel
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci
        ON ci.userid = u.userid AND ci.company_id = @company_id
    WHERE u.active = 1
      AND ISNULL(u.deleted, 0) = 0
      AND (
          UPPER(ISNULL(ci.organization, '')) LIKE '%FINANCE%'
          OR UPPER(ISNULL(ci.job_position, '')) LIKE '%FINANCE%'
      )
    ORDER BY CASE WHEN UPPER(ISNULL(ci.job_position, '')) LIKE '%HEAD%' THEN 0 ELSE 1 END, u.name;
END;
GO

/* 4. Kategori juga per PT. company_id NULL boleh dipakai sebagai template global. */
CREATE OR ALTER PROCEDURE dbo.udp_reimbursement_categories_get
    @user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id = company_id FROM dbo.udt_company_info_user WHERE userid = @user_id;

    ;WITH ranked AS
    (
        SELECT id, name, description,
               ROW_NUMBER() OVER
               (
                   PARTITION BY LOWER(LTRIM(RTRIM(name)))
                   ORDER BY CASE WHEN company_id = @company_id THEN 0 ELSE 1 END, id
               ) AS rn
        FROM dbo.reimbursement_categories
        WHERE company_id = @company_id OR company_id IS NULL
    )
    SELECT id, name, description
    FROM ranked
    WHERE rn = 1
    ORDER BY name;
END;
GO

/* 5. Statistik HRD/Admin/Finance dibatasi perusahaan viewer. */
CREATE OR ALTER PROCEDURE dbo.udp_reimbursement_admin_statistics
    @viewer_user_id VARCHAR(50),
    @year INT = NULL,
    @month INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id = company_id FROM dbo.udt_company_info_user WHERE userid = @viewer_user_id;

    SELECT
        COUNT(1) AS totalSubmissions,
        ISNULL(SUM(CASE WHEN status IN ('pending','revision') THEN 1 ELSE 0 END),0) AS pendingCount,
        ISNULL(SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END),0) AS approvedCount,
        ISNULL(SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END),0) AS rejectedCount,
        ISNULL(SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END),0) AS paidCount,
        ISNULL(SUM(CASE WHEN status IN ('approved','paid') THEN amount ELSE 0 END),0) AS totalApprovedAmount,
        ISNULL(SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END),0) AS totalPaidAmount,
        ISNULL(SUM(CASE WHEN status IN ('pending','revision') THEN amount ELSE 0 END),0) AS totalPendingAmount,
        FORMAT(ISNULL(SUM(CASE WHEN status IN ('approved','paid') THEN amount ELSE 0 END),0),'C','id-ID') AS formattedTotalApproved,
        FORMAT(ISNULL(SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END),0),'C','id-ID') AS formattedTotalPaid,
        FORMAT(ISNULL(SUM(CASE WHEN status IN ('pending','revision') THEN amount ELSE 0 END),0),'C','id-ID') AS formattedTotalPending
    FROM dbo.reimbursements
    WHERE company_id = @company_id
      AND (@year IS NULL OR YEAR(expense_date) = @year)
      AND (@month IS NULL OR MONTH(expense_date) = @month);
END;
GO

/* 6. Dropdown/rekap karyawan HRD hanya berisi karyawan satu PT. */
CREATE OR ALTER PROCEDURE dbo.udp_reimbursement_get_users_with_reimbursements
    @viewer_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT @company_id = company_id FROM dbo.udt_company_info_user WHERE userid = @viewer_user_id;

    SELECT
        u.userid,
        u.name,
        u.mail,
        u.jobs,
        COUNT(r.id) AS totalReimbursements,
        SUM(CASE WHEN r.status IN ('pending','revision') THEN 1 ELSE 0 END) AS pendingCount,
        SUM(CASE WHEN r.status = 'approved' THEN 1 ELSE 0 END) AS approvedCount,
        SUM(CASE WHEN r.status = 'rejected' THEN 1 ELSE 0 END) AS rejectedCount,
        SUM(CASE WHEN r.status = 'paid' THEN 1 ELSE 0 END) AS paidCount,
        ISNULL(SUM(r.amount),0) AS totalAmount,
        FORMAT(ISNULL(SUM(r.amount),0),'C','id-ID') AS formattedTotalAmount
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci
        ON ci.userid = u.userid AND ci.company_id = @company_id
    INNER JOIN dbo.reimbursements r
        ON r.user_id = u.userid AND r.company_id = @company_id
    WHERE u.active = 1 AND ISNULL(u.deleted,0) = 0
    GROUP BY u.userid, u.name, u.mail, u.jobs
    ORDER BY u.name;
END;
GO

/* Verifikasi. */
SELECT company_id, COUNT(*) AS total_reimbursements
FROM dbo.reimbursements GROUP BY company_id ORDER BY company_id;

SELECT name, modify_date
FROM sys.procedures
WHERE name IN ('udp_get_finance_users','udp_reimbursement_categories_get',
               'udp_reimbursement_admin_statistics','udp_reimbursement_get_users_with_reimbursements')
ORDER BY name;
GO
