namespace SprayWallAPI.Contracts
public class ClimbResponse
{
    public Guid ClimbId { get; set; }
    public string Name { get; set; }
    public string? Grade { get; set; }
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; }
    public List<ClimbHoldResponse> Holds { get; set; } = new();
} 
}