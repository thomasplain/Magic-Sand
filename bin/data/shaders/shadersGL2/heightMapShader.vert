/***********************************************************************
heightMapShader - Shader vertex to compute elevation and vertex location.
Copyright (c) 2016 Thomas Wolf

-- adapted from SurfaceRenderer by Oliver Kreylos
Copyright (c) 2012-2015 Oliver Kreylos

This file is part of the Magic Sand.

The Magic Sand is free software; you can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 2 of the
License, or (at your option) any later version.

The Magic Sand is distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License along
with the Magic Sand; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
***********************************************************************/

#version 120

varying float depthfrag;

uniform sampler2DRect tex0; // Sampler for the depth image-space elevation texture automatically set by binding

uniform mat4 kinectProjMatrix; // Transformation from kinect world space to proj image space
uniform mat4 kinectWorldMatrix; // Transformation from kinect image space to kinect world space
uniform mat4 kinectIntrinsicMatrix;
uniform mat4 kinectExtrinsicMatrix;
uniform vec4 distortionCoefficients;
uniform vec2 heightColorMapTransformation; // Transformation from elevation to height color map texture coordinate factor and offset
uniform vec2 depthTransformation; // Normalisation factor and offset applied by openframeworks
uniform vec4 basePlaneEq; // Base plane equation

uniform float maxHeight;
uniform vec2 meshDim;
uniform vec2 meshOffset;


void main()
{
    vec4 position =gl_Vertex;
    gl_TexCoord[0] = (gl_MultiTexCoord0 - vec4(meshOffset.x, meshOffset.y, 0, 0)) / vec4(meshDim, 1.0, 1.0);
    vec2 texcoord = gl_MultiTexCoord0.xy;
    // copy position so we can work with it.
    vec4 pos = position;

    /* Set the vertex' depth image-space z coordinate from the texture: */
    vec4 texel0 = texture2DRect(tex0, texcoord);
    float depth1 = texel0.r;
    float depth = depth1 * depthTransformation.x + depthTransformation.y;

    pos.z = depth;
    pos.w = 1;
    
    /* Transform the vertex from depth image space to world space: */
    vec4 vertexCc = kinectWorldMatrix * pos;  // Transposed multiplication (Row-major order VS col major order
    vec4 vertexCcx = vertexCc * depth;
    vertexCcx.w = 1;
    
    /* Transform elevation to height color map texture coordinate: */
    float elevation = dot(basePlaneEq,vertexCcx);///vertexCc.w;
    depthfrag = elevation*heightColorMapTransformation.x+heightColorMapTransformation.y;
    
    /* Transform vertex to proj coordinates: */
    //vec4 screenPos = kinectIntrinsicMatrix * kinectExtrinsicMatrix * vertexCcx;
    //vec4 projectedPoint = screenPos / screenPos.z;
    //vec4 screenPos = kinectProjMatrix * vertexCcx;
    //vec4 projectedPoint = screenPos / screenPos.z;
    
    vec4 projCoord = kinectExtrinsicMatrix * vertexCcx;
    vec4 imageCoord = projCoord / projCoord.z;
    
    float radius2 = imageCoord.x * imageCoord.x + imageCoord.y * imageCoord.y;
    float radius4 = radius2 * radius2;

    float d = 1 + distortionCoefficients.x * radius2 + distortionCoefficients.y * radius4;

    imageCoord.x *= d;
    imageCoord.y *= d;

    imageCoord = kinectIntrinsicMatrix * imageCoord;

    imageCoord.x = imageCoord.x + distortionCoefficients.z*2*imageCoord.x*imageCoord.y + distortionCoefficients.w*(radius2 + imageCoord.x*imageCoord.x);
    imageCoord.y = imageCoord.y + distortionCoefficients.w*2*imageCoord.x*imageCoord.y + distortionCoefficients.z*(radius2 + imageCoord.y*imageCoord.y);
    
    vec4 projectedPoint = imageCoord; //screenPos / screenPos.z;
    //vec4 projectedPoint = screenPos / screenPos.z;

    projectedPoint.z = 0;
    projectedPoint.w = 1;

	gl_Position = gl_ModelViewProjectionMatrix * projectedPoint;

    gl_TexCoord[0].z = (elevation * heightColorMapTransformation.x + heightColorMapTransformation.y) / (maxHeight);
}
