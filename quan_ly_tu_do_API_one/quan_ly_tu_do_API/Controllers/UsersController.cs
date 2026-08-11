using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using quan_ly_tu_do_API.Data;
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
    public class UsersController : ControllerBase
    {
        private readonly QuanlytudoDbContext _context;
        private readonly RagWebhookService _rag;

        public UsersController(QuanlytudoDbContext context, RagWebhookService rag)
        {
            _context = context;
            _rag = rag;
        }

        // GET: api/Users
        [HttpGet]
        public async Task<ActionResult<IEnumerable<User>>> GetUsers()
        {
            return await _context.Users.ToListAsync();
        }

        // GET: api/Users/5
        [HttpGet("{id}")]
        public async Task<ActionResult<User>> GetUser(Guid id)
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null) return NotFound();
            return user;
        }

        // PUT: api/Users/5
        [HttpPut("{id}")]
        public async Task<IActionResult> PutUser(Guid id, UpdateUserRequest request)
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null) return NotFound();

            user.Name = request.Name.Trim();
            user.Email = request.Email.Trim();
            user.Age = request.Age;
            user.BirthYear = request.BirthYear;
            user.UpdatedAt = DateTime.UtcNow;

            try { await _context.SaveChangesAsync(); }
            catch (DbUpdateConcurrencyException)
            {
                if (!UserExists(id)) return NotFound();
                else throw;
            }

            return NoContent();
        }

        // POST: api/Users
        [HttpPost]
        public async Task<ActionResult<User>> PostUser(User user)
        {
            _context.Users.Add(user);
            await _context.SaveChangesAsync();
            return CreatedAtAction("GetUser", new { id = user.Id }, user);
        }

        // DELETE: api/Users/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteUser(Guid id)
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null) return NotFound();
            _context.Users.Remove(user);
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // POST: api/Users/login
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Email == request.Email);

            if (user == null || user.PasswordHash != request.Password)
                return Unauthorized("Email hoặc mật khẩu không đúng");

            return Ok(new { token = "dummy-token", userId = user.Id });
        }

        // POST: api/Users/register
        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterRequest request)
        {
            if (await _context.Users.AnyAsync(u => u.Email == request.Email))
                return BadRequest("Email đã tồn tại");

            int? age = null;
            int? birthYear = null;
            if (!string.IsNullOrEmpty(request.DateOfBirth) &&
                DateOnly.TryParse(request.DateOfBirth, out var dob))
            {
                birthYear = dob.Year;
                age = DateTime.Today.Year - dob.Year;
                if (DateTime.Today < new DateTime(DateTime.Today.Year, dob.Month, dob.Day))
                    age--;
            }

            var now = DateTime.UtcNow;
            var user = new User
            {
                Id = Guid.NewGuid(),
                Name = request.Name,
                Email = request.Email,
                PasswordHash = request.Password,
                Age = age,
                BirthYear = birthYear,
                CreatedAt = now,
                UpdatedAt = now,
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            // User mới → báo AI Worker khởi tạo index (rỗng, sẵn sàng cho lần thêm đồ đầu tiên)
            _rag.TriggerSync(user.Id, "all");

            return Ok(new { userId = user.Id });
        }

        // POST: api/Users/check-email
        [HttpPost("check-email")]
        public async Task<IActionResult> CheckEmailExists([FromBody] EmailCheckRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Email))
                return BadRequest("Email không được để trống");

            var exists = await _context.Users
                .AnyAsync(u => u.Email == request.Email.Trim());

            return Ok(new
            {
                exists = exists,
                message = exists ? "Email đã tồn tại" : "Email khả dụng"
            });
        }

        private bool UserExists(Guid id)
            => _context.Users.Any(e => e.Id == id);
    }
}