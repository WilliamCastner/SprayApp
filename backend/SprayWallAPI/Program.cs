using SprayWallAPI.Models;
using Supabase;
using Supabase.Interfaces;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddScoped<Supabase.Client>(_ =>
new Supabase.Client(
    builder.Configuration["ConnectionStrings:SupabaseUrl"],
    builder.Configuration["ConnectionStrings:SupabaseKey"],
    new SupabaseOptions
    {
        AutoRefreshToken = true,
        AutoConnectRealtime = true
    }));

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.MapPost("/climb", async (
    ClimbCreateRequest request,
    Supabase.Client client) =>
{
    var climb = new Climb
    {
        Name = request.Name,
    };
});

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
