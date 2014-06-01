/*
	OpenCL C kernel for gravitational interactions of particles computation
	-----------------------------------------------------------------------
	r -- global array of positions
	v -- global array of speeds
	a -- global array of accelarations
	m -- global (constant) array of masses
*/

// definitions of "real" and "v3r" types
#define real float
#define v3r float4	// OpenCL 4-vector type

// square length function
// (there are actually built in "length()" and "fast_length()" functions in OpenCL C,
// but I wanted to minimize multiplication operations)
real sqrlen(v3r r)
{
	v3r r2 = r*r;
	return r2.x + r2.y + r2.z;
}

#define ln 64	// work group size
#define R2 1.5	// closest square radius of interaction

// kernel which computes forces (straight forward approach with global memory)
// =============>>> make it faster by utilizing local memory <<<=============
__kernel __attribute__((reqd_work_group_size(ln, 1, 1)))
void compute_forces_global(	__global const v3r * r,
							__constant const real * m,
							__global v3r * a)
{
	// each work-item (thread) corresponds to a particle
	const uint id = get_global_id(0), n = get_global_size(0);
	v3r dr, r0 = r[id], f = (v3r)(0);
	uint i;
	real d2;
	for (i=0; i<n; i++)	// iterating over all other particles
	{
		// we'd better minimize expensive operations in the inner loop
		dr = r[i] - r0;
		d2 = sqrlen(dr);
		if (d2>R2)	// if not too close to each other
			f += dr * m[i]/(d2*sqrt(d2));	// accumulating gravitational acceleration
	}
	a[id] = f;	// saving computed acceleration to a global array
}

#define dt 0.01		// delta-time between update iterations
#define dt2 0.005	// == dt/2

// kernel which updates positions of particles
__kernel void update_positions(__global v3r * r, __global v3r * v, __global const v3r * a)
{
	uint id = get_global_id(0);
	r[id] += dt * (v[id] + dt2 * a[id]);	// updating positions (2nd order formula)
	v[id] += dt * a[id];	// updating speeds
}
