/*
  SENADA - Waktu absensi tepercaya saat request diterima API

  Urutan deploy:
  1. Jalankan migration ini pada database ABSENSI.
  2. Deploy/restart API yang sudah mengirim @request_received_utc.

  Parameter baru bersifat optional agar API lama tetap kompatibel.
  Waktu dari gadget tidak dipercaya. SP hanya menerima waktu UTC dari API
  jika berada pada rentang 15 menit terakhir sampai 1 menit ke depan.
*/

USE ABSENSI;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS
(
    SELECT 1
    FROM sys.parameters
    WHERE object_id = OBJECT_ID('dbo.udp_verify_face_attendance_python')
      AND name = '@request_received_utc'
)
BEGIN
    SELECT
        'ALREADY APPLIED' AS status,
        p.name AS parameter_name
    FROM sys.parameters p
    WHERE p.object_id = OBJECT_ID('dbo.udp_verify_face_attendance_python')
      AND p.name = '@request_received_utc';
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @definition NVARCHAR(MAX) =
        OBJECT_DEFINITION(OBJECT_ID('dbo.udp_verify_face_attendance_python'));
    DECLARE @accuracyPosition INT;
    DECLARE @accuracyLineEnd INT;
    DECLARE @timeStart INT;
    DECLARE @timeEnd INT;
    DECLARE @createPosition INT;
    DECLARE @newTimeBlock NVARCHAR(MAX);

    IF @definition IS NULL
        THROW 50001, 'SP udp_verify_face_attendance_python tidak ditemukan.', 1;

    /* Tambahkan parameter optional setelah @accuracy_meters. */
    SET @accuracyPosition = CHARINDEX('@accuracy_meters', @definition);
    SET @accuracyLineEnd = CHARINDEX(CHAR(10), @definition, @accuracyPosition);

    IF @accuracyPosition = 0 OR @accuracyLineEnd = 0
        THROW 50002, 'Posisi parameter @accuracy_meters tidak ditemukan.', 1;

    SET @definition = STUFF(
        @definition,
        @accuracyLineEnd + 1,
        0,
        '    @request_received_utc DATETIME2(3) = NULL,' + CHAR(13) + CHAR(10)
    );

    /* Ganti sumber @now dengan waktu request API yang tervalidasi. */
    SET @timeStart = CHARINDEX('DECLARE @now DATETIME = CONVERT(', @definition);
    SET @timeEnd = CHARINDEX('DECLARE @today', @definition, @timeStart);

    IF @timeStart = 0 OR @timeEnd = 0
        THROW 50003, 'Blok DECLARE @now tidak ditemukan.', 1;

    SET @newTimeBlock =
        N'DECLARE @server_utc DATETIME2(3) = SYSUTCDATETIME();

        IF @request_received_utc IS NULL
           OR @request_received_utc < DATEADD(MINUTE, -15, @server_utc)
           OR @request_received_utc > DATEADD(MINUTE, 1, @server_utc)
        BEGIN
            SET @request_received_utc = @server_utc;
        END;

        DECLARE @now DATETIME = CONVERT(
            DATETIME,
            @request_received_utc
                AT TIME ZONE ''UTC''
                AT TIME ZONE ''SE Asia Standard Time''
        );

        ';

    SET @definition = STUFF(
        @definition,
        @timeStart,
        @timeEnd - @timeStart,
        @newTimeBlock
    );

    SET @createPosition = CHARINDEX('CREATE PROCEDURE', @definition);
    IF @createPosition = 0
        THROW 50004, 'Header CREATE PROCEDURE tidak ditemukan.', 1;

    SET @definition = STUFF(
        @definition,
        @createPosition,
        LEN('CREATE'),
        'ALTER'
    );

    EXEC sys.sp_executesql @definition;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.parameters
        WHERE object_id = OBJECT_ID('dbo.udp_verify_face_attendance_python')
          AND name = '@request_received_utc'
          AND TYPE_NAME(user_type_id) = 'datetime2'
    )
        THROW 50005, 'Parameter @request_received_utc gagal ditambahkan.', 1;

    DECLARE @updatedDefinition NVARCHAR(MAX) =
        OBJECT_DEFINITION(OBJECT_ID('dbo.udp_verify_face_attendance_python'));

    IF @updatedDefinition NOT LIKE '%@request_received_utc%AT TIME ZONE ''UTC''%'
        THROW 50006, 'Validasi sumber waktu request gagal.', 1;

    COMMIT TRANSACTION;

    SELECT
        'FIX BERHASIL' AS status,
        p.name AS parameter_name,
        TYPE_NAME(p.user_type_id) AS data_type,
        p.has_default_value
    FROM sys.parameters p
    WHERE p.object_id = OBJECT_ID('dbo.udp_verify_face_attendance_python')
      AND p.name = '@request_received_utc';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
