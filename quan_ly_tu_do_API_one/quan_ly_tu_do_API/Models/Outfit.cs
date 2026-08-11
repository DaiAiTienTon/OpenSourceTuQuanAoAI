using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace quan_ly_tu_do_API.Models;

[Table("outfits")]
[Index("UserId", Name = "idx_outfits_user")]
public partial class Outfit
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("user_id")]
    public Guid UserId { get; set; }

    [Column("name")]
    [StringLength(150)]
    public string Name { get; set; } = null!;

    [Column("occasion")]
    [StringLength(100)]
    public string? Occasion { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; }

    [InverseProperty("Outfit")]
    public virtual ICollection<OutfitItem> OutfitItems { get; set; } = new List<OutfitItem>();

    [ForeignKey("UserId")]
    [InverseProperty("Outfits")]
    public virtual User User { get; set; } = null!;
}
