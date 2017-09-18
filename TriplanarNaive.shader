// Normal Mapping for a Triplanar Shader - Ben Golus 2017
// Naive Method example shader

// This is the example of what not to do, don't use this for anything!

Shader "Triplanar/Naive Method"
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

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                half3 tspace0 : TEXCOORD1;
                half3 tspace1 : TEXCOORD2;
                half3 tspace2 : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _BumpMap;

            fixed4 _LightColor0;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;

                half3 wNormal = UnityObjectToWorldNormal(v.normal);
                half3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);
                // compute bitangent from cross product of normal and tangent
                half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
                // output the tangent space matrix
                o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);

                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                half3 vertexNormal = abs(normalize(half3(i.tspace0.z, i.tspace1.z, i.tspace2.z)));
                half3 triblend = pow(vertexNormal, 4);
                triblend /= max(dot(triblend, half3(1,1,1)), 0.0001);

                // preview blend
                // return fixed4(triblend.xyz, 1);

                // calculate triplanar uvs
                // applying texture scale and offset values ala TRANSFORM_TEX macro
                float2 uvX = i.worldPos.zy * _MainTex_ST.xy + _MainTex_ST.zw;
                float2 uvY = i.worldPos.xz * _MainTex_ST.xy + _MainTex_ST.zw;
                float2 uvZ = i.worldPos.xy * _MainTex_ST.xy + _MainTex_ST.zw;

                // sample the texture
                fixed4 colX = tex2D(_MainTex, uvX);
                fixed4 colY = tex2D(_MainTex, uvY);
                fixed4 colZ = tex2D(_MainTex, uvZ);
                fixed4 col = colX * triblend.x + colY * triblend.y + colZ * triblend.z;

                // tangent space normal map
                half3 tnormalX = UnpackNormal(tex2D(_BumpMap, uvX));
                half3 tnormalY = UnpackNormal(tex2D(_BumpMap, uvY));
                half3 tnormalZ = UnpackNormal(tex2D(_BumpMap, uvZ));
                half3 tnormal = tnormalX * triblend.x + tnormalY * triblend.y + tnormalZ * triblend.z;

                half3 worldNormal = normalize(half3(
                    dot(i.tspace0, tnormal),
                    dot(i.tspace1, tnormal),
                    dot(i.tspace2, tnormal)
                    ));

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
