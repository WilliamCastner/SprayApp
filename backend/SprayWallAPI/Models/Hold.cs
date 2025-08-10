using Supabase.Postgrest.Attributes;
using Supabase.Postgrest.Models;

namespace SprayWallAPI.Models
{
    [Table("holds")]
    public class Hold : BaseModel
    {
        [PrimaryKey("array_index", false)]
        public short ArrayIndex { get; set; }
    }
}