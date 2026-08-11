using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace quan_ly_tu_do_API.Models;

/// <summary>
/// Lưu lịch sử đánh giá trang phục từ AI (OutfitEvalViewModel → evaluate()).
/// Một bản ghi = user chọn áo + quần và nhận nhận xét từ AI.
/// </summary>
[Table("ai_evaluations")]
[Index("UserId", "CreatedAt", Name = "idx_ai_evaluations_user_date", IsDescending = new[] { false, true })]
public partial class AiEvaluation
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("user_id")]
    public Guid UserId { get; set; }

    // ── Trang phục được đánh giá ──────────────────────────────────────

    [Column("top_item_id")]
    public Guid TopItemId { get; set; }

    /// <summary>Snapshot tên áo (phòng trường hợp item bị xoá)</summary>
    [Column("top_item_name")]
    [StringLength(150)]
    public string TopItemName { get; set; } = null!;

    [Column("bottom_item_id")]
    public Guid BottomItemId { get; set; }

    /// <summary>Snapshot tên quần</summary>
    [Column("bottom_item_name")]
    [StringLength(150)]
    public string BottomItemName { get; set; } = null!;

    // ── Ngữ cảnh ──────────────────────────────────────────────────────

    [Column("destination")]
    [StringLength(150)]
    public string? Destination { get; set; }

    [Column("health_tag")]
    [StringLength(100)]
    public string? HealthTag { get; set; }

    [Column("weather_snapshot")]
    [StringLength(255)]
    public string? WeatherSnapshot { get; set; }

    // ── Kết quả AI ────────────────────────────────────────────────────

    /// <summary>Nội dung nhận xét AI trả về</summary>
    [Column("evaluation_text")]
    public string EvaluationText { get; set; } = null!;

    // ── Phản hồi user ─────────────────────────────────────────────────

    /// <summary>Điểm user tự chấm cho bộ đồ: 1–5 sao, null = chưa chấm</summary>
    [Column("user_rating")]
    public int? UserRating { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; }

    // ── Navigation ────────────────────────────────────────────────────
    [ForeignKey("UserId")]
    public virtual User User { get; set; } = null!;

    [ForeignKey("TopItemId")]
    public virtual ClothingItem TopItem { get; set; } = null!;

    [ForeignKey("BottomItemId")]
    public virtual ClothingItem BottomItem { get; set; } = null!;
}