Shader "MyRelaxShader/ripple" //Shader的真正名字  可以是路径式的格式
{
	
	Properties 
	{
		_MainTex ("Texture", 2D) = "" {}
		_MainColor("Main Color",Color) = (1,1,1,1)
		_NoiseMap("NoiseMap", 2D) = "" {}
		_Cutout("Cutout", Range(0.0,1.1)) = 0.0
		_Speed("Speed", Vector) = (.34, .85, .92, 1)
	}
	SubShader
	{
		
		Tags { "RenderType"="Opaque" "DisableBatching"="True"} 
		Pass 
		{
			CGPROGRAM  
			//指定一个名为"vert"的函数为顶点Shader
			#pragma vertex vert 
			//指定一个名为"frag"函数为片元Shader
			#pragma fragment frag 
			#include "UnityCG.cginc"  

			
			struct appdata  //CPU向顶点Shader提供的模型数据
			{
				float4 vertex : POSITION; //模型空间顶点坐标
				half2 texcoord0 : TEXCOORD0; //第一套UV
				half2 texcoord1 : TEXCOORD1; //第二套UV
				half2 texcoord2 : TEXCOORD2; //第二套UV
				half2 texcoord4 : TEXCOORD3;  //模型最多只能有4套UV

				half4 color : COLOR; //顶点颜色
				half3 normal : NORMAL; //顶点法线
				half4 tangent : TANGENT; //顶点切线
			};

			struct v2f  //自定义数据结构体，顶点着色器输出的数据，也是片元着色器输入数据
			{
				//输出裁剪空间下的顶点坐标数据，给光栅化使用，必须要写的数据
				float4 pos : SV_POSITION; 
				float4 uv : TEXCOORD0; //自定义数据体
				//注意跟上方的TEXCOORD的意义是不一样的，上方代表的是UV，这里可以是任意数据。
				//插值器：输出后会被光栅化进行插值，而后作为输入数据，进入片元Shader
				//最多可以写16个：TEXCOORD0 ~ TEXCOORD15。
				float3 pos_local : TEXCOORD1;
				//float3 pos_pivot : TEXCOORD2;
			};

			/*
			Shader内的变量声明，如果跟上面Properties模块内的参数Name同名，就可以产生链接
			*/
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _Cutout;
			float4 _Speed;
			sampler2D _NoiseMap;
			float4 _NoiseMap_ST;
			float4 _MainColor;
			
			// 顶点Shader函数
			v2f vert (appdata v)
			{
				v2f o; // 创建一个v2f类型的输出变量，用于存储顶点着色器的输出数据

				// 通用坐标转换：将顶点从模型空间转换到裁剪空间
				// UnityObjectToClipPos(v.vertex) 是一个内置函数，将顶点位置从模型空间转换到裁剪空间
				o.pos = UnityObjectToClipPos(v.vertex);

				// 计算纹理坐标：将原始纹理坐标v.texcoord0进行缩放和偏移
				// _MainTex_ST.xy 是纹理的缩放因子，_MainTex_ST.zw 是平移偏移量
				// 记住这里v.texcoord0乘纹理的缩放加上纹理的偏移
				o.uv.xy = v.texcoord0 * _MainTex_ST.xy + _MainTex_ST.zw;

				// 计算噪声图纹理坐标：同样应用缩放和平移，但是使用 _NoiseMap_ST 来对噪声图进行操作
				// _NoiseMap_ST.xy 是纹理的缩放因子，_NoiseMap_ST.zw 是平移偏移量
				o.uv.zw = v.texcoord0 * _NoiseMap_ST.xy + _NoiseMap_ST.zw;

				// 传递模型的原始顶点坐标到片元Shader
				// v.vertex.xyz 是顶点坐标的 xyz 分量，用于后续操作
				o.pos_local = v.vertex.xyz;

				return o; // 返回顶点着色器的输出，传递给片元着色器
			}

			// 片元Shader函数，接受顶点着色器的输出数据v2f i
			half4 frag (v2f i) : SV_Target // SV_Target 表示片元Shader的输出目标，渲染到屏幕
			{
				// 从_MainTex纹理中采样颜色，根据时间进行偏移，生成渐变效果
				// tex2D(_MainTex, i.uv.xy + _Time.y * 0.1f * _Speed.xy) 是根据当前的纹理坐标和时间动态变化的纹理采样
				// gradient 的值是采样到的颜色的红色通道（.r），并且调整高度（y方向）使得渐变的强度随着y坐标变化
				half gradient = tex2D(_MainTex, i.uv.xy + _Time.y * 0.1f * _Speed.xy).r 
									* (1.0 - i.uv.y);

				// 从 _NoiseMap 纹理中采样噪声，根据时间和速度进行动态偏移，生成噪声效果
				// 采样的红色通道（.r）和它的反值（1.0 - noise）用于后续的剪切
				half noise = 1.0 - tex2D(_NoiseMap, i.uv.zw + _Time.y * 0.1f * _Speed.zw).r;

				// clip 函数根据条件裁剪片元。如果条件为负，片元将被丢弃（即不会渲染到屏幕）
				// gradient 和 noise 是通过时间变化的动态纹理效果，_Cutout 是一个阈值，低于这个阈值的片元会被丢弃
				clip(gradient - noise - _Cutout);

				// 返回最终的颜色，这里使用 _MainColor 作为主颜色输出
				return _MainColor;
			}

			ENDCG // Shader代码从这里结束
		}
	}
}
