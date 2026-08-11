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
    public class UserPreferenceDto
    {
        public Guid? Id { get; set; }
        public Guid UserId { get; set; }
        public string? Hobbies { get; set; }
        public string? StylePreference { get; set; }
        public string? DefaultLocation { get; set; }
    }

    [Route("api/[controller]")]
    [ApiController]
    public class UserPreferencesController : ControllerBase
    {
        private readonly QuanlytudoDbContext _context;
        private readonly RagWebhookService _rag; // ← thêm

        public UserPreferencesController(QuanlytudoDbContext context, RagWebhookService rag) // ← thêm rag
        {
            _context = context;
            _rag = rag; // ← thêm
        }

        // GET: api/UserPreferences
        [HttpGet]
        public async Task<ActionResult<IEnumerable<UserPreference>>> GetUserPreferences()
        {
            return await _context.UserPreferences.ToListAsync();
        }

        // GET: api/UserPreferences/5
        [HttpGet("{id}")]
        public async Task<ActionResult<UserPreference>> GetUserPreference(Guid id)
        {
            var userPreference = await _context.UserPreferences.FindAsync(id);
            if (userPreference == null) return NotFound();
            return userPreference;
        }

        // PUT: api/UserPreferences/5
        [HttpPut("{id}")]
        public async Task<IActionResult> PutUserPreference(Guid id, [FromBody] UserPreferenceDto dto)
        {
            var existing = await _context.UserPreferences.FindAsync(id);
            if (existing == null) return NotFound();

            existing.Hobbies = dto.Hobbies;
            existing.StylePreference = dto.StylePreference;
            existing.DefaultLocation = dto.DefaultLocation;
            existing.UpdatedAt = DateTime.UtcNow;

            try
            {
                await _context.SaveChangesAsync();
                _rag.TriggerSync(existing.UserId, "preferences"); // ← thêm
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!UserPreferenceExists(id)) return NotFound();
                else throw;
            }

            return NoContent();
        }

        // POST: api/UserPreferences
        [HttpPost]
        public async Task<ActionResult<UserPreference>> PostUserPreference([FromBody] UserPreferenceDto dto)
        {
            if (dto.UserId == Guid.Empty)
                return BadRequest("UserId không hợp lệ");

            // Upsert: nếu đã có thì update
            var existing = await _context.UserPreferences
                .FirstOrDefaultAsync(p => p.UserId == dto.UserId);

            if (existing != null)
            {
                existing.Hobbies = dto.Hobbies;
                existing.StylePreference = dto.StylePreference;
                existing.DefaultLocation = dto.DefaultLocation;
                existing.UpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();

                _rag.TriggerSync(existing.UserId, "preferences"); // ← thêm

                return Ok(existing);
            }

            var pref = new UserPreference
            {
                Id = dto.Id.HasValue && dto.Id.Value != Guid.Empty
                    ? dto.Id.Value
                    : Guid.NewGuid(),
                UserId = dto.UserId,
                Hobbies = dto.Hobbies,
                StylePreference = dto.StylePreference,
                DefaultLocation = dto.DefaultLocation,
                UpdatedAt = DateTime.UtcNow,
            };

            _context.UserPreferences.Add(pref);
            await _context.SaveChangesAsync();

            _rag.TriggerSync(pref.UserId, "preferences"); // ← thêm

            return CreatedAtAction("GetUserPreference", new { id = pref.Id }, pref);
        }

        // DELETE: api/UserPreferences/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteUserPreference(Guid id)
        {
            var userPreference = await _context.UserPreferences.FindAsync(id);
            if (userPreference == null) return NotFound();

            var userId = userPreference.UserId; // ← lưu trước khi xoá
            _context.UserPreferences.Remove(userPreference);
            await _context.SaveChangesAsync();

            _rag.TriggerSync(userId, "preferences"); // ← thêm

            return NoContent();
        }

        private bool UserPreferenceExists(Guid id)
        {
            return _context.UserPreferences.Any(e => e.Id == id);
        }
    }
}