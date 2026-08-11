using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace quan_ly_tu_do_API.Models;

[Table("clothing_items")]
[Index("Category", Name = "idx_clothing_items_category")]
[Index("UserId", Name = "idx_clothing_items_user")]
public partial class ClothingItem
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("user_id")]
    public Guid UserId { get; set; }

    [Column("name")]
    [StringLength(150)]
    public string Name { get; set; } = null!;

    [Column("description")]
    public string? Description { get; set; }

    [Column("category")]
    [StringLength(50)]
    public string Category { get; set; } = null!;

    [Column("color")]
    [StringLength(50)]
    public string? Color { get; set; }

    [Column("season")]
    [StringLength(20)]
    public string? Season { get; set; }

    [Column("image_url")]
    public string? ImageUrl { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; }

    [InverseProperty("ClothingItem")]
    public virtual ICollection<OutfitItem> OutfitItems { get; set; } = new List<OutfitItem>();

    [ForeignKey("UserId")]
    [InverseProperty("ClothingItems")]
    public virtual User User { get; set; } = null!;
}
