namespace quan_ly_tu_do_API.Models
{
    /// <summary>
    /// DTO nhận dữ liệu đăng ký từ client.
    /// Đặt tên RegisterRequest (không import Microsoft.AspNetCore.Identity.Data
    /// trong UsersController để tránh CS0104 ambiguous reference).
    /// </summary>
    public class RegisterRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string? DateOfBirth { get; set; }   // "yyyy-MM-dd", map sang Age + BirthYear
        public List<string>? Hobbies { get; set; } // lưu vào UserPreference nếu cần, bỏ qua nếu không
    }
}