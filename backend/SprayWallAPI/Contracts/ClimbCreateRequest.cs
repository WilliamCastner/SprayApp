using SprayWallAPI.Contracts;

public class ClimbCreateRequest
{
    public string Name { get; set; }
    public string? Grade { get; set; }
    public string? Notes { get; set; }
    public List<ClimbHoldRequest> Holds { get; set; } = new();
}