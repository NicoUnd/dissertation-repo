shader_type spatial;
render_mode depth_prepass_alpha;

#include "res://shaders/shader_include.gdshaderinc"

// terrain generation method specific parameters
uniform sampler2D heightmap1;
uniform sampler2D heightmap2;
uniform sampler2D heightmap3;
uniform sampler2D heightmap4;

uniform float c1: hint_range(0.0, 1.0, 0.1);
uniform float c2: hint_range(0.0, 1.0, 0.1);
uniform float c3: hint_range(0.0, 1.0, 0.1);
uniform float c4: hint_range(0.0, 1.0, 0.1);


void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
