//
//  AppDelegate.swift
//  MetalToy
//
//  Created by Toni Jovanoski on 8/20/17.
//  Copyright © 2017 Toni Jovanoski. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

typedef struct
{
    packed_float2 position;
} Vertex;

typedef struct
{
    float4 fragCoord [[position]];
} FragmentData;

// Vertex Function
vertex FragmentData
vertexShader(uint               vertexID                [[vertex_id]],
             constant   Vertex  *vertices               [[buffer(0)]])
{
    FragmentData out;
    
    out.fragCoord = float4(0.0, 0.0, 0.0, 1.0);
    
    float2 pixelSpacePosition = vertices[vertexID].position;
    
    out.fragCoord.xy = pixelSpacePosition;
    
    return out;
}

// Fragment function
fragment float4 fragmentShader(FragmentData in [[stage_in]],
                               constant   float2  *resolution    [[buffer(0)]])
{
    float2 uv = in.fragCoord.xy / *resolution;
    
    return float4(uv, 0.0, 1.0);
}

