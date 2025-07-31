using Supabase.Postgrest.Attributes;
using Supabase.Postgrest.Models;

namespace SprayWallAPI.Models
{
    [Table("climbholds")]
    public class ClimbHold : BaseModel
    {
        [Column("climbid")]
        public Guid ClimbId { get; set; }

        [Column("holdstate")]
        public int HoldState { get; set; }

        [PrimaryKey("array_index", false)]
        public short ArrayIndex { get; set; }
    }
}