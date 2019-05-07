---
layout: post
title: "Quadcopters: The Board"

tags:
  - Quadcopters
---

This post is less about the mechanics of the quadcopter and more to satisfy those curious about what exactly is on the board.

Here are links to the schematics and component placements:

* [Component Placement - Top](https://wiki.bitcraze.io/_media/projects:crazyflie2:hardware:crazyflie_2.0_rev.c_component_placement_top.pdf)
* [Component Placement - bottom](https://wiki.bitcraze.io/_media/projects:crazyflie2:hardware:crazyflie_2.0_rev.c_component_placement_bottom.pdf)
* [Schematics](https://wiki.bitcraze.io/_media/projects:crazyflie2:hardware:crazyflie_2.0_rev.c_schematics.pdf)

On the pictures below we'll use the **schematic symbols** as they are shortest.

## Top Side

![Labelled Top](/assets/images/2015/05/image4144.jpg)

<table>
  <thead>
    <tr>
      <th>On-Board</th>
      <th>Schematic</th>
      <th>Part</th>
      <th>Purpose</th>
    </tr>
  </thead>
  <tbody>
	<tr>
      <td>MP92 X752D1</td>
      <td>U9</td>
      <td>MPU-9250</td>
      <td>3 Axis Accelerometer, Gyroscope, & Magnometer</td>
    </tr>
  	<tr>
   	  <td>A7RRYG</td>
      <td>U3</td>
      <td>NCP702SN30</td>
      <td>Voltage Regulator & Power Supply</td>
    </tr>
  	<tr>
      <td>CDU TI08W</td>
      <td>U4</td>
      <td>BQ24075</td>
      <td>Battery Charger</td>
    </tr>
    <tr>
      <td>NS1822 QFAAG3 1440BE</td>
      <td>U6</td>
      <td>NRF51822</td>
      <td>System-on-a-Chip (Transceiver/Bluetooth)</td>
    </tr>
    <tr>
    	<td>6360 T 4Y03</td>
        <td>X3</td>
        <td>N/A</td>
        <td>16Mhz Quartz Crystal</td>
    </tr>
    <tr>
      <td>RF AXIS X2401C UB1248</td>
      <td>U8</td>
      <td>RFX2401C</td>
      <td>2.4Ghz Zigbee Transceiver</td>
    </tr>
  </tbody>
</table>

## Bottom Side

![Labelled Bottom](/assets/images/2015/05/labelled_bottom.png)

<table>
  <thead>
    <tr>
      <th>On-Board</th>
      <th>Schematic</th>
      <th>Part</th>
      <th>Purpose</th>
    </tr>
  </thead>
  <tbody>
	<tr>
      <td>STM32F405</td>
      <td>U2</td>
      <td>STM32F405RG</td>
      <td>System-on-a-Chip</td>
    </tr>
	<tr>
      <td>N/A</td>
      <td>U1</td>
      <td>24AA64FT-E/OT</td>
      <td>64K EEPROM</td>
    </tr>
    <tr>
      <td>N/A</td>
      <td>U10</td>
      <td>LPS25H</td>
      <td>Pressure Sensor</td>
    </tr>
    <tr>
      <td>LRAG</td>
      <td>U5</td>
      <td>LP2985</td>
      <td>Regulator</td>
    </tr>
  </tbody>
</table>
