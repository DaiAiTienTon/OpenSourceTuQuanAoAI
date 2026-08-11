using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using System.Text.Json.Serialization;
namespace quan_ly_tu_do_API.Models;

[Table("health_logs")]
[Index("UserId", "LogDate", Name = "idx_health_logs_user_date", IsDescending = new[] { false, true })]
[Index("UserId", "LogDate", Name = "uq_health_user_date", IsUnique = true)]
public partial class HealthLog
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("user_id")]
    public Guid UserId { get; set; }

    [Column("log_date")]
    public DateOnly LogDate { get; set; }

    [Column("heart_rate")]
    [StringLength(20)]
    public string? HeartRate { get; set; }

    [Column("blood_pressure")]
    [StringLength(20)]
    public string? BloodPressure { get; set; }

    [Column("weight", TypeName = "decimal(5, 2)")]
    public decimal? Weight { get; set; }

    [Column("sleep_hours", TypeName = "decimal(4, 2)")]
    public decimal? SleepHours { get; set; }

    [Column("notes")]
    public string? Notes { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; }

    [ForeignKey("UserId")]
    [InverseProperty("HealthLogs")]
    [JsonIgnore]
    public virtual User? User { get; set; }
}
