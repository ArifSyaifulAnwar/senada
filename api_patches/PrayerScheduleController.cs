// Salin ke apiabsensi/Controllers dan daftarkan di apiabsensi.csproj.
// Memerlukan database_migrations/028_company_prayer_schedule.sql.
using apiabsensi.Services;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Security.Claims;
using System.Threading.Tasks;
using System.Web.Http;

namespace apiabsensi.Controllers
{
    [Authorize]
    [RoutePrefix("api/employee")]
    public class PrayerScheduleController : ApiController
    {
        public class ListRequest { public string Tanggal { get; set; } }
        public class SaveRequest : ListRequest
        {
            public string PrayerCode { get; set; }
            public string MuadzinUserId { get; set; }
            public string ImamUserId { get; set; }
        }

        private string UserId => (User.Identity as ClaimsIdentity)
            ?.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        private static bool ParseDate(string input, out DateTime value) =>
            DateTime.TryParseExact(input, "yyyy-MM-dd", CultureInfo.InvariantCulture,
                DateTimeStyles.None, out value);

        [HttpPost, Route("prayer-schedule-list")]
        public async Task<IHttpActionResult> List([FromBody] ListRequest request)
        {
            if (string.IsNullOrWhiteSpace(UserId)) return Unauthorized();
            if (request == null || !ParseDate(request.Tanggal, out var date))
                return BadRequest("Tanggal harus berformat yyyy-MM-dd.");
            try
            {
                var rows = new List<object>();
                using (var connection = new SqlConnection(DatabaseConnection.GetConnectionString()))
                using (var command = new SqlCommand("dbo.udp_company_prayer_schedule_list", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.Add("@user_id", SqlDbType.VarChar, 50).Value = UserId;
                    command.Parameters.Add("@schedule_date", SqlDbType.Date).Value = date;
                    await connection.OpenAsync();
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                            rows.Add(new {
                                prayer_code = reader["prayer_code"].ToString(),
                                muadzin_user_id = reader["muadzin_user_id"].ToString(),
                                muadzin_name = reader["muadzin_name"].ToString(),
                                imam_user_id = reader["imam_user_id"].ToString(),
                                imam_name = reader["imam_name"].ToString()
                            });
                    }
                }
                return Ok(new { success = true, data = rows });
            }
            catch (SqlException ex) when (ex.Number == 52800)
            {
                return Content(System.Net.HttpStatusCode.Forbidden,
                    new { success = false, message = ex.Message });
            }
        }

        [HttpPost, Route("prayer-schedule-save")]
        public async Task<IHttpActionResult> Save([FromBody] SaveRequest request)
        {
            if (string.IsNullOrWhiteSpace(UserId)) return Unauthorized();
            if (request == null || !ParseDate(request.Tanggal, out var date))
                return BadRequest("Tanggal harus berformat yyyy-MM-dd.");
            if (string.IsNullOrWhiteSpace(request.PrayerCode) ||
                string.IsNullOrWhiteSpace(request.MuadzinUserId) ||
                string.IsNullOrWhiteSpace(request.ImamUserId))
                return BadRequest("Waktu salat, petugas azan, dan imam wajib diisi.");
            try
            {
                using (var connection = new SqlConnection(DatabaseConnection.GetConnectionString()))
                using (var command = new SqlCommand("dbo.udp_company_prayer_schedule_save", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.Add("@user_id", SqlDbType.VarChar, 50).Value = UserId;
                    command.Parameters.Add("@schedule_date", SqlDbType.Date).Value = date;
                    command.Parameters.Add("@prayer_code", SqlDbType.VarChar, 10).Value = request.PrayerCode;
                    command.Parameters.Add("@muadzin_user_id", SqlDbType.VarChar, 50).Value = request.MuadzinUserId;
                    command.Parameters.Add("@imam_user_id", SqlDbType.VarChar, 50).Value = request.ImamUserId;
                    await connection.OpenAsync();
                    await command.ExecuteNonQueryAsync();
                }
                return Ok(new { success = true, message = "Jadwal berhasil disimpan." });
            }
            catch (SqlException ex) when (ex.Number >= 52801 && ex.Number <= 52804)
            {
                return Content(System.Net.HttpStatusCode.Forbidden,
                    new { success = false, message = ex.Message });
            }
        }
    }
}
