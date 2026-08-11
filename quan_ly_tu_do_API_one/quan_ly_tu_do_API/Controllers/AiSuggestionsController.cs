using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quan_ly_tu_do_API.Data;
using quan_ly_tu_do_API.DTOs;
using quan_ly_tu_do_API.Models;

namespace quan_ly_tu_do_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AiSuggestionsController : ControllerBase
    {
        private readonly QuanlytudoDbContext _context;

        public AiSuggestionsController(QuanlytudoDbContext context)
        {
            _context = context;
        }

        // GET: api/AiSuggestions/user/{userId}
        // Lấy toàn bộ lịch sử gợi ý của một user, mới nhất trước
        [HttpGet("user/{userId}")]
        public async Task<ActionResult<IEnumerable<AiSuggestionResponseDto>>> GetByUser(
            Guid userId,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20)
        {
            if (page < 1) page = 1;
            if (pageSize is < 1 or > 100) pageSize = 20;

            var query = _context.AiSuggestions
                .Where(s => s.UserId == userId)
                .OrderByDescending(s => s.CreatedAt);

            var items = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(s => ToDto(s))
                .ToListAsync();

            return Ok(items);
        }

        // GET: api/AiSuggestions/{id}
        [HttpGet("{id}")]
        public async Task<ActionResult<AiSuggestionResponseDto>> GetById(Guid id)
        {
            var item = await _context.AiSuggestions.FindAsync(id);
            if (item == null) return NotFound();
            return Ok(ToDto(item));
        }

        // POST: api/AiSuggestions
        // Flutter gọi ngay sau khi nhận được kết quả AI
        [HttpPost]
        public async Task<ActionResult<AiSuggestionResponseDto>> Create(
            [FromBody] CreateAiSuggestionDto dto)
        {
            if (dto.UserId == Guid.Empty)
                return BadRequest("UserId không hợp lệ.");

            if (string.IsNullOrWhiteSpace(dto.SuggestionText))
                return BadRequest("SuggestionText không được rỗng.");

            var entity = new AiSuggestion
            {
                Id = Guid.NewGuid(),
                UserId = dto.UserId,
                Destination = dto.Destination?.Trim(),
                HealthTag = dto.HealthTag?.Trim(),
                WeatherSnapshot = dto.WeatherSnapshot?.Trim(),
                SuggestionText = dto.SuggestionText.Trim(),
                Source = dto.Source ?? "worker",
                CreatedAt = DateTime.UtcNow,
            };

            _context.AiSuggestions.Add(entity);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetById),
                new { id = entity.Id }, ToDto(entity));
        }

        // PATCH: api/AiSuggestions/{id}/feedback
        // User bấm 👍/👎 hoặc lưu outfit
        [HttpPatch("{id}/feedback")]
        public async Task<IActionResult> Feedback(
            Guid id, [FromBody] FeedbackSuggestionDto dto)
        {
            var entity = await _context.AiSuggestions.FindAsync(id);
            if (entity == null) return NotFound();

            entity.IsHelpful = dto.IsHelpful;
            entity.SavedOutfitId = dto.SavedOutfitId;

            await _context.SaveChangesAsync();
            return NoContent();
        }

        // DELETE: api/AiSuggestions/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(Guid id)
        {
            var entity = await _context.AiSuggestions.FindAsync(id);
            if (entity == null) return NotFound();

            _context.AiSuggestions.Remove(entity);
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // ── Helper ────────────────────────────────────────────────────────
        private static AiSuggestionResponseDto ToDto(AiSuggestion s) => new()
        {
            Id = s.Id,
            UserId = s.UserId,
            Destination = s.Destination,
            HealthTag = s.HealthTag,
            WeatherSnapshot = s.WeatherSnapshot,
            SuggestionText = s.SuggestionText,
            Source = s.Source,
            IsHelpful = s.IsHelpful,
            SavedOutfitId = s.SavedOutfitId,
            CreatedAt = s.CreatedAt,
        };
    }
}