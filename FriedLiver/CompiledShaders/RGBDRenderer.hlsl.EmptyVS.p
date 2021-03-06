DXBCїЇdоgГ▌Ї2╒+╬вx\   АO     8   д   ┤   ─   ▄   x  RDEFd               <    ■ 	  <   RD11<          (   $          Microsoft (R) HLSL Shader Compiler 10.1 ISGN          OSGN          SHEX   P     j >  STATФ                                                                                                                                                     SPDB N  Microsoft C/C++ MSF 7.00
DS         '   └       %                                                                                                                                                                                                                                                                                                                                                                                                                                                                           └                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               8   └                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  <                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    Ф.1╬═\   ВЮ№Ў╜ш╦NР0U'╦BЪ╦                          ▄Q3                                                                                                                                                                                                                                                                                                                                                                                                                                                                    D3DSHDR                               `                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        PЕ ╚8                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        #define MINF asfloat(0xff800000)

#define DEPTH_WORLD_MIN 0.1f
#define DEPTH_WORLD_MAX 20.0f

float cameraToKinectProjZ(float z)
{
	return (z - DEPTH_WORLD_MIN)/(DEPTH_WORLD_MAX - DEPTH_WORLD_MIN);
}

float kinectProjZToCamera(float z)
{
	return DEPTH_WORLD_MIN+z*(DEPTH_WORLD_MAX - DEPTH_WORLD_MIN);
}

cbuffer cbRGBDRenderer : register( b0 )
{
	float4x4	g_mIntrinsicInverse;
	float4x4	g_mExtrinsic;		//model-view
	float4x4	g_mIntrinsicNew;	//for 'real-world' depth range
	float4x4	g_mProjection;		//for graphics rendering
	
	uint		g_uScreenWidth;
	uint		g_uScreenHeight;
	uint		g_uDepthImageWidth;
	uint		g_uDepthImageHeight;

	float		g_fDepthThreshOffset;
	float		g_fDepthThreshLin;
	float2		g_vDummy;
};

sampler g_PointSampler : register (s0);
sampler g_LinearSampler : register (s1);

Texture2D<float>	g_ImageDepth	: register(t0);
Texture2D<float4>	g_ImageRGB		: register(t1);


void EmptyVS()
{
}


struct GS_INPUT
{
};

struct PS_INPUT
{
	float4 vPosition		: SV_POSITION;
	float4 camSpacePosition	: POSITION0;
	float4 vNormal			: NORMAL0;
	float2 vTexCoord		: TEXCOORD0;
	float  fDepth			: DE;
	float4 vColor			: COLOR0;
};

struct PS_OUTPUT
{
	float  depth;
	float4 camSpace;
	float4 normal;
	float4 color;
};

float4 getWorldSpacePosition(uint x, uint y)
{
	float d = g_ImageDepth.Load(uint3(x,y,0));
	float4 posCam = mul(float4((float)x*d, (float)y*d, d, d), g_mIntrinsicInverse);
	posCam = float4(posCam.x, posCam.y, posCam.w, 1.0f);

	float4 posWorld = mul(posCam, g_mExtrinsic);
	posWorld /= posWorld.w;

	return posWorld;
}

PS_INPUT ComputeQuadVertex(uint x, uint y)
{
	float d = g_ImageDepth.Load(uint3(x,y,0));
	float4 posWorldCC = getWorldSpacePosition(x, y);

	float4 posWorlMC = getWorldSpacePosition(x-1, y);
	float4 posWorlCM = getWorldSpacePosition(x, y-1);
	float4 posWorlCP = getWorldSpacePosition(x, y+1);
	float4 posWorlPC = getWorldSpacePosition(x+1, y);

	float3 normal = cross(posWorlCP.xyz-posWorlCM.xyz, posWorlPC.xyz-posWorlMC.xyz);
	normal = normalize(normal);

	float4 posClip = mul(float4(posWorldCC.x, posWorldCC.y, posWorldCC.z, 1.0f), g_mIntrinsicNew);
	posClip = float4(posClip.x/posClip.z, posClip.y/posClip.z, posClip.z, 1.0f);

	float fx = ((float)posClip.x / (float)(g_uScreenWidth- 1))*2.0f - 1.0f;
	//float fy = ((float)posClip.y / (float)(g_uScreenHeight-1))*2.0f - 1.0f;
	float fy = 1.0f - ((float)posClip.y / (float)(g_uScreenHeight-1))*2.0f;
	float fz = cameraToKinectProjZ(posClip.z);
	posClip.x = fx;
	posClip.y = fy;
	posClip.z = fz;
	posClip.w = 1.0f;

	PS_INPUT Out;
	Out.camSpacePosition = posWorldCC;
	Out.vPosition = posClip;
	Out.vNormal = float4(normal, 1.0f);
	Out.vTexCoord = float2(0.0f, 0.0f);
	Out.fDepth = d;
	Out.vColor = g_ImageRGB.Load(uint3(x,y,0));

	return Out;
}

[maxvertexcount(4)]
void RGBDRendererGS( point GS_INPUT fake[1], uint quadIdx : SV_PrimitiveID, inout TriangleStream<PS_INPUT> OutStream )
{
	PS_INPUT Out = (PS_INPUT)0;

	uint x = quadIdx % g_uDepthImageWidth;
	uint y = quadIdx / g_uDepthImageWidth;

	float d0 = g_ImageDepth.Load(uint3(x+0, y+0, 0));
	float d1 = g_ImageDepth.Load(uint3(x+0, y+1, 0));
	float d2 = g_ImageDepth.Load(uint3(x+1, y+0, 0));
	float d3 = g_ImageDepth.Load(uint3(x+1, y+1, 0));

	if (d0 <= DEPTH_WORLD_MIN || d1 <= DEPTH_WORLD_MIN || d2 <= DEPTH_WORLD_MIN || d3 <= DEPTH_WORLD_MIN)	return;
	if (d0 == MINF || d1 == MINF || d2 == MINF || d3 == MINF)	return;

	float dmax = max(max(d0, d1), max(d2,d3));
	float dmin = min(min(d0, d1), min(d2,d3));

	float d = 0.5f*(dmax+dmin);
	
	if (dmax - dmin > g_fDepthThreshOffset+g_fDepthThreshLin*d)	return;

	//be aware of the order for CULLING
	OutStream.Append( ComputeQuadVertex(x+0, y+1) );
	OutStream.Append( ComputeQuadVertex(x+0, y+0) );
	OutStream.Append( ComputeQuadVertex(x+1, y+1) );
	OutStream.Append( ComputeQuadVertex(x+1, y+0) );
}

PS_OUTPUT RGBDRendererRawDepthPS( PS_INPUT In) : SV_TARGET
{
	PS_OUTPUT res;
	res.depth = In.fDepth;
	res.camSpace = In.camSpacePosition;
	res.normal = In.vNormal;
	res.color = In.vColor;
	
	return res;
}
                                                                                                                                                                                                                                                                                                                                                                                                                                                             ■я■я      C:\Users\jonat\Documents\BundleFusion-master\BundleFusion\FriedLiver\Shaders\RGBDRenderer.hlsl  c:\users\jonat\documents\bundlefusion-master\bundlefusion\friedliver\shaders\rgbdrenderer.hlsl #define MINF asfloat(0xff800000)

#define DEPTH_WORLD_MIN 0.1f
#define DEPTH_WORLD_MAX 20.0f

float cameraToKinectProjZ(float z)
{
	return (z - DEPTH_WORLD_MIN)/(DEPTH_WORLD_MAX - DEPTH_WORLD_MIN);
}

float kinectProjZToCamera(float z)
{
	return DEPTH_WORLD_MIN+z*(DEPTH_WORLD_MAX - DEPTH_WORLD_Mт0А   zт
*╒                                                               a   (   т0Bюл,C     `   a                                                                                                                                                                                                                                                                                                                                                                                                                  B <   
   cE
   cEMicrosoft (R) HLSL Shader Compiler 10.1   : =hlslFlags 0x801 hlslTarget vs_5_0 hlslEntry EmptyVS    .     ┤                       аEmptyVS    Ї         bшJфь╙┘csрнЦMCс╠  Є   0                   $      *  А   *       Ў                                                                                                                                                                                                                                             ╩18           
                             
                                                                                                                                                                                                                                                                                                                                                                                                                                                            ╩18                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          	/ё                                             @                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      %    Д    EmptyVS   яПn╓    	/ё                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             щ    яПn╓    	/ё                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            IN);
}

cbuffer cbRGBDRenderer : register( b0 )
{
	float4x4	g_mIntrinsicInverse;
	float4x4	g_mExtrinsic;		//model-view
	float4x4	g_mIntrinsicNew;	//for 'real-world' depth range
	float4x4	g_mProjection;		//for graphics rendering
	
	uint		g_uScreenWidth;
	uint		g_uScreenHeight;
	uint		g_uDepthImageWidth;
	uint		g_uDepthImageHeight;

	float		g_fDepthThreshOffset;
	float		g_fDepthThreshLin;
	float2		g_vDummy;
};

sampler g_PointSampler : register (s0);
sampler g_LinearSampler : register (s1    w	1     О ?\   P       ,   l                                          `             	 ╕       d                  EmptyVS none    -║.ё             `                                                          C:\Users\jonat\Documents\BundleFusion-master\BundleFusion\FriedLiver\Shaders\RGBDRenderer.hlsl  ■я■я                                                                                                                                                                                );

Texture2D<float>	g_ImageDepth	: register(t0);
Texture2D<float4>	g_ImageRGB		: register(t1);


void EmptyVS()
{
}


struct GS_INPUT
{
};

struct PS_INPUT
{
	float4 vPosition		: SV_POSITION;
	float4 camSpacePosition	: POSITION0;
	float4 vNormal			: NORMAL0;
	float2 vTexCoord		: TEXCOORD0;
	float  fDepth			: DE;
	float4 vColor			: COLOR0;
};

struct PS_OUTPUT
{
	float  depth;
	float4 camSpace;
	float4 normal;
	float4 color;
};

float4 getWorldSpacePosition(uint x, uint y)
{
	float d = g_ImageDepth.Load(uint3(x,y,0));
	float4 posCam = mul(float4((float)x*d, (float)y*d, d, d), g_mIntrinsicInverse);
	posCam = float4(posCam.x, posCam.y, posCam.w, 1.0f);

	float4 posWorld = mul(posCam, g_mExtrinsic);
	posWorld /= posWorld.w;

	return posWorld;
}

PS_INPUT ComputeQuadVertex(uint x, uint y)
{
	float d = g_ImageDepth.Load(uint3(x,y,0));
	float4 posWorldCC = getWorldSpacePosition(x, y);

	float4 posWorlMC = getWorldSpacePosition(x-1, y);
	float4 posWorlCM = getWorldSpacePosition(x, y-1);
	float4 posWorlCP = getWorldSpacePosition(x, y+1);
	float4 posWorlPC = getWorldSpacePosition(x+1, y);

	float3 normal = cross(posWorlCP.xyz-posWorlCM.xyz, posWorlPC.xyz-posWorlMC.xyz);
	normal = normalize(normal);

	float4 posClip = mul(float4(posWorldCC.x, posWorldCC.y, posWorldCC.z, 1.0f), g_mIntrinsicNew);
	posClip = float4(posClip.x/posClip.z, posClip.y/posClip.z, posClip.z, 1.0f);

	float fx = ((float)posClip.x / (float)(g_uScreenWidth- 1))*2.0f - 1.0f;
	//float fy = ((float)posClip.y / (float)(g_uScreenHeight-1))*2.0f - 1.0f;
	float fy = 1.0f - ((float)posClip.y / (float)(g_uScreenHeight-1))*2.0f;
	float fz = cameraToKinectProjZ(posClip.z);
	posClip.x = fx;
	posClip.y = fy;
	posClip.z = fz;
	posClip.w = 1.0f;

	PS_INPUT Out;
	Out.camSpacePosition = posWorldCC;
	Out.vPosition = posClip;
	Out.vNormal = float4(normal, 1.0f);
	Out.vTexCoord = float2(0.0f, 0.0f);
	Out.fDepth = d;
	Out.vColor = g_ImageRGB.Load(uint3(x,y,0));

	return Out;
}

[maxvertexcount(4)]
void RGBDRendererGS( point GS_INPUT fake[1], uint quadIdx : SV_PrimitiveID, inout TriangleStream<PS_INPUT> OutStream )
{
	PS_INPUT Out = (PS_INPUT)0;

	uint x = quadIdx % g_uDepthImageWidth;
	uint y = quadIdx / g_uDepthImageWidth;

	float d0 = g_ImageDepth.Load(uint3(x+0, y+0, 0));
	float d1 = g_ImageDepth.Load(uint3(x+0, y+1, 0));
	float d2 = g_ImageDepth.Load(uint3(x+1, y+0, 0));
	float d3 = g_ImageDepth.Load(uint3(x+1, y+1, 0));

	if (d0 <= DEPTH_WORLD_MIN || d1 <= DEPTH_WORLD_MIN || d2 <= DEPTH_WORLD_MIN || d3 <= DEPTH_WORLD_MIN)	return;
	if (d0 == MINF || d1 == MINF || d2 == MINF || d3 == MINF)	return;

	float dmax = max(max(d0, d1), max(d2,d3));
	float dmin = min(min(d0, d1), min(d2,d3));

	float d = 0.5f*(dmax+dmin);
	
	if (dmax - dmin > g_fDepthThreshOffset+g_fDepthThreshLin*d)	return;

	//be aware of the order for CULLING
	OutStream.Append( ComputeQuadVertex(x+0, y+1) );
	OutStream.Append( ComputeQuadVertex(x+0, y+0) );
	OutStream.Append( ComputeQuadVertex(x+1, y+1) );
	OutStream.Append( ComputeQuadVertex(x+1, y+0) );
}

PS_OUTPUT RGBDRendererRawDepthPS( PS_INPUT In) : SV_TARGET
{
	PS_OUTPUT res;
	res.depth = In.fDepth;
	res.camSpace = In.camSpacePosition;
	res.normal = In.vNormal;
	res.color = In.vColor;
	
	return res;
}
    └   `                  a                                                                                                                                                                                                                  Ф.1╬═\   ВЮ№Ў╜ш╦NР0U'╦BЪ╦М   /LinkInfo /names /src/headerblock /src/files/c:\users\jonat\documents\bundlefusion-master\bundlefusion\friedliver\shaders\rgbdrenderer.hlsl                       "      
                 ▄Q3                                                                                                                                                                                                                                                                                               ш   T   w  8       4  А   C  $         (      ,         #                                  !   "         	   
                                                                                                                                                                                                                                                                                                                                                                          $                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               