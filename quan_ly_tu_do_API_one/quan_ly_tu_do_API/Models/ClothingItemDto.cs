namespace quan_ly_tu_do_API.DTOs;

public class ClothingItemDto
{
    public Guid? Id { get; set; }
    public Guid UserId { get; set; }
    public string Name { get; set; } = null!;
    public string? Description { get; set; }
    public string Category { get; set; } = null!;
    public string? Color { get; set; }
    public string? Season { get; set; }
    public string? ImageUrl { get; set; }
    public bool IsActive { get; set; } = true;
}