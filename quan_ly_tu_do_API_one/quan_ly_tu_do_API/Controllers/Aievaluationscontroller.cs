using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quan_ly_tu_do_API.Data;
using quan_ly_tu_do_API.DTOs;
using quan_ly_tu_do_API.Models;

namespace quan_ly_tu_do_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AiEvaluationsController : ControllerBase
    {
        private readonly QuanlytudoDbContext _context;

        public AiEvaluationsController(QuanlytudoDbContext context)
        {
            _context = context;
        }

        // GET: api/AiEvaluations/user/{userId}
        [HttpGet("user/{userId}")]
        public async Task<ActionResult<IEnumerable<AiEvaluationResponseDto>>> GetByUser(
            Guid userId,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20)
        {
            if (page < 1) page = 1;
            if (pageSize is < 1 or > 100) pageSize = 20;

            var items = await _context.AiEvaluations
                .Where(e => e.UserId == userId)
                .OrderByDescending(e => e.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(e => ToDto(e))
                .ToListAsync();

            return Ok(items);
        }

        // GET: api/AiEvaluations/{id}
        [HttpGet("{id}")]
        public async Task<ActionResult<AiEvaluationResponseDto>> GetById(Guid id)
        {
            var entity = await _context.AiEvaluations.FindAsync(id);
            if (entity == null) return NotFound();
            return Ok(ToDto(entity));
        }

        // POST: api/AiEvaluations
        // Flutter gọi sau khi nhận evaluation text từ AI Worker
        [HttpPost]
        public async Task<ActionResult<AiEvaluationResponseDto>> Create(
            [FromBody] CreateAiEvaluationDto dto)
        {
            if (dto.UserId == Guid.Empty)
                return BadRequest("UserId không hợp lệ.");
            if (dto.TopItemId == Guid.Empty || dto.BottomItemId == Guid.Empty)
                return BadRequest("TopItemId / BottomItemId không hợp lệ.");
            if (string.IsNullOrWhiteSpace(dto.EvaluationText))
                return BadRequest("EvaluationText không được rỗng.");

            var entity = new AiEvaluation
            {
                Id = Guid.NewGuid(),
                UserId = dto.UserId,
                TopItemId = dto.TopItemId,
                TopItemName = dto.TopItemName.Trim(),
                BottomItemId = dto.BottomItemId,
                BottomItemName = dto.BottomItemName.Trim(),
                Destination = dto.Destination?.Trim(),
                HealthTag = dto.HealthTag?.Trim(),
                WeatherSnapshot = dto.WeatherSnapshot?.Trim(),
                EvaluationText = dto.EvaluationText.Trim(),
                CreatedAt = DateTime.UtcNow,
            };

            _context.AiEvaluations.Add(entity);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetById),
                new { id = entity.Id }, ToDto(entity));
        }

        // PATCH: api/AiEvaluations/{id}/rate
        // User chấm sao sau khi xem kết quả
        [HttpPatch("{id}/rate")]
        public async Task<IActionResult> Rate(
            Guid id, [FromBody] RateEvaluationDto dto)
        {
            if (dto.UserRating is < 1 or > 5)
                return BadRequest("UserRating phải từ 1 đến 5.");

            var entity = await _context.AiEvaluations.FindAsync(id);
            if (entity == null) return NotFound();

            entity.UserRating = dto.UserRating;
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // DELETE: api/AiEvaluations/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(Guid id)
        {
            var entity = await _context.AiEvaluations.FindAsync(id);
            if (entity == null) return NotFound();

            _context.AiEvaluations.Remove(entity);
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // ── Helper ────────────────────────────────────────────────────────
        private static AiEvaluationResponseDto ToDto(AiEvaluation e) => new()
        {
            Id = e.Id,
            UserId = e.UserId,
            TopItemId = e.TopItemId,
            TopItemName = e.TopItemName,
            BottomItemId = e.BottomItemId,
            BottomItemName = e.BottomItemName,
            Destination = e.Destination,
            HealthTag = e.HealthTag,
            WeatherSnapshot = e.WeatherSnapshot,
            EvaluationText = e.EvaluationText,
            UserRating = e.UserRating,
            CreatedAt = e.CreatedAt,
        };
    }
}