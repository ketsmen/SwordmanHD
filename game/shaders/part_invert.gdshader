// SPDX-License-Identifier: GPL-3.0-only
// 原版部件 type 5 / 6 (反色; 静态观察 动画对照_静态观察.md 第 2 节):
//   type 5: 源 XOR 0x7FFF = 源图反色, 不透明覆盖
//   type 6: 底 XOR 0x7FFF = 贴图形状范围内的底色反色 (要读屏幕: 只有 type 6 用这个 shader)
shader_type canvas_item;
uniform bool invert_screen = false;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
void fragment() {
	vec4 s = texture(TEXTURE, UV);
	if (invert_screen) {
		vec3 d = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
		COLOR = vec4(mix(d, vec3(1.0) - d, s.a), 1.0);
	} else {
		COLOR = vec4(vec3(1.0) - s.rgb, s.a);
	}
}
