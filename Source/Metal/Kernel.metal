//
//  Kernel.metal
//  Nebula
//
//  Created by Zeb Zhao on 6/3/19.
//

#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

float2x2 rot(float a) {
    float c=cos(a), s=sin(a);
    return float2x2(c,-s,s,c);
}

float map(float t, float3 p){
    p.xz = rot(-t*0.31)*p.xz;
    p.xy = rot(t*0.27)*p.xy;
    p.x = sin(0.8*p.x);
    float3 q = p*1.9+t;
    return length(p+float3(sin(t*0.7)))*log(length(p)+1.2) + sin(q.x+sin(q.z+sin(q.y)))*0.7 - 1.;
}

float3 ether(float t, float2 p, float3 baseClr, float3 dynClr) {
    float3 cl = float3(0.);
    float d = 2.5;
    float3 ct = float3(0., 0., 5.);
    p = rot(0.15*36.0*sin(t/36.0))*p;
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

float3 swirl(float t, float2 uv, float3 baseClr, float3 dynClr, float iTransition) {
    float3 cl = float3(0.);
    float2x2 tw = rot(0.15*36.0*sin(t/36.0));
    float d = length(uv);
    float v = 3./(.01 + d);
    float modt = fmod(t, 12.566);
    for (float i=0.; i<3.; i++) {
        float ti = modt + 12.566/3.*i,
        wi = (.5 - .5*cos(.5*ti))/1.5;
        float2 uvi = uv*rot(.3*(-.9 + fract(ti/12.566))*v);
        float2 p = tw*mix(uv, uvi, iTransition);
        cl += ether(t, p, baseClr, dynClr)*wi;
    }
    cl *= mix(1.0, 2.0*exp(-64.*pow(d-.5, 4.)), iTransition);
    return cl;
}

extern "C" {
    namespace coreimage {
        float4 mainImage(float iTime,
                         float2 iResolution,
                         float4 r1,
                         float4 r2,
                         float4 r3,
                         float iTransition,
                         destination dest) {
            float2 p = dest.coord().xy/iResolution.x - float2(.5,.55*iResolution.y/iResolution.x);
            
            float3 c1 = float3(0.1,0.3,.4);
            float3 c2 = float3(5., 2.5, 3.);
            float2x3 ce1 = float2x3(c1.rgg, c2.rbb);
            float2x3 ce2 = float2x3(c1.rgg, c2);
            float2x3 ce3 = float2x3(c1.rbb, c2);
            float2x3 ce4 = float2x3(c1.rrg, c2.grg);
            float2x3 ce5 = float2x3(c1.rrb, c2.grg);
            float2x3 ce6 = float2x3(c1.rrb, c2.brr);
            float2x3 ce7 = float2x3(c1.grb, c2.grb);
            float2x3 ce8 = float2x3(c1, c2.rbr);
            float2x3 ce9 = float2x3(c1.grg, c2.grr);
            float2x3 ce10 = float2x3(c1.brg, c2.brr);
            float2x3 ce11 = float2x3(c1.brb, c2.brb);
            float2x3 ce12 = float2x3(c1.brb, c2.grb);
            
            float mag = sqrt(length_squared(r1) + length_squared(r2) + length_squared(r3));
            r1 = powr(r1, 2.)/mag;
            r2 = powr(r2, 2.)/mag;
            r3 = powr(r3, 2.)/mag;
            float3 e1 = swirl(iTime, p, r1*transpose(float4x3(ce1[0], ce2[0], ce3[0], ce4[0])),
                              r1*transpose(float4x3(ce1[1], ce2[1], ce3[1], ce4[1])), iTransition);
            float3 e2 = swirl(iTime, p, r2*transpose(float4x3(ce5[0], ce6[0], ce7[0], ce8[0])),
                              r2*transpose(float4x3(ce5[1], ce6[1], ce7[1], ce8[1])), iTransition);
            float3 e3 = swirl(iTime, p, r3*transpose(float4x3(ce9[0], ce10[0], ce11[0], ce12[0])),
                              r3*transpose(float4x3(ce9[1], ce10[1], ce11[1], ce12[1])), iTransition);
            float3 et = 0.75*(e1 + e2 + e3);
            float3 w = float3(0.15, 0.2, 0.1);
            return float4(et, saturate(saturate(dot(et, w)) + 0.35 + 0.5*length(p)));
        }
    }
}
