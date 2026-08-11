namespace quan_ly_tu_do_API.DTOs;

// ── Request DTOs (client → server) ──────────────────────────────────────────

public class CreateAiSuggestionDto
{
    public Guid UserId { get; set; }
    public string? Destination { get; set; }
    public string? HealthTag { get; set; }
    public string? WeatherSnapshot { get; set; }
    public string SuggestionText { get; set; } = null!;
    /// <summary>"rag" | "worker" | "heuristic"</summary>
    public string Source { get; set; } = "worker";
}

public class FeedbackSuggestionDto
{
    /// <summary>true = hữu ích, false = không hữu ích</summary>
    public bool IsHelpful { get; set; }
    /// <summary>Gắn outfit đã lưu từ gợi ý này (tuỳ chọn)</summary>
    public Guid? SavedOutfitId { get; set; }
}

public class CreateAiEvaluationDto
{
    public Guid UserId { get; set; }
    public Guid TopItemId { get; set; }
    public string TopItemName { get; set; } = null!;
    public Guid BottomItemId { get; set; }
    public string BottomItemName { get; set; } = null!;
    public string? Destination { get; set; }
    public string? HealthTag { get; set; }
    public string? WeatherSnapshot { get; set; }
    public string EvaluationText { get; set; } = null!;
}

public class RateEvaluationDto
{
    /// <summary>1–5 sao</summary>
    public int UserRating { get; set; }
}

// ── Response DTOs (server → client) ─────────────────────────────────────────

public class AiSuggestionResponseDto
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string? Destination { get; set; }
    public string? HealthTag { get; set; }
    public string? WeatherSnapshot { get; set; }
    public string SuggestionText { get; set; } = null!;
    public string Source { get; set; } = null!;
    public bool? IsHelpful { get; set; }
    public Guid? SavedOutfitId { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class AiEvaluationResponseDto
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid TopItemId { get; set; }
    public string TopItemName { get; set; } = null!;
    public Guid BottomItemId { get; set; }
    public string BottomItemName { get; set; } = null!;
    public string? Destination { get; set; }
    public string? HealthTag { get; set; }
    public string? WeatherSnapshot { get; set; }
    public string EvaluationText { get; set; } = null!;
    public int? UserRating { get; set; }
    public DateTime CreatedAt { get; set; }
}