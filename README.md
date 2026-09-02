# Battery-Charging-Optimiser
A MATLAB App Designer application that calculates the cost-optimal daily charging/discharging schedule for a home battery, using real electricity price data and real electricity demand data

## What it does
Given a household's battery specifications (capacity, charge/discharge rate, efficiency, degradation cost), the app determines the schedule that minimises daily electricity cost. It decides, for every 30 minute period of the day, how much to charge, discharge or draw from the electricity grid.

This is an operational optimisation tool: It assumes a battery is already installed. This project is asking 'How should the battery be run to save money' and not includes the upfront costs.

## How it works
The core problem 
