/*
	Copyright (c) 2011, T. Kroes <t.kroes@tudelft.nl>
	All rights reserved.

	Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

	- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	- Neither the name of the TU Delft nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#pragma once

#include "Geometry.cuh"

#include <thrust/reduce.h>

KERNEL void KrnlComputeGradientMagnitudeVolume(float* pGradientMagnitude, int Width, int Height, int Depth)
{
	const int X = blockIdx.x * blockDim.x + threadIdx.x;
	const int Y	= blockIdx.y * blockDim.y + threadIdx.y;
	const int Z	= blockIdx.z * blockDim.z + threadIdx.z;
	
	if (X >= Width || Y >= Height || Z >= Depth)
		return;
	
	const Vec3f P = ToVec3f(gVolume.MinAABB) + ToVec3f(gVolume.Size) * (Vec3f((float)X + 0.5f, (float)Y + 0.5f, (float)Z + 0.5f) * ToVec3f(gVolume.InvExtent));

	int ID = X + Y * Width + Z * (Width * Height);

	pGradientMagnitude[ID] = GradientMagnitude(P);
}

void ComputeGradientMagnitudeVolume(int Extent[3], float& MaximumGradientMagnitude)
{
	const dim3 BlockDim(8, 8, 8);
	const dim3 GridDim((int)ceilf((float)Extent[0] / (float)BlockDim.x), (int)ceilf((float)Extent[1] / (float)BlockDim.y), (int)ceilf((float)Extent[2] / (float)BlockDim.z));

	float* pGradientMagnitude = NULL;

	HandleCudaError(cudaMalloc(&pGradientMagnitude, Extent[0] * Extent[1] * Extent[2] * sizeof(float)));

	KrnlComputeGradientMagnitudeVolume<<<GridDim, BlockDim>>>(pGradientMagnitude, Extent[0], Extent[1], Extent[2]);
	cudaThreadSynchronize();
	
	thrust::device_ptr<float> DevicePtr(pGradientMagnitude); 

	float Result = 0.0f;
	Result = thrust::reduce(DevicePtr, DevicePtr + Extent[0] * Extent[1] * Extent[2], Result, thrust::maximum<float>());
	
	cudaFree(pGradientMagnitude);

	MaximumGradientMagnitude = Result;
}