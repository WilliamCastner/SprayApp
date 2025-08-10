using Supabase.Postgrest.Attributes;
using Supabase.Postgrest.Models;

namespace SprayWallAPI.Models
{
    [Table("climbssent")]
    public class ClimbsSent : BaseModel
    {
        [PrimaryKey("sid")]
        public Guid SendId { get; set; }

        [Column("climbid")]
        public int ClimbId{ get; set; }
        
        [Column("id")]
        public Guid UserId { get; set; }
        
        [Column("created_at")]
        public DateTime CreatedAt{ get; set; }
       
        [Column("grade")]
        public string Grade {  get; set; }
    }
}
