using Supabase.Postgrest.Attributes;
using Supabase.Postgrest.Models;

namespace SprayWallAPI.Models
{
    [Table("users")]
    public class User : BaseModel
    {
        [PrimaryKey("userid", false)]
        public Guid UserId { get; set; }

        [Column("username")]
        public string Username { get; set; }

        [Column("email")]
        public string? Email { get; set; }

        [Column("createdat")]
        public DateTime CreatedAt { get; set; }

        [Column("password_hash")]
        public string? PasswordHash { get; set; }
    }
}