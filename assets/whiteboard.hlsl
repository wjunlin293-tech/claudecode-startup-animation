// Whiteboard marker filter for Windows Terminal (experimental.pixelShaderPath)
// Static by default: slight hand-drawn wobble, ink bleed and paper grain.
// Tweak the three constants below; set BOIL to 1.0 for a gentle "line boil" animation.

Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings {
    float  Time;
    float  Scale;
    float2 Resolution;
    float4 Background;
};

static const float WOBBLE_PX = 0.0;   // how far lines wander, in pixels
static const float BLEED     = 0.0;   // 0 = crisp, 0.5 = soft marker edges
static const float GRAIN     = 0.018; // paper grain strength
static const float BOIL      = 0.0;   // 0 = still, 1 = slow wobble animation

float hash(float2 p)
{
    return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float2 px = tex * Resolution;
    float t = floor(Time * 4.0) * BOIL;

    // low-frequency wobble, like a hand that is not perfectly steady
    float2 n = float2(vnoise(px / 38.0 + t), vnoise(px / 38.0 + 17.3 + t)) - 0.5;
    float2 uv = tex + n * 2.0 * WOBBLE_PX * Scale / Resolution;

    float4 c = shaderTexture.Sample(samplerState, uv);

    // ink bleed: pull in a little of the darkest neighbour
    float2 o = Scale / Resolution;
    float4 s1 = shaderTexture.Sample(samplerState, uv + float2( o.x, 0));
    float4 s2 = shaderTexture.Sample(samplerState, uv + float2(-o.x, 0));
    float4 s3 = shaderTexture.Sample(samplerState, uv + float2(0,  o.y));
    float4 s4 = shaderTexture.Sample(samplerState, uv + float2(0, -o.y));
    float4 darkest = min(min(s1, s2), min(s3, s4));
    c.rgb = lerp(c.rgb, min(c.rgb, darkest.rgb), BLEED);

    // paper grain
    float g = (hash(floor(px)) - 0.5) * GRAIN;
    c.rgb = saturate(c.rgb + g);

    return c;
}
