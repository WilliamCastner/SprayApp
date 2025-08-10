using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.IdentityModel.Tokens;
using SprayWallAPI.Contracts;
using SprayWallAPI.Models;
using Supabase;
using Supabase.Interfaces;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Load configuration
var supabaseUrl = builder.Configuration["ConnectionStrings:SupabaseUrl"];
var supabaseKey = builder.Configuration["ConnectionStrings:SupabaseKey"];
var validIssuer = builder.Configuration["Authentication:ValidIssuer"];
var validAudience = builder.Configuration["Authentication:ValidAudience"];

// Add services
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddControllers();

builder.Services.AddAuthorization();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        // Set the Authority to Supabase's issuer URL
        options.Authority = validIssuer;

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = validIssuer,

            ValidateAudience = true,
            ValidAudience = validAudience,

            ValidateIssuerSigningKey = true,
            ValidateLifetime = true
        };

        // Automatically pulls the JWKS from /.well-known/jwks.json
        options.RequireHttpsMetadata = true;
    });

// Register Supabase client
builder.Services.AddScoped<Supabase.Client>(_ =>
    new Supabase.Client(
        supabaseUrl,
        supabaseKey,
        new SupabaseOptions
        {
            AutoRefreshToken = true,
            AutoConnectRealtime = true
        }));

var app = builder.Build();

// Middleware
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseAuthentication();  // Important: authentication must come before authorization
app.UseAuthorization();

// Endpoint: GET /climbs
app.MapGet("/climbs", async (
    HttpContext context,
    Supabase.Client client) =>
{
    // Optional: extract user ID if needed
    // var userId = context.User.FindFirst("sub")?.Value;

    var response = await client
        .From<Climb>()
        .Get();

    if (!response.Models.Any())
        return Results.NotFound();

    var climbs = response.Models.Select(climb => new ClimbResponse
    {
        ClimbId = climb.ClimbId,
        Name = climb.Name,
        Grade = climb.Grade,
        Notes = climb.Notes,
        CreatedAt = climb.CreatedAt,
    }).ToList();

    return Results.Ok(climbs);
});

// Endpoint: POST /climb
app.MapPost("/climb", [Authorize] async (
    HttpContext context,
    ClimbCreateRequest request,
    Supabase.Client client) =>
{
    var userId = context.User.FindFirst("sub")?.Value;

    if (string.IsNullOrEmpty(userId))
        return Results.Unauthorized();

    var climb = new Climb
    {
        Name = request.Name,
        Grade = request.Grade,
        Notes = request.Notes,
        UserId = Guid.Parse(userId)
    };

    await client.From<Climb>().Insert(climb);
    return Results.Ok();
});

app.MapControllers();

app.Run();
