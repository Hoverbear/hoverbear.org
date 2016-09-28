---
layout: post
title: "Quadcopters: Stabilization"

tags:
  - Quadcopters
---

In our [past articles](/tag/quadcopters/) we've explored some of the basics of the mechanics of Quadcopters. In this article we'll be doing something a bit different and discussing the algorithms behind how the Quadcopter keeps itself stable.

To do this we'll actually be inspecting some of the official [Bitcraze Firmware](https://github.com/bitcraze/crazyflie-firmware) and it's [`stabilizer.c`](https://github.com/bitcraze/crazyflie-firmware/blob/crazyflie2/modules/src/stabilizer.c) implementation.

> It's okay if you don't know C or understand what's going on in this file, that's part of the purpose of this article!

The Crazyflie uses a *real time* operating system called [FreeRTOS](http://www.freertos.org/index.html) which is a well regarded industry standard.

# Structure

**C code and Arduino code are fairly similar**, and the best practice is to lay out your code roughly as follows:

	// Includes
    // Definitions
    // Variables
    // Functions

So what are all these? Let's break them down.

## Includes

In order to use code from other files it's necessary to bring them "in scope". Includes come in two forms:

	#include <math.h>     // Use a system provided library.
	#include "FreeRTOS.h" // Use from the project library.

Notice how we include `.h` files instead of `.c` files? These are called *header files* and contain functions, variables, and definitions. In most cases, each `.h` file has a respective `.c` file.

> The distinction between `.c` and `.h` files is largely a historical one. Some modern languages have combined the two.

## Definitions

Definitions are a way to assign certain values to specific names. `#define`s can be values or expressions.

    #define example 1
    #define max(a,b) ((a) > (b) ? (a) : (b))
    #define min(a,b) ((a) < (b) ? (a) : (b))

*Note:* Definitions cannot change while the program is running, this is not a place for variables.

Consider them like "macros", if we enter `max(1,2)` then our compiler will replace it with `((1) > (2) ? (1) : (2))`.

## Variables

We've used variables in our Arduino experiments already. Variables are the main workhorse of *data storage*.

	int foo;
    static int bar = 2;
    const int baz = 3;
    foo = 1;

Variables follow the format `type name = value`. You can also do just `type name` and `name` will be `null` (nothing) until it is set.

Sometimes you'll also see things like `static` and `const` in front. `static` variables exist over the lifetime of the program and are unique inside that given code file, they are not accessible outside of it. `const` variables cannot change their value after declared.

Not all variables will be simple values, for example, below we declare three `Axis3f`. When designing programs it's quite easy to create your own types to store whatever you might need.

    static Axis3f gyro; // Gyro axis data in deg/s
    static Axis3f acc;  // Accelerometer axis data in mG
    static Axis3f mag;  // Magnetometer axis data in testla

You'll see `float` occur commonly in the stabilization code, this is a decimal value like `0.00001`.

## Functions

Functions are step-by-step procedures which (generally) have an input and an output. The simplest function is this:

	void foo() {}

This is a function with no input or output! `void` is the *return type*, `void` in most cases means nothing is returned. A function which takes a pair of integers and returns their sum looks like this:

	int sum(int a, int b) {
    	return a+b;
    }

Functions can be invoked by calling them like so:

	int should_be_three = sum(1, 2);

# Understanding the Code

The stabilization code is broken up into a few sections. We'll take the code directly from the project and go over it slowly. If anything doesn't make sense please [email me](mailto:andrew+quads@hoverbear.org) and I'll make it more clear!


## Initialization

    void stabilizerInit(void)
    {
      if(isInit)
        return;

      motorsInit();
      imu6Init();
      sensfusion6Init();
      controllerInit();

      rollRateDesired = 0;
      pitchRateDesired = 0;
      yawRateDesired = 0;

      xTaskCreate(stabilizerTask, (const signed char * const)STABILIZER_TASK_NAME,
                  STABILIZER_TASK_STACKSIZE, NULL, STABILIZER_TASK_PRI, NULL);

      isInit = true;
    }

The `stabilizerInit()` function is what starts up the stabilization routines. You can see in the first line that if it is already been initialized the function simply returns early, doing nothing. (Note how `isInit` is set at the end of a normal call)

The code then initializes it's dependencies (which also exit early if already initialized!) After, it sets the desired orientation values to zero.

Finally, the function calls `xTaskCreate` which spawns a *task* which can run concurrently alongside other tasks. This particular task runs the `stabilizerTask()` function.

> In general, you can consider the entire quadcopter somewhat like your computer. It runs multiple tasks all the time. On your computer, this is things like your web browser and music player. On the quadcopter it's things like the stabilizer and radio.

## The Task

Okay, so what does this task look like then? Let's take a look! This function is longer, so I'll be breaking it up.

    static void stabilizerTask(void* param)
    {
      uint32_t attitudeCounter = 0;
      uint32_t altHoldCounter = 0;
      uint32_t lastWakeTime;

      vTaskSetApplicationTaskTag(0, (void*)TASK_STABILIZER_ID_NBR);

      //Wait for the system to be fully started to start stabilization loop
      systemWaitStart();

      lastWakeTime = xTaskGetTickCount();

      while(1)
      {
        vTaskDelayUntil(&lastWakeTime, F2T(IMU_UPDATE_FREQ)); // 500Hz

In the first few lines the function allocates some space for some 32-bit unsigned integers, these *only represent absolute numbers*. You can see that `lastWakeTime` is set later in the code. There are a few functions whose purpose is not immediately clear, let's go over them.

* [`vTaskSetApplicationTaskTag()`](http://www.freertos.org/vTaskSetApplicationTag.html) - Sets the 'tag' of the tag for debugging purposes. We need not concern ourselves with this.
* [`xTaskGetTickCount()`](http://www.freertos.org/a00021.html#xTaskGetTickCount) - This returns the number of ticks since the task was started (we saw this above).
* [`vTaskDelayUntil()`](http://www.freertos.org/vtaskdelayuntil.html) - This call asks the FreeRTOS to delay any execution of the task until the appropriate time, then start it again.

You'll notice as well that there is the start of a `while(1)` loop, which is an *infinite loop*, and will keep going until it is manually exited. Let's move forward.

    // Magnetometer not yet used more then for logging.
    imu9Read(&gyro, &acc, &mag);

    if (imu6IsCalibrated())
    {
      commanderGetRPY(&eulerRollDesired, &eulerPitchDesired, &eulerYawDesired);
      commanderGetRPYType(&rollType, &pitchType, &yawType);

      // 250HZ
      if (++attitudeCounter >= ATTITUDE_UPDATE_RATE_DIVIDER)
      {
        sensfusion6UpdateQ(gyro.x, gyro.y, gyro.z, acc.x, acc.y, acc.z, FUSION_UPDATE_DT);
        sensfusion6GetEulerRPY(&eulerRollActual, &eulerPitchActual, &eulerYawActual);

        accWZ = sensfusion6GetAccZWithoutGravity(acc.x, acc.y, acc.z);
        accMAG = (acc.x*acc.x) + (acc.y*acc.y) + (acc.z*acc.z);
        // Estimate speed from acc (drifts)
        vSpeed += deadband(accWZ, vAccDeadband) * FUSION_UPDATE_DT;

        controllerCorrectAttitudePID(eulerRollActual, eulerPitchActual, eulerYawActual,
                                     eulerRollDesired, eulerPitchDesired, -eulerYawDesired,
                                     &rollRateDesired, &pitchRateDesired, &yawRateDesired);
        attitudeCounter = 0;
      }

At the top of this chunk you'll see `imu9Read(&gyro, &acc, &mag);` which, if you've never used pointers, may seem odd. Essentially what we're doing is calling the `imu9Read` function and passing it the three *pointers* to the location of our variables. The function can then *dereference* these pointers and write into them. This is a common practice when you want to modify a complex value in a function without needing to copy the entire thing.

The `commanderGetRPY()` and `commanderGetRPYType()` fetch the desired inputs from the user, like an increase in pitch or roll.

After, if a counter is high enough (the `++` increments it) we do an 'attitude' update. This is not to be confused with altitude. The term attitude is something that seems to be internal to the Crazyflie, and appears to just be their term for a need for adjustment.

The `sensfusion6UpdateQ()` and `sensfusion6GetEulerRPY()` functions pull the current quadcopter orientation from the sensors onboard. You may note that this only updates the Gyro and Accelerometer, that's because the Crazyflie does not use the Magnometer in this code yet.

`AccWZ` is used along with the deadband (a way to reduce the amount of data collected and save battery life) to estimate the vertical speed of the device. It appears that `AccMAG` is unused.

Then `controllerCorrectAttitudePID()` is called. This takes the desired values and through a round-about method works with [`PidObject`](https://github.com/bitcraze/crazyflie-firmware/blob/a3ecf78d2e0e70e45c8a77f4d3d068b875ab8bf4/modules/interface/pid.h#L65-L81)s to update the pointers we pass in (The `&` values). `PidObject`s are used to model mathematics that drive the quadcopter.

      // 100HZ
      if (imuHasBarometer() && (++altHoldCounter >= ALTHOLD_UPDATE_RATE_DIVIDER))
      {
        stabilizerAltHoldUpdate();
        altHoldCounter = 0;
      }

      if (rollType == RATE)
      {
        rollRateDesired = eulerRollDesired;
      }
      if (pitchType == RATE)
      {
        pitchRateDesired = eulerPitchDesired;
      }
      if (yawType == RATE)
      {
        yawRateDesired = -eulerYawDesired;
      }

Next, if necessary, an altitude hold update is performed. Afterwards the three axes of movement are updated to their desired values.

      // TODO: Investigate possibility to subtract gyro drift.
      controllerCorrectRatePID(gyro.x, -gyro.y, gyro.z,
                               rollRateDesired, pitchRateDesired, yawRateDesired);

      controllerGetActuatorOutput(&actuatorRoll, &actuatorPitch, &actuatorYaw);

      if (!altHold || !imuHasBarometer())
      {
        // Use thrust from controller if not in altitude hold mode
        commanderGetThrust(&actuatorThrust);
      }
      else
      {
        // Added so thrust can be set to 0 while in altitude hold mode after disconnect
        commanderWatchdog();
      }

Here the task updates the desired rate, and updates its picture of how fast the quadcopter is actuating with its motors. Then it is updating the thrust based on input from the user or the altitude hold control.

          if (actuatorThrust > 0)
          {
    #if defined(TUNE_ROLL)
            distributePower(actuatorThrust, actuatorRoll, 0, 0);
    #elif defined(TUNE_PITCH)
            distributePower(actuatorThrust, 0, actuatorPitch, 0);
    #elif defined(TUNE_YAW)
            distributePower(actuatorThrust, 0, 0, -actuatorYaw);
    #else
            distributePower(actuatorThrust, actuatorRoll, actuatorPitch, -actuatorYaw);
    #endif
          }
          else
          {
            distributePower(0, 0, 0, 0);
            controllerResetAllPID();
          }
        }
      }

Finally, the task distributes power to the actuators. The `#if defined(TUNE_ROLL)` lines are compile time options meant for debugging, normally the `#else` case is used.

# What does it all mean?

In order to stabilize itself a quadcopter must *rapidly, constantly* sample its sensors, controller, and actuators in order to get the best picture of two very important things:

* What it is doing at that moment.
* What it should be doing at that moment.

In order to determine these values it uses mathematical models to get an idea of it's orientation and status. If you read our article on sensors you may recall how we transformed our accelerometer data into velocity data, this is the same idea. Then, the quadcopter attempts to find a *happy, stable* place that satisfies these requirements.
