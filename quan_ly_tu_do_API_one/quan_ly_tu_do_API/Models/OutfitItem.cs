using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace quan_ly_tu_do_API.Models;

[Table("outfit_items")]
[Index("ClothingItemId", Name = "idx_outfit_items_clothing")]
[Index("OutfitId", Name = "idx_outfit_items_outfit")]
[Index("OutfitId", "ClothingItemId", Name = "uq_outfit_clothing", IsUnique = true)]
public partial class OutfitItem
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("outfit_id")]
    public Guid OutfitId { get; set; }

    [Column("clothing_item_id")]
    public Guid ClothingItemId { get; set; }

    [Column("role")]
    [StringLength(50)]
    public string? Role { get; set; }

    [ForeignKey("ClothingItemId")]
    [InverseProperty("OutfitItems")]
    public virtual ClothingItem ClothingItem { get; set; } = null!;

    [ForeignKey("OutfitId")]
    [InverseProperty("OutfitItems")]
    public virtual Outfit Outfit { get; set; } = null!;
}
