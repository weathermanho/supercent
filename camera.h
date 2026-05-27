////////////////////////////////////////
// camera.h
////////////////////////////////////////

#ifndef CSE169_CAMERA_H
#define CSE169_CAMERA_H

#include "core.h"

////////////////////////////////////////////////////////////////////////////////

class Camera {
public:
	Camera();
	
	float HEIGHT;
	float WIDTH;
	float FOV;
	
	float x;
	float y;
	float z;

	void Update();
	void Reset();
	void Draw();

	// Access functions
	void SetFOV(float f)		{ FOV = f; }
	void SetAspect(float a)		{Aspect=a;}
	void SetDistance(float d)	{Distance=d;}
	void SetAzimuth(float a)	{Azimuth=a;}
	void SetIncline(float i)	{Incline=i;}

	float GetDistance()			{return Distance;}
	float GetAzimuth()			{return Azimuth;}
	float GetIncline()			{return Incline;}

private:
	// Perspective controls
	
	float Aspect;
	float NearClip;
	float FarClip;

	// Polar controls
	float Distance;
	float Azimuth;
	float Incline;
};

////////////////////////////////////////////////////////////////////////////////

/*
The Camera class provides a simple means to controlling the 3D camera. It could
be extended to support more interactive controls. Ultimately. the camera sets the
GL projection and viewing matrices.
*/

#endif
