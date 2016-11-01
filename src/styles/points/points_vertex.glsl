uniform vec2 u_resolution;
uniform float u_time;
uniform vec3 u_map_position;
uniform vec4 u_tile_origin;
uniform float u_tile_proxy_depth;
uniform float u_meters_per_pixel;
uniform float u_device_pixel_ratio;
uniform float u_visible_time;
uniform bool u_fade_in;

uniform mat4 u_model;
uniform mat4 u_modelView;
uniform mat3 u_normalMatrix;
uniform mat3 u_inverseNormalMatrix;

attribute vec4 a_position;
attribute vec4 a_shape;
attribute float a_pre_angle;
attribute vec4 a_pre_angles;
attribute vec4 a_angles;
attribute vec3 a_stops;
attribute vec4 a_color;
attribute vec2 a_texcoord;
attribute vec2 a_offset;
attribute vec4 a_offsets;

#define TANGRAM_NORMAL vec3(0., 0., 1.)

varying vec4 v_color;
varying vec2 v_texcoord;
varying vec4 v_world_position;

#ifdef TANGRAM_MULTI_SAMPLER
varying float v_sampler;
#endif

#pragma tangram: camera
#pragma tangram: material
#pragma tangram: lighting
#pragma tangram: raster
#pragma tangram: global

vec2 rotate2D(vec2 _st, float _angle) {
    return mat2(cos(_angle),-sin(_angle),
                sin(_angle),cos(_angle)) * _st;
}

void main() {
    // Initialize globals
    #pragma tangram: setup

    v_color = a_color;
    v_texcoord = a_texcoord;

    // Position
    vec4 position = u_modelView * vec4(a_position.xyz, 1.);

    // Apply positioning and scaling in screen space
    vec2 shape = a_shape.xy / 256.;                 // values have an 8-bit fraction
    vec2 offset = vec2(a_offset.x, -a_offset.y);    // flip y to make it point down

    float zoom = fract(u_map_position.z);
    float theta = a_shape.z / 4096.;
    float pre_angle = a_pre_angle;
    float w;

    if (zoom < a_stops[0]){
        w = zoom / a_stops[0];
        theta = mix(a_angles[0], a_angles[1], w);
        offset.x = mix(a_offsets[0], a_offsets[1], w);
        pre_angle = mix(a_pre_angles[0], a_pre_angles[1], w);
        // theta = a_angles[0] / 4096.;
        // offset.x = a_offsets[0];
    }
    else if (zoom < a_stops[1]){
        w = (zoom - a_stops[0]) / (a_stops[1] - a_stops[0]);
        theta = mix(a_angles[1], a_angles[2], w);
        offset.x = mix(a_offsets[1], a_offsets[2], w);
        pre_angle = mix(a_pre_angles[1], a_pre_angles[2], w);
        // theta = a_angles[1] / 4096.;
        // offset.x = a_offsets[1];
    }
    else if (zoom < a_stops[2]){
        w = (zoom - a_stops[1]) / (a_stops[2] - a_stops[1]);
        theta = mix(a_angles[2], a_angles[3], w);
        offset.x = mix(a_offsets[2], a_offsets[3], w);
        pre_angle = mix(a_pre_angles[2], a_pre_angles[3], w);
        // theta = a_angles[2] / 4096.;
        // offset.x = a_offsets[2];
    }
    else {
        theta = a_angles[3];
        offset.x = a_offsets[3];
        pre_angle = a_pre_angles[3];
    }

    #ifdef TANGRAM_MULTI_SAMPLER
    v_sampler = a_shape.w; // texture sampler
    #endif

    shape = rotate2D(shape, pre_angle);
    shape = rotate2D(shape + offset, theta);     // apply rotation to vertex

    // World coordinates for 3d procedural textures
    v_world_position = u_model * position;
    v_world_position.xy += shape * u_meters_per_pixel;
    v_world_position = wrapWorldPosition(v_world_position);

    // Modify position before camera projection
    #pragma tangram: position

    cameraProjection(position);

    #ifdef TANGRAM_LAYER_ORDER
        // +1 is to keep all layers including proxies > 0
        applyLayerOrder(a_position.w + u_tile_proxy_depth + 1., position);
    #endif

    // Apply pixel offset in screen-space
    // Multiply by 2 is because screen is 2 units wide Normalized Device Coords (and u_resolution device pixels wide)
    // Device pixel ratio adjustment is because shape is in logical pixels
    position.xy += shape * position.w * 2. * u_device_pixel_ratio / u_resolution;

    gl_Position = position;
}
