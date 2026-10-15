/*
  SENADA - Home calendar wajib mengikuti perusahaan user yang login.

  Sebelum perubahan ini /api/calendar/check hanya menerima tanggal sehingga
  hari libur/WFH berpotensi terbaca dari perusahaan lain. Sekarang company_id
  selalu diturunkan dari @user_id; Flutter tidak boleh mengirim company_id.
*/

USE [ABSENSI];
GO

CREATE OR ALTER PROCEDURE dbo.udp_calendar_check_tanggal
    @tanggal DATE,
    @user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company_id INT;

    SELECT TOP (1) @company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c
        ON c.id = ci.company_id
       AND c.is_active = 1
    WHERE u.userid = @user_id
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    IF @company_id IS NULL
        THROW 51000, 'User tidak aktif atau belum terhubung ke perusahaan.', 1;

    DECLARE @is_weekend BIT = CASE
        WHEN (DATEDIFF(DAY, CONVERT(DATE, '19000101'), @tanggal) % 7) IN (5, 6)
            THEN 1 ELSE 0
    END;

    DECLARE @tipe VARCHAR(10);
    DECLARE @keterangan NVARCHAR(500);

    SELECT TOP (1)
        @tipe = UPPER(LTRIM(RTRIM(cal.tipe))),
        @keterangan = cal.keterangan
    FROM dbo.udt_company_calendar cal
    WHERE cal.company_id = @company_id
      AND cal.tanggal = @tanggal
      AND UPPER(LTRIM(RTRIM(cal.tipe))) IN ('LIBUR', 'WFH')
    ORDER BY CASE UPPER(LTRIM(RTRIM(cal.tipe)))
                 WHEN 'LIBUR' THEN 1
                 WHEN 'WFH' THEN 2
                 ELSE 3
             END,
             cal.id DESC;

    SELECT
        @tanggal AS tanggal,
        @is_weekend AS is_weekend,
        CONVERT(BIT, CASE WHEN @tipe = 'LIBUR' THEN 1 ELSE 0 END) AS is_libur,
        CONVERT(BIT, CASE WHEN @tipe = 'WFH' THEN 1 ELSE 0 END) AS is_wfh,
        CONVERT(BIT, CASE WHEN @is_weekend = 1 OR @tipe = 'LIBUR'
                         THEN 1 ELSE 0 END) AS is_hari_libur,
        COALESCE(
            NULLIF(LTRIM(RTRIM(@keterangan)), ''),
            CASE
                WHEN @is_weekend = 1
                    THEN CASE WHEN (DATEDIFF(DAY, CONVERT(DATE, '19000101'), @tanggal) % 7) = 5
                              THEN N'Hari Sabtu' ELSE N'Hari Minggu' END
                ELSE N''
            END
        ) AS keterangan;
END;
GO

/* Verifikasi manual: ganti dua UserId dengan user dari perusahaan berbeda. */
-- EXEC dbo.udp_calendar_check_tanggal @tanggal = '2026-10-14', @user_id = 'USER_PT_A';
-- EXEC dbo.udp_calendar_check_tanggal @tanggal = '2026-10-14', @user_id = 'USER_PT_B';

