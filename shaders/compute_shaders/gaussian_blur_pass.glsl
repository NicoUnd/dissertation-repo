#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) buffer ParameterBuffer{
	float horizontal;
	float blur_size;
	float blur_strength;
	float resolution;
}
parameter_buffer;

layout(set = 0, binding = 1, r32f) uniform image2D image1;

layout(set = 0, binding = 2, r32f) uniform image2D image2;

float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma)) / (sqrt(2.0 * 3.14159265) * sigma);
}

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	
	int blur_size = int(parameter_buffer.blur_size);
	int resolution = int(parameter_buffer.resolution);	
	bool horizontal = bool(parameter_buffer.horizontal); // if horizontal then image1 is input and image2 is output, otherwise vice versa

	float blurred_value = 0.0;
	float total_weight = 0.0;
	for (int i = -blur_size; i <= blur_size; i++) {
		ivec2 sample_uv = uv;
		if (horizontal) {
			sample_uv.x += i;
		} else {
			sample_uv.y += i;
		}
		sample_uv = clamp(sample_uv, ivec2(0), ivec2(resolution - 1));
		
		float weight = gaussian(float(i), parameter_buffer.blur_strength);
		total_weight += weight;
		if (horizontal) {
			blurred_value += imageLoad(image1, sample_uv).r * weight;
		} else {
			blurred_value += imageLoad(image2, sample_uv).r * weight;
		}
	}
	if (horizontal) {
		imageStore(image2, uv, vec4(blurred_value / total_weight, 0.0, 0.0, 0.0));
	} else {
		imageStore(image1, uv, vec4(blurred_value / total_weight, 0.0, 0.0, 0.0));
	}
}
