shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform vec2 uv_scale = vec2(1.0, 1.0);

// Updated globally from GDScript every frame
global uniform vec3 player_position;

uniform float radius : hint_range(0.0, 20.0) = 2.5;
uniform float edge_softness : hint_range(0.01, 10.0) = 1.0;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // vec4 tex = texture(albedo_texture, UV) * albedo;
    vec4 tex = texture(albedo_texture, UV * uv_scale) * albedo;
    ALBEDO = tex.rgb;
    ROUGHNESS = roughness;

    // Distance on the horizontal plane only (ignore height)
    float dist = distance(world_pos.xz, player_position.xz);
    float alpha = smoothstep(radius, radius + edge_softness, dist);

    ALPHA = alpha;
}
