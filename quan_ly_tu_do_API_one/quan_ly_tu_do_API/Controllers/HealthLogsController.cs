using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quan_ly_tu_do_API.Data;
using quan_ly_tu_do_API.Models;
using quan_ly_tu_do_API.Services; // ← thêm

namespace quan_ly_tu_do_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class HealthLogsController : ControllerBase
    {
        private readonly QuanlytudoDbContext _context;
        private readonly RagWebhookService _rag; // ← thêm

        public HealthLogsController(QuanlytudoDbContext context, RagWebhookService rag) // ← thêm rag
        {
            _context = context;
            _rag = rag; // ← thêm
        }

        // GET: api/HealthLogs
        [HttpGet]
        public async Task<ActionResult<IEnumerable<HealthLog>>> GetHealthLogs()
        {
            return await _context.HealthLogs.ToListAsync();
        }

        // GET: api/HealthLogs/5
        [HttpGet("{id}")]
        public async Task<ActionResult<HealthLog>> GetHealthLog(Guid id)
        {
            var healthLog = await _context.HealthLogs.FindAsync(id);
            if (healthLog == null) return NotFound();
            return healthLog;
        }

        // PUT: api/HealthLogs/5
        [HttpPut("{id}")]
        public async Task<IActionResult> PutHealthLog(Guid id, HealthLog healthLog)
        {
            if (id != healthLog.Id) return BadRequest();

            _context.Entry(healthLog).State = EntityState.Modified;
            try
            {
                await _context.SaveChangesAsync();
                _rag.TriggerSync(healthLog.UserId, "health"); // ← thêm
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!HealthLogExists(id)) return NotFound();
                else throw;
            }

            return NoContent();
        }

        // POST: api/HealthLogs
        [HttpPost]
        public async Task<ActionResult<HealthLog>> PostHealthLog(HealthLog healthLog)
        {
            healthLog.Id = Guid.NewGuid();
            healthLog.CreatedAt = DateTime.UtcNow;
            _context.HealthLogs.Add(healthLog);
            await _context.SaveChangesAsync();

            _rag.TriggerSync(healthLog.UserId, "health"); // ← thêm

            return CreatedAtAction("GetHealthLog", new { id = healthLog.Id }, healthLog);
        }

        // DELETE: api/HealthLogs/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteHealthLog(Guid id)
        {
            var healthLog = await _context.HealthLogs.FindAsync(id);
            if (healthLog == null) return NotFound();

            var userId = healthLog.UserId; // ← lưu trước khi xoá
            _context.HealthLogs.Remove(healthLog);
            await _context.SaveChangesAsync();

            _rag.TriggerSync(userId, "health"); // ← thêm

            return NoContent();
        }

        // GET: api/HealthLogs/user/{userId}/date/{date}
        [HttpGet("user/{userId}/date/{date}")]
        public async Task<ActionResult<HealthLog>> GetByUserAndDate(Guid userId, DateOnly date)
        {
            var log = await _context.HealthLogs
                .FirstOrDefaultAsync(h => h.UserId == userId && h.LogDate == date);
            if (log == null) return NotFound();
            return log;
        }

        private bool HealthLogExists(Guid id)
        {
            return _context.HealthLogs.Any(e => e.Id == id);
        }
    }
}