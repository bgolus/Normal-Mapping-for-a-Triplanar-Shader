// Normal Mapping for a Triplanar Shader - Ben Golus 2017
// Screen Space Partial Derivative Cotangent Frame example shader

// Calculates a tangent to world transform in the fragment shader using screen space partial derivatives.
// Based on the ideas in this article by Christian Schüler http://www.thetenthplanet.de/archives/1180
// Expensive, but lets you get tangent space vectors if needed.

Shader "Triplanar/Derivative Cotangents"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [NoScaleOffset] _BumpMap ("Normal Map", 2D) = "bump" {}
    }
    SubShader
    {
        Tags { "LightMode"="ForwardBase" "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            // flip UVs horizontally to correct for back side projection
            #define TRIPLANAR_CORRECT_PROJECTED_U

            // offset UVs to prevent obvious mirroring
            // #define TRIPLANAR_UV_OFFSET

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                half3 worldNormal : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _BumpMap;

            fixed4 _LightColor0;

            // Unity version of http://www.thetenthplanet.de/archives/1180
            float3x3 cotangent_frame( float3 normal, float3 position, float2 uv )
            {
                // get edge vectors of the pixel triangle
                float3 dp1 = ddx( position );
                float3 dp2 = ddy( position ) * _ProjectionParams.x;
                float2 duv1 = ddx( uv );
                float2 duv2 = ddy( uv ) * _ProjectionParams.x;
                // solve the linear system
                float3 dp2perp = cross( dp2, normal );
                float3 dp1perp = cross( normal, dp1 );
                float3 T = dp2perp * duv1.x + dp1perp * duv2.x;
                float3 B = dp2perp * duv1.y + dp1perp * duv2.y;
                // construct a scale-invariant frame
                float invmax = rsqrt( max( dot(T,T), dot(B,B) ) );

                 // matrix is transposed, use mul(VECTOR, MATRIX) order
                return float3x3( T * invmax, B * invmax, normal );
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);

                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                // calculate triplanar blend
                half3 triblend = saturate(pow(i.worldNormal, 4));
                triblend /= max(dot(triblend, half3(1,1,1)), 0.0001);

                // preview blend
                // return fixed4(triblend.xyz, 1);

                // calculate triplanar uvs
                // applying texture scale and offset values ala TRANSFORM_TEX macro
                float2 uvX = i.worldPos.zy * _MainTex_ST.xy + _MainTex_ST.zw;
                float2 uvY = i.worldPos.xz * _MainTex_ST.xy + _MainTex_ST.zw;
                float2 uvZ = i.worldPos.xy * _MainTex_ST.xy + _MainTex_ST.zw;

                // offset UVs to prevent obvious mirroring
            #if defined(TRIPLANAR_UV_OFFSET)
                uvY += 0.33;
                uvZ += 0.67;
            #endif

                // minor optimization of sign(). prevents return value of 0
                half3 axisSign = i.worldNormal < 0 ? -1 : 1;

                // flip UVs horizontally to correct for back side projection
            #if defined(TRIPLANAR_CORRECT_PROJECTED_U)
                uvX.x *= axisSign.x;
                uvY.x *= axisSign.y;
                uvZ.x *= -axisSign.z;
            #endif

                // albedo textures
                fixed4 colX = tex2D(_MainTex, uvX);
                fixed4 colY = tex2D(_MainTex, uvY);
                fixed4 colZ = tex2D(_MainTex, uvZ);
                fixed4 col = colX * triblend.x + colY * triblend.y + colZ * triblend.z;

                // tangent space normal maps
                half3 tnormalX = UnpackNormal(tex2D(_BumpMap, uvX));
                half3 tnormalY = UnpackNormal(tex2D(_BumpMap, uvY));
                half3 tnormalZ = UnpackNormal(tex2D(_BumpMap, uvZ));

                half3 vertexNormal = normalize(i.worldNormal);

                // calculate tangent to world transform matrices for each projection plane
                half3x3 tbnX = cotangent_frame(vertexNormal, i.worldPos, uvX);
                half3x3 tbnY = cotangent_frame(vertexNormal, i.worldPos, uvY);
                half3x3 tbnZ = cotangent_frame(vertexNormal, i.worldPos, uvZ);

                // apply transform and blend together
                half3 worldNormal = normalize(
                    mul(tnormalX, tbnX) * triblend.x +
                    mul(tnormalY, tbnY) * triblend.y +
                    mul(tnormalZ, tbnZ) * triblend.z
                    );

                // preview world normals
                // return fixed4(worldNormal * 0.5 + 0.5, 1);

                // calculate lighting
                half ndotl = saturate(dot(worldNormal, _WorldSpaceLightPos0.xyz));
                half3 ambient = ShadeSH9(half4(worldNormal, 1));
                half3 lighting = _LightColor0.rgb * ndotl + ambient;
                
                // preview directional lighting
                // return fixed4(ndotl.xxx, 1);
                
                return fixed4(col.rgb * lighting, 1);
            }
            ENDCG
        }
    }
}
