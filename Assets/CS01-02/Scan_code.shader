
Shader "Unlit/Scan_Code"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RimMin("RimMin", Range(-1,1)) = 0.0
        _RimMax("RimMax", Range(0,2)) = 1.0
        _InnerColor("Inner Color", Color) = (0,0,0,0)   
        _RimColor("Rim Color", Color) = (1,1,1,1)
        _RimIntensity("Rim Intensity", Float) = 1.0
        _FlowTilling("Flow Tilling", Vector) = (1,1,0,0)
        _FlowSpeed("Flow Speed", Vector) = (1,1,0,0)
        _FlowTex("Flow Tex", 2D) = "white" {}
        _FlowIntensity("Flow Intensity", Float) = 0.5
        _InnerAlpha("Inner Alpha", Range(0.0,1.0)) = 0.0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" }
        LOD 100

        Pass
        {
            ZWrite Off
            Blend SrcAlpha One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 pos_world : TEXCOORD1;
                float3 normal_world : TEXCOORD2;
                float3 pivot_world : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _RimMin;
            float _RimMax;
            float4 _InnerColor;  
            float4 _RimColor;
            float _RimIntensity;
            float4 _FlowTilling;
            float4 _FlowSpeed;
            sampler2D _FlowTex;
            float _FlowIntensity;
            float _InnerAlpha;

            v2f vert (appdata v)
            {
                v2f o;
                // 标准转换
                o.pos = UnityObjectToClipPos(v.vertex);
                // frag需要用到转换后的世界空间法线和位置
                float3 normal_world = mul((float3x3)unity_WorldToObject, v.normal); 
                float3 pos_world = mul(unity_ObjectToWorld, v.vertex).xyz;
                // normalize归一化函数
                o.normal_world = normalize(normal_world);
                o.pos_world = pos_world;
                // 物体中心点的世界坐标,用于流动纹理的uv计算,相对位置才不会在物体运动时产生偏移
                o.pivot_world = mul(unity_ObjectToWorld, float4(0.0, 0.0, 0.0, 1.0)).xyz; 
                o.uv = v.texcoord;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                half3 normal_world = normalize(i.normal_world);
                // 视线方向
                half3 view_world = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);
                // 计算计算视线和法线角度,越近越大
                half NdotV = saturate(dot(normal_world, view_world));

                half fresnel = 1.0 - NdotV;
                fresnel = smoothstep(_RimMin, _RimMax, fresnel);
                half emiss = tex2D(_MainTex, i.uv).r;
                emiss = pow(emiss, 5.0);
                
                // 边缘光
                half final_fresnel = saturate(fresnel + emiss);
                // 内侧颜色和边缘颜色插值
                half3 final_rim_color = lerp(_InnerColor.xyz, _RimColor.xyz * _RimIntensity, final_fresnel);
                // 最终边缘透明度
                half final_rim_alpha = final_fresnel;
                // 流动纹理
                half2 uv_flow = (i.pos_world.xy - i.pivot_world.xy) * _FlowTilling.xy;
                // 时间偏移
                uv_flow = uv_flow + _Time.y * _FlowSpeed.xy;
                float4 flow_rgba = tex2D(_FlowTex, uv_flow) * _FlowIntensity;
                // 最终颜色和透明度叠加
                float3 final_col = final_rim_color + flow_rgba.xyz;
                float final_alpha = saturate(final_rim_alpha + flow_rgba.a + _InnerAlpha);
                return float4(final_col, final_alpha);
            }
            ENDCG
        }
    }
}