using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;
using quan_ly_tu_do_API.Models;

namespace quan_ly_tu_do_API.Data;

public partial class QuanlytudoDbContext : DbContext
{
    public QuanlytudoDbContext(DbContextOptions<QuanlytudoDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<ClothingItem> ClothingItems { get; set; }

    public virtual DbSet<HealthLog> HealthLogs { get; set; }

    public virtual DbSet<Outfit> Outfits { get; set; }

    public virtual DbSet<OutfitItem> OutfitItems { get; set; }
    public DbSet<AiSuggestion> AiSuggestions { get; set; }
    public DbSet<AiEvaluation> AiEvaluations { get; set; }

    public virtual DbSet<User> Users { get; set; }

    public virtual DbSet<UserPreference> UserPreferences { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.UseCollation("Vietnamese_CI_AS");

        modelBuilder.Entity<ClothingItem>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__clothing__3213E83F4FAD0C52");

            entity.Property(e => e.Id).HasDefaultValueSql("(newid())");
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.Description).HasDefaultValue("");
            entity.Property(e => e.IsActive).HasDefaultValue(true);

            entity.HasOne(d => d.User).WithMany(p => p.ClothingItems).HasConstraintName("FK__clothing___user___440B1D61");
        });

        modelBuilder.Entity<HealthLog>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__health_l__3213E83F542D2A37");

            entity.Property(e => e.Id).HasDefaultValueSql("(newid())");
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.LogDate).HasDefaultValueSql("(CONVERT([date],sysdatetime()))");
            entity.Property(e => e.Notes).HasDefaultValue("");

            entity.HasOne(d => d.User).WithMany(p => p.HealthLogs).HasConstraintName("FK__health_lo__user___5629CD9C");
        });

        modelBuilder.Entity<Outfit>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__outfits__3213E83F884AA858");

            entity.Property(e => e.Id).HasDefaultValueSql("(newid())");
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysdatetime())");

            entity.HasOne(d => d.User).WithMany(p => p.Outfits).HasConstraintName("FK__outfits__user_id__4AB81AF0");
        });

        modelBuilder.Entity<OutfitItem>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__outfit_i__3213E83FB6ABD733");

            entity.Property(e => e.Id).HasDefaultValueSql("(newid())");

            entity.HasOne(d => d.ClothingItem).WithMany(p => p.OutfitItems)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__outfit_it__cloth__5165187F");

            entity.HasOne(d => d.Outfit).WithMany(p => p.OutfitItems).HasConstraintName("FK__outfit_it__outfi__5070F446");
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__users__3213E83FA996A4B7");

            entity.ToTable("users", tb => tb.HasTrigger("trg_users_updated_at"));

            entity.Property(e => e.Id).HasDefaultValueSql("(newid())");
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.UpdatedAt).HasDefaultValueSql("(sysdatetime())");
        });

        modelBuilder.Entity<UserPreference>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__user_pre__3213E83FF081AB45");

            entity.ToTable("user_preferences", tb => tb.HasTrigger("trg_user_preferences_updated_at"));

            entity.Property(e => e.Id).HasDefaultValueSql("(newid())");
            entity.Property(e => e.UpdatedAt).HasDefaultValueSql("(sysdatetime())");

            entity.HasOne(d => d.User).WithOne(p => p.UserPreference).HasConstraintName("FK__user_pref__user___3F466844");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
