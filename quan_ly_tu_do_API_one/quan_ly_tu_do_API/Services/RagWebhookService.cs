// Services/RagWebhookService.cs
// Inject vào Program.cs: builder.Services.AddScoped<RagWebhookService>();
// Dùng trong các Controller sau khi SaveChangesAsync()

using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace quan_ly_tu_do_API.Services
{
    /// <summary>
    /// Service gọi RAG server để rebuild vector index sau mỗi thay đổi dữ liệu.
    /// Fire-and-forget: không block response trả về client.
    /// </summary>
    public class RagWebhookService
    {
        private readonly HttpClient _http;
        private readonly ILogger<RagWebhookService> _logger;
        private readonly string _ragBaseUrl;
        private readonly string _ragApiKey;

        public RagWebhookService(
            IHttpClientFactory httpClientFactory,
            IConfiguration config,
            ILogger<RagWebhookService> logger)
        {
            _http = httpClientFactory.CreateClient("rag");
            _logger = logger;
            _ragBaseUrl = config["Rag:BaseUrl"] ?? "http://localhost:8000";
            _ragApiKey = config["Rag:ApiKey"] ?? "";
        }

        /// <summary>
        /// data_type: "wardrobe" | "preferences" | "health" | "all"
        /// </summary>
        public void TriggerSync(Guid userId, string dataType)
        {
            // Chạy nền, không await — không làm chậm request chính
            _ = Task.Run(async () =>
            {
                try
                {
                    var payload = new { user_id = userId.ToString(), data_type = dataType };
                    using var req = new HttpRequestMessage(HttpMethod.Post, $"{_ragBaseUrl}/api/sync")
                    {
                        Content = JsonContent.Create(payload)
                    };
                    req.Headers.Add("X-Rag-Key", _ragApiKey);

                    var resp = await _http.SendAsync(req);
                    if (!resp.IsSuccessStatusCode)
                    {
                        var body = await resp.Content.ReadAsStringAsync();
                        _logger.LogWarning("[RAG sync] {StatusCode} — {Body}", resp.StatusCode, body);
                    }
                    else
                    {
                        _logger.LogInformation("[RAG sync] OK — user={UserId} type={Type}", userId, dataType);
                    }
                }
                catch (Exception ex)
                {
                    // RAG server down không nên crash API server
                    _logger.LogError(ex, "[RAG sync] Lỗi gọi RAG server");
                }
            });
        }
    }
}

/*
 * ─── Đăng ký trong Program.cs ────────────────────────────────────────────────
 *
 * builder.Services.AddHttpClient("rag");
 * builder.Services.AddScoped<RagWebhookService>();
 *
 * ─── Thêm vào appsettings.json ───────────────────────────────────────────────
 *
 * "Rag": {
 *   "BaseUrl": "http://localhost:8000",
 *   "ApiKey":  "chuỗi-bí-mật-giống-RAG_API_KEY-trong-.env"
 * }
 *
 * ─── Dùng trong ClothingItemsController ──────────────────────────────────────
 *
 * public class ClothingItemsController : ControllerBase
 * {
 *     private readonly QuanlytudoDbContext _context;
 *     private readonly RagWebhookService _rag;
 *
 *     public ClothingItemsController(QuanlytudoDbContext context, RagWebhookService rag)
 *     {
 *         _context = context;
 *         _rag     = rag;
 *     }
 *
 *     [HttpPost]
 *     public async Task<ActionResult<ClothingItem>> PostClothingItem(ClothingItemDto dto)
 *     {
 *         // ... tạo item, SaveChangesAsync() ...
 *         await _context.SaveChangesAsync();
 *
 *         // Trigger RAG sync (fire-and-forget)
 *         _rag.TriggerSync(item.UserId, "wardrobe");
 *
 *         return CreatedAtAction(...);
 *     }
 * }
 *
 * ─── Tương tự cho các controller khác: ───────────────────────────────────────
 *   - HealthLogsController    → _rag.TriggerSync(userId, "health")
 *   - UserPreferencesController → _rag.TriggerSync(userId, "preferences")
 *   - OutfitsController       → _rag.TriggerSync(userId, "wardrobe")
 *   - OutfitItemsController   → _rag.TriggerSync(userId, "wardrobe")
 */