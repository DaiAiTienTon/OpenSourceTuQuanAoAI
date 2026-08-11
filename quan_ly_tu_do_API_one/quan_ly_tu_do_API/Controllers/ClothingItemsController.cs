using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quan_ly_tu_do_API.Data;
using quan_ly_tu_do_API.DTOs;
using quan_ly_tu_do_API.Models;
using quan_ly_tu_do_API.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace quan_ly_tu_do_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ClothingItemsController : ControllerBase
    {
        private readonly QuanlytudoDbContext _context;
        private readonly RagWebhookService _rag;

        public ClothingItemsController(QuanlytudoDbContext context, RagWebhookService rag)
        {
            _context = context;
            _rag = rag;
        }

        // GET: api/ClothingItems
        [HttpGet]
        public async Task<ActionResult<IEnumerable<ClothingItem>>> GetClothingItems()
        {
            return await _context.ClothingItems.ToListAsync();
        }

        // GET: api/ClothingItems/5
        [HttpGet("{id}")]
        public async Task<ActionResult<ClothingItem>> GetClothingItem(Guid id)
        {
            var clothingItem = await _context.ClothingItems.FindAsync(id);
            if (clothingItem == null) return NotFound();
            return clothingItem;
        }

        // PUT: api/ClothingItems/5
        [HttpPut("{id}")]
        public async Task<IActionResult> PutClothingItem(Guid id, ClothingItemDto dto)
        {
            if (id != dto.Id) return BadRequest();

            var existing = await _context.ClothingItems.FindAsync(id);
            if (existing == null) return NotFound();

            existing.Name = dto.Name;
            existing.Description = dto.Description;
            existing.Category = dto.Category;
            existing.Color = dto.Color;
            existing.Season = dto.Season;
            existing.ImageUrl = dto.ImageUrl;
            existing.IsActive = dto.IsActive;

            try { await _context.SaveChangesAsync(); }
            catch (DbUpdateConcurrencyException)
            {
                if (!ClothingItemExists(id)) return NotFound();
                else throw;
            }

            _rag.TriggerSync(existing.UserId, "wardrobe");
            return NoContent();
        }

        // POST: api/ClothingItems
        [HttpPost]
        public async Task<ActionResult<ClothingItem>> PostClothingItem(ClothingItemDto dto)
        {
            var item = new ClothingItem
            {
                Id = dto.Id ?? Guid.NewGuid(),
                UserId = dto.UserId,
                Name = dto.Name,
                Description = dto.Description,
                Category = dto.Category,
                Color = dto.Color,
                Season = dto.Season,
                ImageUrl = dto.ImageUrl,
                IsActive = dto.IsActive,
                CreatedAt = DateTime.UtcNow,
            };

            _context.ClothingItems.Add(item);
            await _context.SaveChangesAsync();

            _rag.TriggerSync(item.UserId, "wardrobe");
            return CreatedAtAction("GetClothingItem", new { id = item.Id }, item);
        }

        // DELETE: api/ClothingItems/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteClothingItem(Guid id)
        {
            var clothingItem = await _context.ClothingItems.FindAsync(id);
            if (clothingItem == null) return NotFound();

            var userId = clothingItem.UserId;

            var relatedEvals = _context.AiEvaluations
                .Where(e => e.TopItemId == id || e.BottomItemId == id);
            _context.AiEvaluations.RemoveRange(relatedEvals);

            var relatedOutfitItems = _context.OutfitItems
                .Where(o => o.ClothingItemId == id);
            _context.OutfitItems.RemoveRange(relatedOutfitItems);

            _context.ClothingItems.Remove(clothingItem);
            await _context.SaveChangesAsync();

            _rag.TriggerSync(userId, "wardrobe");
            return NoContent();
        }

        private bool ClothingItemExists(Guid id)
            => _context.ClothingItems.Any(e => e.Id == id);
    }
}