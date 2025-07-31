namespace SprayWallAPI.Contracts
{
    public class ClimbHoldRequest
    {
        public short ArrayIndex { get; set; }
        public int HoldState { get; set; } // 1 = hand, 2 = foot, 3 = start
    }
}