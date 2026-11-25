/* Check-in dibuka 30 menit sebelum jam masuk PT, berdasarkan waktu request
   API terverifikasi. Berlaku juga untuk hari libur; checkout tidak dibatasi.
   Memerlukan migrasi 044 dan 051. Tidak mengubah jam server. */
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @definition NVARCHAR(MAX) =
        OBJECT_DEFINITION(OBJECT_ID(N'dbo.udp_verify_face_attendance_python'));
    DECLARE @checkin INT, @officeDeclaration INT, @createPosition INT;

    IF @definition IS NULL
        THROW 55501, 'Prosedur absensi wajah tidak ditemukan.', 1;
    IF OBJECT_ID(N'dbo.udt_company_attendance_reminder_setting', N'U') IS NULL
        THROW 55502, 'Jalankan migrasi 044 terlebih dahulu.', 1;
    IF @definition NOT LIKE N'%THROW 55104%'
        THROW 55503, 'Jalankan migrasi 051 terlebih dahulu agar waktu API terverifikasi.', 1;
    IF @definition LIKE N'%EARLIEST_CHECKIN_30_MIN%'
    BEGIN
        COMMIT TRANSACTION;
        SELECT N'SUDAH TERPASANG' AS status;
        RETURN;
    END;

    SET @checkin = CHARINDEX(N'IF @attendance_type = ''checkin''', @definition);
    SET @officeDeclaration = CHARINDEX(N'DECLARE', @definition,
        CHARINDEX(N'IF @is_holiday = 0', @definition));
    IF @checkin = 0 OR @officeDeclaration = 0 OR
       @officeDeclaration > @checkin OR
       SUBSTRING(@definition, @officeDeclaration, 100) NOT LIKE N'%@office_id%'
        THROW 55504, 'Posisi validasi check-in tidak dikenali; prosedur tidak diubah.', 1;

    SET @definition = STUFF(@definition, @officeDeclaration, 0, N'
        /* EARLIEST_CHECKIN_30_MIN: sebelum cek lokasi/wajah/penyimpanan. */
        IF @attendance_type = ''checkin''
        BEGIN
            DECLARE @company_start_time TIME(0) = COALESCE(
                (SELECT s.start_time
                 FROM dbo.udt_company_attendance_reminder_setting s
                 WHERE s.company_id = @company_id),
                @check_in_time,
                CAST(''08:00'' AS TIME(0))
            );
            DECLARE @earliest_checkin DATETIME = DATEADD(
                MINUTE,
                DATEDIFF(MINUTE, CAST(''00:00'' AS TIME(0)), @company_start_time) - 30,
                CAST(@today AS DATETIME)
            );
            IF @now < @earliest_checkin
            BEGIN
                ROLLBACK TRANSACTION;
                SET @result_code = -30;
                SET @result_message = N''Check-in baru dibuka pukul ''
                    + CONVERT(NVARCHAR(5), CAST(@earliest_checkin AS TIME), 108)
                    + N'' (30 menit sebelum jam masuk PT).'';
                RETURN;
            END;
            /* Status tepat waktu/terlambat mengikuti jam masuk PT yang sama. */
            IF @is_holiday = 0 SET @check_in_time = @company_start_time;
        END;

    ');

    IF UPPER(LTRIM(@definition)) LIKE N'CREATE%PROCEDURE%'
       AND UPPER(LTRIM(@definition)) NOT LIKE N'CREATE OR ALTER%'
    BEGIN
        SET @createPosition = CHARINDEX(N'CREATE', UPPER(@definition));
        SET @definition = STUFF(@definition, @createPosition, LEN(N'CREATE'), N'ALTER');
    END;

    EXEC sys.sp_executesql @definition;
    IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.udp_verify_face_attendance_python'))
        NOT LIKE N'%EARLIEST_CHECKIN_30_MIN%'
        THROW 55505, 'Validasi aturan check-in gagal.', 1;
    COMMIT TRANSACTION;
    SELECT N'BERHASIL - check-in dibuka 30 menit sebelum jam masuk PT' AS status;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
