// SPDX-License-Identifier: GPL-3.0-only
// 原版部件 type 3 / 4 (纯色着色, 参数 p12 = RGB555 常量色; 静态观察 第 2 节):
//   type 3: 结果 = 底 * p10/16 + 色 * p8/16        (按贴图形状加一块纯色, 源图颜色不用)       => src_k = 0, dst_keep = p10/16
//   type 4: 结果 = 源 * p10/16 + 色 * p8/16, 覆盖底   (源图变暗再叠纯色; p8=p10=0 即黑色剪影)  => src_k = p10/16, dst_keep = 0
// 预乘 alpha 混合: out = c + dst * (1 - a); 与 screen_blend.gdshader 同样不读屏幕纹理。
shader_type canvas_item;
render_mode blend_premul_alpha;
uniform vec3 col = vec3(1.0);
uniform float col_k = 1.0;
uniform float src_k = 0.0;
uniform float dst_keep = 1.0;
void fragment() {
	vec4 s = texture(TEXTURE, UV);
	vec3 c = (s.rgb * src_k + col * col_k) * s.a;
	COLOR = vec4(c, s.a * (1.0 - dst_keep));
}
