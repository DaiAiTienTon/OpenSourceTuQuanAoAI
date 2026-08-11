using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace quan_ly_tu_do_API.Models;

[Table("users")]
[Index("Email", Name = "UQ__users__AB6E61642261CA56", IsUnique = true)]
public partial class User
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("name")]
    [StringLength(100)]
    public string Name { get; set; } = null!;

    [Column("email")]
    [StringLength(255)]
    public string Email { get; set; } = null!;

    [Column("password_hash")]
    public string PasswordHash { get; set; } = null!;

    [Column("age")]
    public int? Age { get; set; }

    [Column("birth_year")]
    public int? BirthYear { get; set; }

    [Column("avatar_url")]
    public string? AvatarUrl { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; }

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; }

    [InverseProperty("User")]
    public virtual ICollection<ClothingItem> ClothingItems { get; set; } = new List<ClothingItem>();

    [InverseProperty("User")]
    public virtual ICollection<HealthLog> HealthLogs { get; set; } = new List<HealthLog>();

    [InverseProperty("User")]
    public virtual ICollection<Outfit> Outfits { get; set; } = new List<Outfit>();

    [InverseProperty("User")]
    public virtual UserPreference? UserPreference { get; set; }
}
