{
  "fragment" : "#include <metal_stdlib>\nusing namespace metal;\n\ntypedef struct\n{\n   float time;\n} Uniforms;\n\nconstexpr sampler textureSampler (mag_filter::linear, min_filter::linear);\n\n\n\/\/ Protean clouds by nimitz (twitter: @stormoid)\n\/\/ https:\/\/www.shadertoy.com\/view\/3l23Rh\n\/\/ License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License\n\/\/ Contact the author for other licensing options\n\n\/*\n\tTechnical details:\n\n\tThe main volume noise is generated from a deformed periodic grid, which can produce\n\ta large range of noise-like patterns at very cheap evalutation cost. Allowing for multiple\n\tfetches of volume gradient computation for improved lighting.\n\n\tTo further accelerate marching, since the volume is smooth, more than half the the density\n\tinformation isn't used to rendering or shading but only as an underlying volume\tdistance to \n\tdetermine dynamic step size, by carefully selecting an equation\t(polynomial for speed) to \n\tstep as a function of overall density (not necessarialy rendered) the visual results can be \n\tthe\tsame as a naive implementation with ~40% increase in rendering performance.\n\n\tSince the dynamic marching step size is even less uniform due to steps not being rendered at all\n\tthe fog is evaluated as the difference of the fog integral at each rendered step.\n\n*\/\n\nfloat2x2 rot(const float a)\n{\n    float c = cos(a);\n    float s = sin(a);\n    return float2x2(c, s, -s, c);\n}\n\nconstant float3x3 m3 = float3x3(0.33338, 0.56034, -0.71817, -0.87887, 0.32651, -0.15323, 0.15162, 0.69596, 0.61339) * 1.93;\n\nfloat mag2(const float2 p) {\n    return dot(p,p);\n}\n\nfloat linstep(float mn, float mx, float x) {\n    return clamp((x - mn)\/(mx - mn), 0., 1.);\n}\n\nconstant float2 bsMo = float2(0);\n\nfloat2 disp(float t) {\n    return float2(sin(t*0.22)*1., cos(t*0.175)*1.)*2.;\n}\n\nfloat2 map(float3 p, const float prm1, const float time)  \/\/iTime\n{\n    float3 p2 = p;\n    p2.xy -= disp(p.z).xy;\n    p.xy = p.xy * rot(sin(p.z+time)*(0.1 + prm1*0.05) + time * 0.09);\n    float cl = mag2(p2.xy);\n    float d = 0.;\n    p *= .61;\n    float z = 1.;\n    float trk = 1.;\n    float dspAmp = 0.1 + prm1*0.2;\n    for(int i = 0; i < 5; i++)\n    {\n\t\tp += sin(p.zxy*0.75*trk + time*trk*.8)*dspAmp;\n        d -= abs(dot(cos(p), sin(p.yzx))*z);\n        z *= 0.57;\n        trk *= 1.4;\n        p = p*m3;\n    }\n    d = abs(d + prm1*3.)+ prm1*.3 - 2.5 + bsMo.y;\n    return float2(d + cl*.2 + 0.25, cl);\n}\n\nfloat4 render(const float3 ro, const float3 rd, const float time, const float prm1 )\n{\n\tfloat4 rez = float4(0);\n   \/\/const float ldst = 8.;\n\t\/\/float3 lpos = float3(disp(time + ldst)*0.5, time + ldst);\n\tfloat t = 1.5;\n\tfloat fogT = 0.;\n\tfor(int i=0; i<130; i++)\n\t{\n\t\tif(rez.a > 0.99)break;\n\n\t\tfloat3 pos = ro + t*rd;\n        float2 mpv = map(pos, prm1, time);\n\t\tfloat den = clamp(mpv.x-0.3,0.,1.)*1.12;\n\t\tfloat dn = clamp((mpv.x + 2.),0.,3.);\n        \n\t\tfloat4 col = float4(0);\n        if (mpv.x > 0.6)\n        {\n        \n            col = float4(sin(float3(5.,0.4,0.2) + mpv.y*0.1 +sin(pos.z*0.4)*0.5 + 1.8)*0.5 + 0.5,0.08);\n            col *= den*den*den;\n\t\t\tcol.rgb *= linstep(4.,-2.5, mpv.x)*2.3;\n            float dif =  clamp((den - map(pos+.8, prm1, time).x)\/9., 0.001, 1. );\n            dif += clamp((den - map(pos+.35, prm1, time).x)\/2.5, 0.001, 1. );\n            col.xyz *= den*(float3(0.005,.045,.075) + 1.5*float3(0.033,0.07,0.03)*dif);\n        }\n\t\t\n\t\tfloat fogC = exp(t*0.2 - 2.2);\n\t\tcol.rgba += float4(0.06,0.11,0.11, 0.1)*clamp(fogC-fogT, 0., 1.);\n\t\tfogT = fogC;\n\t\trez = rez + col*(1. - rez.a);\n\t\tt += clamp(0.5 - dn*dn*.05, 0.09, 0.3);\n\t}\n\treturn clamp(rez, 0.0, 1.0);\n}\n\nfloat getsat(const float3 c)\n{\n    float mi = min(min(c.x, c.y), c.z);\n    float ma = max(max(c.x, c.y), c.z);\n    return (ma - mi)\/(ma+ 1e-7);\n}\n\n\/\/from my \"Will it blend\" shader (https:\/\/www.shadertoy.com\/view\/lsdGzN)\nfloat3 iLerp(const float3 a, const float3 b, const float x)\n{\n    float3 ic = mix(a, b, x) + float3(1e-6,0.,0.);\n    float sd = abs(getsat(ic) - mix(getsat(a), getsat(b), x));\n    float3 dir = normalize(float3(2.*ic.x - ic.y - ic.z, 2.*ic.y - ic.x - ic.z, 2.*ic.z - ic.y - ic.x));\n    float lgt = dot(float3(1.0), ic);\n    float ff = dot(dir, normalize(ic));\n    ic += 1.5*dir*sd*ff*lgt;\n    return clamp(ic,0.,1.);\n}\n\nkernel void shader(texture2d<float, access::read> texture0 [[texture(0)]],\n                   texture2d<float, access::read> texture1 [[texture(1)]],\n                   texture2d<float, access::read> texture2 [[texture(2)]],\n                   texture2d<float, access::read> texture3 [[texture(3)]],\n                   texture2d<float, access::write> output [[texture(4)]],\n                   constant Uniforms& uniforms [[buffer(0)]],\n                   uint2 gid [[thread_position_in_grid]])\n{\t\n    int width = output.get_width();\n    int height = output.get_height();\n\n\t float2 q = float2(gid) \/ float2(width, height);\n    float2 p = (float2(gid) - 0.5 * float2(width, height)) \/ height;\n\n\t float prm1 = 0.;\n    \n    float time = uniforms.time * 3.;\n    float3 ro = float3(0, 0, time);\n    \n    ro += float3(sin(uniforms.time)*0.5,sin(uniforms.time*1.)*0.,0);\n        \n    float dspAmp = .85;\n    ro.xy += disp(ro.z)*dspAmp;\n    float tgtDst = 3.5;\n    \n    float3 target = normalize(ro - float3(disp(time + tgtDst)*dspAmp, time + tgtDst));\n    ro.x -= bsMo.x*2.;\n    float3 rightdir = normalize(cross(target, float3(0,1,0)));\n    float3 updir = normalize(cross(rightdir, target));\n    rightdir = normalize(cross(updir, target));\n\t float3 rd=normalize((p.x*rightdir + p.y*updir)*1. - target);\n    rd.xy = rd.xy * rot(-disp(time + 3.5).x*0.2 + bsMo.x);\n    prm1 = smoothstep(-0.4, 0.4,sin(uniforms.time * 0.3));\n\t float4 scn = render(ro, rd, time, prm1);\n\t\t\n    float3 col = scn.rgb;\n    col = iLerp(col.bgr, col.rgb, clamp(1.-prm1,0.05,1.));\n    \n    col = pow(col, float3(.55,0.65,0.6))*float3(1.,.97,.9);\n\n    col *= pow( 16.0*q.x*q.y*(1.0-q.x)*(1.0-q.y), 0.12)*0.7+0.3; \/\/Vign\n    \n\t output.write(float4( col, 1.0), gid);\n}\n",
  "textures" : [
    "NULL",
    "NULL",
    "NULL",
    "NULL"
  ]
}