// Models/UpdateUserRequest.cs — tạo file mới
namespace quan_ly_tu_do_API.Models
{
    public class UpdateUserRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public int? Age { get; set; }
        public int? BirthYear { get; set; }
    }
}