//
//  Kernel.metal
//  Nebula
//
//  Created by Zeb Zhao on 6/3/19.
//

#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

float2x2 m(float a) {
    float c=cos(a), s=sin(a);
    return float2x2(c,-s,s,c);
}

float map(float t, float3 p){
    p.xz = m(t*0.4)*p.xz;
    p.xy = m(t*0.3)*p.xy;
    float3 q = p*2.+t;
    return length(p+float3(sin(t*0.7)))*log(length(p)+1.) + sin(q.x+sin(q.z+sin(q.y)))*0.5 - 1.;
}

float3 ether(float t, float2 p, float3 baseClr, float3 dynClr) {
    float3 cl = float3(0.);
    float d = 2.5;
    float3 ct = float3(0.5*sin(t), 0.5*cos(t+0.1), 5.);
    p = m(0.15*t)*p;
    for(int i=0; i<=5; i++) {
        float3 pt = ct + normalize(float3(p, -1.))*d;
        float rz = map(t, pt);
        float f =  clamp((rz - map(t, pt + .1))*0.5, -.1, 1. );
        float3 l = baseClr + dynClr*f;
        cl = cl*l + smoothstep(2.5, .0, rz)*.7*l;
        d += min(rz, 1.);
    }
    return cl;
}

extern "C" {
    namespace coreimage {
        float4 mainImage(float iTime,
                         float2 iResolution,
                         float4 r1,
                         float4 r2,
                         float4 r3,
                         destination dest) {
            float2 fragCoord = dest.coord().xy/iResolution.xy;
            float2 p = fragCoord.xy - float2(.5,.5);
            float3 c1 = float3(0.1,0.3,.4);
            float3 c2 = float3(5., 2.5, 3.);
            float3 e1 = ether(iTime, p, c1.rgg, c2.rbb);
            float3 e2 = ether(iTime*1.1 + 1., p, c1.rgg, c2);
            float3 e3 = ether(iTime*1.2 + 2., p, c1.rbb, c2);
            float3 e4 = ether(iTime*1.3 + 3., p, c1.rrg, c2.grg);
            float3 e5 = ether(iTime*1.4 + 4., p, c1.rrb, c2.grg);
            float3 e6 = ether(iTime*1.5 + 5., p, c1.rrb, c2.brr);
            float3 e7 = ether(iTime*1.6 + 6., p, c1.grb, c2.grb);
            float3 e8 = ether(iTime*1.7 + 7., p, c1, c2.rbr);
            float3 e9 = ether(iTime*1.8 + 8., p, c1.grg, c2.grr);
            float3 e10 = ether(iTime*1.9 + 9., p, c1.brg, c2.brr);
            float3 e11 = ether(iTime*2.0 + 10., p, c1.brb, c2.brb);
            float3 e12 = ether(iTime*2.1 + 11., p, c1.brb, c2.grb);
            return float4(r1*transpose(float4x3(e1, e2, e3, e4)) +
                          r2*transpose(float4x3(e5, e6, e7, e8)) +
                          r3*transpose(float4x3(e9,e10,e11,e12)), 1.);
        }
    }
}
