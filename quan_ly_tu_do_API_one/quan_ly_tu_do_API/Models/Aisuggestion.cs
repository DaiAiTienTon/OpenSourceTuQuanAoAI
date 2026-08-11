using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace quan_ly_tu_do_API.Models;

/// <summary>
/// Lưu lịch sử gợi ý trang phục từ AI (HomeTab → suggestOutfit).
/// Một bản ghi = một lần AI đề xuất bộ trang phục cho user.
/// </summary>
[Table("ai_suggestions")]
[Index("UserId", "CreatedAt", Name = "idx_ai_suggestions_user_date", IsDescending = new[] { false, true })]
public partial class AiSuggestion
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("user_id")]
    public Guid UserId { get; set; }

    // ── Ngữ cảnh lúc gợi ý ────────────────────────────────────────────

    /// <summary>Địa điểm / tag đích (vd: "Đi làm", "Đi chơi", "")</summary>
    [Column("destination")]
    [StringLength(150)]
    public string? Destination { get; set; }

    /// <summary>Tag sức khoẻ user chọn (vd: "Khoẻ mạnh", "Mệt mỏi")</summary>
    [Column("health_tag")]
    [StringLength(100)]
    public string? HealthTag { get; set; }

    /// <summary>Snapshot thời tiết lúc gợi ý (vd: "Nắng, 32°C, Độ ẩm 75%")</summary>
    [Column("weather_snapshot")]
    [StringLength(255)]
    public string? WeatherSnapshot { get; set; }

    // ── Kết quả AI trả về ─────────────────────────────────────────────

    /// <summary>Nội dung AI gợi ý (markdown/plain text)</summary>
    [Column("suggestion_text")]
    public string SuggestionText { get; set; } = null!;

    /// <summary>Nguồn gợi ý: "rag" | "worker" | "heuristic"</summary>
    [Column("source")]
    [StringLength(30)]
    public string Source { get; set; } = "worker";

    // ── Phản hồi của user ─────────────────────────────────────────────

    /// <summary>null = chưa phản hồi, true = hữu ích, false = không hữu ích</summary>
    [Column("is_helpful")]
    public bool? IsHelpful { get; set; }

    /// <summary>ID outfit user tạo từ gợi ý này (nếu có)</summary>
    [Column("saved_outfit_id")]
    public Guid? SavedOutfitId { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; }

    // ── Navigation ────────────────────────────────────────────────────
    [ForeignKey("UserId")]
    public virtual User User { get; set; } = null!;

    [ForeignKey("SavedOutfitId")]
    public virtual Outfit? SavedOutfit { get; set; }
}