using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace quan_ly_tu_do_API.Models;

[Table("user_preferences")]
[Index("UserId", Name = "UQ__user_pre__B9BE370E18674374", IsUnique = true)]
public partial class UserPreference
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("user_id")]
    public Guid UserId { get; set; }

    [Column("style_preference")]
    [StringLength(100)]
    public string? StylePreference { get; set; }

    [Column("hobbies")]
    public string? Hobbies { get; set; }

    [Column("default_location")]
    [StringLength(255)]
    public string? DefaultLocation { get; set; }

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; }

    [ForeignKey("UserId")]
    [InverseProperty("UserPreference")]
    public virtual User User { get; set; } = null!;
}
