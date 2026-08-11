using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quan_ly_tu_do_API.Data;
using quan_ly_tu_do_API.Models;

namespace quan_ly_tu_do_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class OutfitItemsController : ControllerBase
    {
        private readonly QuanlytudoDbContext _context;

        public OutfitItemsController(QuanlytudoDbContext context)
        {
            _context = context;
        }

        // GET: api/OutfitItems
        [HttpGet]
        public async Task<ActionResult<IEnumerable<OutfitItem>>> GetOutfitItems()
        {
            return await _context.OutfitItems.ToListAsync();
        }

        // GET: api/OutfitItems/5
        [HttpGet("{id}")]
        public async Task<ActionResult<OutfitItem>> GetOutfitItem(Guid id)
        {
            var outfitItem = await _context.OutfitItems.FindAsync(id);

            if (outfitItem == null)
            {
                return NotFound();
            }

            return outfitItem;
        }

        // PUT: api/OutfitItems/5
        // To protect from overposting attacks, see https://go.microsoft.com/fwlink/?linkid=2123754
        [HttpPut("{id}")]
        public async Task<IActionResult> PutOutfitItem(Guid id, OutfitItem outfitItem)
        {
            if (id != outfitItem.Id)
            {
                return BadRequest();
            }

            _context.Entry(outfitItem).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!OutfitItemExists(id))
                {
                    return NotFound();
                }
                else
                {
                    throw;
                }
            }

            return NoContent();
        }

        // POST: api/OutfitItems
        // To protect from overposting attacks, see https://go.microsoft.com/fwlink/?linkid=2123754
        [HttpPost]
        public async Task<ActionResult<OutfitItem>> PostOutfitItem(OutfitItem outfitItem)
        {
            _context.OutfitItems.Add(outfitItem);
            await _context.SaveChangesAsync();

            return CreatedAtAction("GetOutfitItem", new { id = outfitItem.Id }, outfitItem);
        }

        // DELETE: api/OutfitItems/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteOutfitItem(Guid id)
        {
            var outfitItem = await _context.OutfitItems.FindAsync(id);
            if (outfitItem == null)
            {
                return NotFound();
            }

            _context.OutfitItems.Remove(outfitItem);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private bool OutfitItemExists(Guid id)
        {
            return _context.OutfitItems.Any(e => e.Id == id);
        }
    }
}
