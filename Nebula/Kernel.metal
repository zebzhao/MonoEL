//
//  Kernel.metal
//  Nebula
//
//  Created by Zeb Zhao on 6/3/19.
//

#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

constant float3 brf = float3(5.,0.4,0.2);
constant float3 brf2 = float3(0.033,0.07,0.03);
constant float3 brf3 = float3(0.005,.045,.075);
constant float4 brf4 = float4(0.06,0.11,0.11, 0.1);
constant float3x3 m3 = float3x3(0.33338, 0.56034, -0.71817, -0.87887, 0.32651, -0.15323, 0.15162, 0.69596, 0.61339)*1.93;

float2x2 rot(float a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(c,s,-s,c);
}

float mag2(float2 p)
{
    return dot(p,p);
}

float linstep(float mn, float mx, float x){
    return saturate((x - mn)/(mx - mn));
}

float2 disp(float t)
{
    return float2(sin(t*0.22), cos(t*0.175))*2.;
}

float2 map(float3 p, float iTime, float pColor, float2 bsMo, float pDetail)
{
    float3 p2 = p;
    p2.xy -= disp(p.z).xy;
    p.xy = rot(sin(p.z+iTime)*(0.1 + pColor*0.05) + iTime*0.09)*p.xy;
    float cl = mag2(p2.xy);
    float d = 0.;
    p *= .61;
    float z = 1.;
    float trk = 1.;
    float dspAmp = 0.1 + pColor*0.2;
    for(short i = 0; i < 5; i++)
    {
        p += sin(p.zxy*0.75 + iTime*.8)*dspAmp*trk;
        d -= abs(dot(cos(p), sin(p.yzx))*z);
        z *= 0.57;
        trk *= 1.4;
        p = p*m3*pDetail;
    }
    d = abs(d + pColor*3.)+ pColor*.3 - 2. + bsMo.y;
    return float2(d + cl*.2 + 0.25, cl);
}

float getsat(float3 c)
{
    float mi = min3(c.x, c.y, c.z);
    float ma = max3(c.x, c.y, c.z);
    return (ma - mi)/(ma + 1e-7);
}

//from my "Will it blend" shader (https://www.shadertoy.com/view/lsdGzN)
float3 iLerp(float3 a, float3 b, float x)
{
    float3 ic = mix(a, b, x) + float3(1e-6,0.,0.);
    float sd = abs(getsat(ic) - mix(getsat(a), getsat(b), x));
    float3 dir = normalize(float3(2.*ic.x - ic.y - ic.z, 2.*ic.y - ic.x - ic.z, 2.*ic.z - ic.y - ic.x));
    float lgt = ic[0] + ic[1] + ic[2];
    float ff = dot(dir, normalize(ic));
    ic += 1.5*dir*sd*ff*lgt;
    return saturate(ic);
}

float4 render(float3 ro, float3 rd, float iTime, float2 bsMo, float pColor, float pDetail )
{
    float4 rez = float4(0);
    float t = 1.5;
    float fogT = 0.;
//    float prm1 = smoothstep(-0.4, 0.4,sin(iTime*0.3));
    
    for(short i=0; i<100; i++)
    {
        if(rez.a > 0.99) break;
        
        float3 pos = ro + t*rd;
        float2 mpv = map(pos, iTime, pColor, bsMo, pDetail);
        float den = saturate(mpv.x - 0.3)*1.12;
        float dn = clamp((mpv.x + 2.),0.,3.);
        
        float4 col = float4(0);
        if (mpv.x > 0.6)
        {
            
            col = float4(sin(brf + mpv.y*0.1 +sin(pos.z*0.4)*0.5 + 1.8)*0.5 + 0.5,0.08);
            col *= den*den*den;
            col.rgb *= linstep(4.,-2.5, mpv.x)*2.3;
            float dif =  clamp((den - map(pos+.8, iTime, pColor, bsMo, pDetail).x)/9., 0.001, 1. );
            dif += clamp((den - map(pos+.35, iTime, pColor, bsMo, pDetail).x)/2.5, 0.001, 1. );
            col.xyz *= den*(brf3 + 1.5*brf2*dif);
        }
        
        float fogC = exp(t*0.2 - 2.2);
        col.rgba += brf4*saturate(fogC - fogT);
        fogT = fogC;
        rez = rez + col*(1. - rez.a);
        t += clamp(0.5 - dn*dn*.05, 0.09, 0.3);
    }
    return saturate(rez);
}

// ---

constant float TAU = 3.1415926535*2.0;
constant float PEAKS = 12.0;
constant float BRIGHTNESS = 0.05;
constant float4 R = float4(0.22487037, 0.68850972, 0.22487037, 0.8256673);
constant float4 G = float4(0.54558713, 0.37599467, 0.54558713, 0.34957688);
constant float4 B = float4(0.8256673, 0.34957688, 0.8256673, 0.44279738);

float mod(float x, float y) {
    return x - floor(x/y)*y;
}

extern "C" {
    namespace coreimage {
        float4 wheelShader(
                           float iTime,
                           float2 resolution,
                           float4 pitchRange1,
                           float4 pitchRange2,
                           float4 pitchRange3,
                           destination dest)
        {
            float2 fragCoord = dest.coord().xy;
            float2 p = (2.0*fragCoord.xy-resolution.xy)/resolution.y;
            float a = atan2(p.y, p.x)/TAU;
            float d = 2.0*length(p);
            
            //get the color
            int2 indices = int2(mod(4.0*a, 4.0), mod(4.0*a + 1.0, 4.0));
            float3 color = mix(float3(R[indices[0]], G[indices[0]], B[indices[0]]),
                               float3(R[indices[1]], G[indices[1]], B[indices[1]]), fract(4.0*a));
            // draw color beam
            short ia = short(12.0*(a + 0.5)) % 12;
            float pitchStr;
            if (ia > 7) {
                pitchStr = pitchRange3[ia];
            }
            else if (ia > 3) {
                pitchStr = pitchRange2[ia];
            }
            else {
                pitchStr = pitchRange1[ia];
            }
            float beamWidth = (1.0 + clamp(pitchStr, 0.0, 0.6)*sin(TAU*a*PEAKS)) * BRIGHTNESS / abs(d - 1.0);
            float3 circleCol = color*float3(beamWidth);
            
            // Normalized pixel coordinates (from 0 to 1)
            float2 uv = fragCoord/resolution.xy;
            // move image right, flip left horizontally
            if (uv.x < .5){
                uv.x = -uv.x+.5;
            } else {
                uv.x = uv.x-.5;
            }
            // Apply FFT
            float distFromMid = pow(abs(.5-uv.y), 1.2);
            float edge = resolution.y/resolution.x/4.0;
            float scl = step(edge, uv.x);
            uv.x = saturate(uv.x - edge);
            float lineStr;
            short ix = int(uv.x*12.0);
            if (ia > 7) {
                lineStr = pitchRange3[ix];
            }
            else if (ia > 3) {
                lineStr = pitchRange2[ix];
            }
            else {
                lineStr = pitchRange1[ix];
            }
            lineStr = clamp(lineStr*abs(sin(6*TAU*uv.x)), 0.1, 1.0);
            float3 lineCol = color*0.002*lineStr*scl/distFromMid;
            // Output to screen
            return float4(circleCol + lineCol, 1.0);
        }
        
        float4 cloudsShader(
                      float iTime,
                      float2 mouse,
                      float2 resolution,
                      float pDetail,
                      float pColor,
                      float pDodgeHigh,
                      float pDodgeMid,
                      destination dest)
        {
            float2 fragCoord = dest.coord().xy;
            float2 q = fragCoord.xy/resolution.xy;
            float2 p = (fragCoord.xy - 0.5*resolution.xy)/resolution.y;
            float2 bsMo = (mouse.xy - 0.5*resolution.xy)/resolution.y;
            
            float time = iTime*3.;
            float3 ro = float3(0,0,time);
            
            ro += float3(sin(iTime)*0.5,0.,0.);
            
            float dspAmp = .85;
            ro.xy += disp(ro.z)*dspAmp;
            float tgtDst = 3.5;

            float3 target = normalize(ro - float3(disp(time + tgtDst)*dspAmp, time + tgtDst));
            ro.x -= bsMo.x*2.;
            float3 rightdir = normalize(cross(target, float3(0,1,0)));
            float3 updir = normalize(cross(rightdir, target));
            rightdir = normalize(cross(updir, target));
            float3 rd=normalize((p.x*rightdir + p.y*updir)*1. - target);
            rd.xy = rot(-disp(time + 3.5).x*0.2 + bsMo.x)*rd.xy;
            float4 scn = render(ro, rd, time, bsMo, pColor, pDetail);
            
            float3 col = scn.rgb;
            
            col = iLerp(col.bgr, col.rgb, clamp(1.-pColor,0.05,1.));
            
            col = pDodgeMid*pow(col, float3(.55,0.65,0.6))*float3(1.,.97,.9);
            
            col = pDodgeHigh*(pow( 16.0*q.x*q.y*(1.0-q.x)*(1.0-q.y), 0.12)*0.7+0.3)*col; //Vign
            
            return float4( col[0], col[1], col[2], 1.0 );
        }
    }
}
