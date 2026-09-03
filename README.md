# Battery-Charging-Optimiser
A MATLAB App Designer application that calculates the cost-optimal daily charging/discharging schedule for a home battery, using real electricity price data and real electricity demand data. It is a representative residential scale system.

## What it does
Given a household's battery specifications (capacity, charge/discharge rate, efficiency, degradation cost), the app determines the schedule that minimises daily electricity cost. It decides, for every 30 minute period of the day, how much to charge, discharge or draw from the electricity grid.

This is an operational optimisation tool: It assumes a battery is already installed. This project is asking 'How should the battery be run to save money' and not includes the upfront costs.

## How it works
The core problem is formulated and solved as a linear program using Matlab's linprog: 
1. Decision variables: Charging power, discharging power and electricity drawn from grid for each 30-minute period
2.  Minimise the total electricity cost (grid draw × price) plus a battery degradation cost, so the model doesn't cycle the battery unnecessarily just to chase small price differences
3.  Constraints:
     a: Battery energy stays within capacity and minimum energy limits at every         time.
     b: Charge/discharge power stays within the battery's rated limits
     c: Grid draw + battery discharge - battery charge = household demand
     d: Battery reaches a target energy level by the end of the day
4. Self Validation checks are done to ensure all values inputted respect the constraint

## Data Sources
Data were scaled down to a small system to show the functionality
1. Electricity prices: SEMOpx day ahead prices. Then converted from €/MWh to €/kWh
2. Eirgrid system demand data

## Assumption
Price and demand datasets were from different days during the summer as time matching data were not available. Same season so it gives a good representative

## Features
a. Interactive Matlab App Designer interface where specifications can be adjusted and run again
b. Input validation with clear error messages if they didn't obey the constraints
c. Three linked visualisations: Price/demand/schedule overlay, cost comparison and battery state of change over the day
d. Battery performance summaries

# Important
## Running the app
1. Requires MATLAB with the Optimization Toolbox
2. Place SEMOpx data csv, Demand spreasheet and function code into the same folder as the app
3. Open BatteryChargingOptimiser.mlpp in Matlab and run it first to get instructions
4. Adjust parameters accordingly and click Run again
5. If demand file fails to download, here is the website to download it: ( https://www.eirgrid.ie/grid/system-and-renewable-data-reports ) and find the System Data Qtr Hourly spreadsheet

## Limitations and Future Improvements:
1. A live version of price and demand data would be a better representation as     it shows the fluctuation and there would be no time difference
2. Demand profile is a scaled national average, not a real individual household
3. Doesn't model the battery purchase costs


