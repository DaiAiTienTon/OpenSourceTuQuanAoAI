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
    public class OutfitsController : ControllerBase
    {
        private readonly QuanlytudoDbContext _context;

        public OutfitsController(QuanlytudoDbContext context)
        {
            _context = context;
        }

        // GET: api/Outfits
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Outfit>>> GetOutfits()
        {
            return await _context.Outfits.ToListAsync();
        }

        // GET: api/Outfits/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Outfit>> GetOutfit(Guid id)
        {
            var outfit = await _context.Outfits.FindAsync(id);

            if (outfit == null)
            {
                return NotFound();
            }

            return outfit;
        }

        // PUT: api/Outfits/5
        // To protect from overposting attacks, see https://go.microsoft.com/fwlink/?linkid=2123754
        [HttpPut("{id}")]
        public async Task<IActionResult> PutOutfit(Guid id, Outfit outfit)
        {
            if (id != outfit.Id)
            {
                return BadRequest();
            }

            _context.Entry(outfit).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!OutfitExists(id))
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

        // POST: api/Outfits
        // To protect from overposting attacks, see https://go.microsoft.com/fwlink/?linkid=2123754
        [HttpPost]
        public async Task<ActionResult<Outfit>> PostOutfit(Outfit outfit)
        {
            _context.Outfits.Add(outfit);
            await _context.SaveChangesAsync();

            return CreatedAtAction("GetOutfit", new { id = outfit.Id }, outfit);
        }

        // DELETE: api/Outfits/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteOutfit(Guid id)
        {
            var outfit = await _context.Outfits.FindAsync(id);
            if (outfit == null)
            {
                return NotFound();
            }

            _context.Outfits.Remove(outfit);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private bool OutfitExists(Guid id)
        {
            return _context.Outfits.Any(e => e.Id == id);
        }
    }
}
