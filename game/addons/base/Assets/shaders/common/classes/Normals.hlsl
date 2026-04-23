#ifndef NORMALS_HLSL
#define NORMALS_HLSL

#include "common/GBuffer.hlsl"
#include "common/classes/Bindless.hlsl"
#include "common/classes/Depth.hlsl"

int NormalsTextureIndex < Attribute("NormalsTextureIndex");>;

class Normals
{
    /// <summary>
    /// Reconstructs the world-space normal at the given screen position from the depth buffer.
    /// </summary>
    static float3 SampleFromDepth(int2 screenPos)
    {
        float3 posCenter = Depth::GetWorldPosition(screenPos);
        float3 posRight = Depth::GetWorldPosition(screenPos + int2(1, 0));
        float3 posUp = Depth::GetWorldPosition(screenPos + int2(0, 1));

        float3 dx = posRight - posCenter;
        float3 dy = posUp - posCenter;

        return -normalize(cross(dx, dy));
    }

    /// <summary>
    /// Samples the world-space normal at the given screen position.
    /// </summary>
    static float3 Sample(int2 screenPos, uint msaaSampleIndex = 0 )
    {
        // Reconstruct normal from depth buffer if depth normals are not available
        if (NormalsTextureIndex == -1)
            return Normals::SampleFromDepth(screenPos);

        // Load normals from DepthNormals G-buffer
        // Bindless Texture2DMS crashes on AMD RDNA 1/2 in compute shaders,
        // so we use a Texture2D.Load on the MSAA resource instead which defaults to the first sample (0).
        // If you really really want to do an MSAA resolve in compute, which we don't right now, just bind it.
        #if PROGRAM == VFX_PROGRAM_CS
        Texture2D<float4> tDepthNormals = Bindless::GetTexture2D( NormalsTextureIndex );
        float3 normals = tDepthNormals.Load( int3(screenPos + g_vViewportOffset, 0) ).xyz;
        #else
        Texture2DMS<float4> tDepthNormals = Bindless::GetTexture2DMS( NormalsTextureIndex );
        float3 normals = tDepthNormals.Load( screenPos + g_vViewportOffset, msaaSampleIndex ).xyz;
        #endif

        // Rebuild from depth if the normal is invalid
        if( all( normals == 0 ) )
            return Normals::SampleFromDepth(screenPos);
        
        // Convert from [0, 1] to [-1, 1]
        return ( 2.0f * normals - 1.0f );
    }
};

class Roughness
{
    static float Sample(int2 screenPos, uint msaaSampleIndex = 0 )
    {
        // Load roughness from DepthNormals G-buffer
        Texture2DMS<float4> tDepthNormals = Bindless::GetTexture2DMS(NormalsTextureIndex);
        float roughness = tDepthNormals.Load( screenPos + g_vViewportOffset, msaaSampleIndex ).w;

        return roughness;
    }
};
#endif // NORMALS_HLSL