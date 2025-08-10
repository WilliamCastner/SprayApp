using SprayWallAPI.Contracts;

public class ClimbCreateRequest
{
    public Guid UserId { get; set; }
    public string Name { get; set; }
    public string? Grade { get; set; }
    public string? Notes { get; set; }
}