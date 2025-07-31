namespace SprayWallAPI.Contracts
{
    public class UserResponse
    {
        public Guid UserId { get; set; }
        public string Username { get; set; }
        public string? Email { get; set; }
    }
}