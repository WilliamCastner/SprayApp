using Supabase.Postgrest.Attributes;
using Supabase.Postgrest.Models;

namespace SprayWallAPI.Models
{
    [Table("climbs")]
    public class Climb : BaseModel
    {
        [PrimaryKey("climbid", false)]
        public Guid ClimbId { get; set; }

        [Column("userid")]
        public Guid UserId { get; set; }

        [Column("name")]
        public string Name { get; set; }

        [Column("grade")]
        public string? Grade { get; set; }

        [Column("notes")]
        public string? Notes { get; set; }

        [Column("createdat")]
        public DateTime CreatedAt { get; set; }
    }