% This file is a read-only copy of the app's code, exported for viewing on GitHub. 
% To run the actual app, open BatteryChargingOptimiser.mlapp in MATLAB.'

classdef BatteryChargingOptimiser < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        PressRuntogetdetailsofapplicationLabel  matlab.ui.control.Label
        DegradationCostEditField        matlab.ui.control.NumericEditField
        BatteryDegradationCostLabel     matlab.ui.control.Label
        OptimisationSummaryTextArea     matlab.ui.control.TextArea
        OptimisationSummaryTextAreaLabel  matlab.ui.control.Label
        StatusLabel                     matlab.ui.control.Label
        ResetButton                     matlab.ui.control.Button
        BatteryPerformanceTextArea      matlab.ui.control.TextArea
        BatteryPerformanceTextAreaLabel  matlab.ui.control.Label
        DischargeEfficiencyEditField    matlab.ui.control.NumericEditField
        DischargeEfficiencyLabel        matlab.ui.control.Label
        ChargeEfficiciencyEditField     matlab.ui.control.NumericEditField
        ChargeEfficiencyDecimalLabel    matlab.ui.control.Label
        RunOptimisationButton           matlab.ui.control.Button
        MinimumEnergyEditField          matlab.ui.control.NumericEditField
        MinimumEnergykWhEditFieldLabel  matlab.ui.control.Label
        BatteryChargingOptimiserLabel   matlab.ui.control.Label
        TargetEnergyEditField           matlab.ui.control.NumericEditField
        TargetEnergykWhEditFieldLabel   matlab.ui.control.Label
        InitialEnergyEditField          matlab.ui.control.NumericEditField
        InitialEnergykWhEditFieldLabel  matlab.ui.control.Label
        MaxDischargeRateEditField       matlab.ui.control.NumericEditField
        MaxDischargeRatekWEditFieldLabel  matlab.ui.control.Label
        MaxChargeRateEditField          matlab.ui.control.NumericEditField
        MaxChargeRatekWEditFieldLabel   matlab.ui.control.Label
        CapacityEditField               matlab.ui.control.NumericEditField
        BatteryCapacitykWhEditFieldLabel  matlab.ui.control.Label
        CostAxes                        matlab.ui.control.UIAxes
        EnergyAxes                      matlab.ui.control.UIAxes
        OptimisationAxes                matlab.ui.control.UIAxes
    end

    
   properties (Access = private)
       PriceData
       DemandData
       Results
       InfoShown = false
   end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: RunOptimisationButton
        function RunOptimisationButtonPushed(app, event)
     if ~app.InfoShown

     uialert(app.UIFigure, ...
        ['This application determines an optimal battery charging and ' ...
        'discharging schedule using electricity price and demand data.' newline newline ...
        'MODEL ASSUMPTIONS' newline ...
        '• Electricity prices: SEMOpx day-ahead prices' newline ...
        '• Demand: EirGrid system demand data' newline ...
        '• Time interval: 30 minutes' newline ...
        '• Charge/discharge efficiency: user defined' newline ...
        '• Battery degradation cost: user defined' newline ...
        '• Demand data is scaled for the battery model' newline newline ...
        'Note: The price and demand datasets are representative inputs ' ...
        'and do not necessarily correspond to the exact same date.'], ...
        'About the Battery Optimiser', ...
        'Icon','info');

     app.InfoShown = true;

     end
     app.StatusLabel.Text = 'Loading data...';
     drawnow;
     %% 1. Read battery inputs 
     capacity = app.CapacityEditField.Value;
     maxChargeRate = app.MaxChargeRateEditField.Value;
     maxDischargeRate = app.MaxDischargeRateEditField.Value;
     chargeEfficiency = app.ChargeEfficiciencyEditField.Value /100;
     dischargeEfficiency = app.DischargeEfficiencyEditField.Value /100;
     initialEnergy = app.InitialEnergyEditField.Value;
     targetEnergy = app.TargetEnergyEditField.Value;
     minimumEnergy = app.MinimumEnergyEditField.Value;
     degradationCost = app.DegradationCostEditField.Value;
     dt = 0.5;

     if capacity <= 0
        uialert(app.UIFigure, ...
            'Battery capacity must be greater than 0.', ...
            'Invalid Input');
        return
    end

    if maxChargeRate <= 0
        uialert(app.UIFigure, ...
            'Maximum charge rate cannot be negative or 0.', ...
            'Invalid Input');
        return
    end

    if maxDischargeRate <= 0
        uialert(app.UIFigure, ...
            'Maximum discharge rate cannot be negative or 0.', ...
            'Invalid Input');
        return
    end

    if chargeEfficiency <= 0 || chargeEfficiency > 1
        uialert(app.UIFigure, ...
            'Charge efficiency must be between 0% and 100%.', ...
            'Invalid Input');
        return
    end

    if dischargeEfficiency <= 0 || dischargeEfficiency > 1
        uialert(app.UIFigure, ...
            'Discharge efficiency must be between 0% and 100%.', ...
            'Invalid Input');
        return
    end

    if minimumEnergy < 0 || minimumEnergy > capacity
        uialert(app.UIFigure, ...
            'Minimum energy must be between 0 and battery capacity.', ...
            'Invalid Input');
        return
    end

    if initialEnergy < minimumEnergy || initialEnergy > capacity
        uialert(app.UIFigure, ...
            'Initial energy must be between minimum energy and battery capacity.', ...
            'Invalid Input');
        return
    end

    if targetEnergy < minimumEnergy || targetEnergy > capacity
        uialert(app.UIFigure, ...
            'Target energy must be between minimum energy and battery capacity.', ...
            'Invalid Input');
        return
    end

    if maxChargeRate * dt > capacity
    uialert(app.UIFigure, ...
        'Maximum charge rate is very high compared with the battery capacity.', ...
        'Check Battery Settings');
    return
    end

    if maxDischargeRate * dt > capacity
    uialert(app.UIFigure, ...
        'Maximum discharge rate is very high compared with the battery capacity.', ...
        'Check Battery Settings');
    return
    end
    if degradationCost < 0
    uialert(app.UIFigure, ...
        'Battery degradation cost cannot be negative.', ...
        'Invalid Input');
    return
    end
    %% 2. Load SEMOpx electricity price data
    filename = 'SEMOpx_data.csv';
    lines = readlines(filename);

    % Find "Index prices" section
    priceHeader = find(startsWith(lines,'Index prices;30;EUR'),1);
    if isempty(priceHeader)
         uialert(app.UIFigure, ...
            'Could not find Index prices section in SEMOpx_data.csv.', ...
            'File Error');
        return
    end

    % Get timestamp and price lines
    timeLine = lines(priceHeader+1);
    priceLine = lines(priceHeader+2);

    % Split timestamp and price data
    timeStrings = split(timeLine,';');
    priceStrings = split(priceLine,';');

    % Convert comma decimal separator to dot
    priceStrings = replace(priceStrings,',','.');

    % Convert prices to numbers
    priceMWh = str2double(priceStrings);

    % Convert €/MWh to €/kWh
    price = priceMWh / 1000;

    % Convert timestamps
    time = datetime(timeStrings, ...
        'InputFormat','uuuu-MM-dd''T''HH:mm:ss''Z''', ...
        'TimeZone','UTC');

    % Number of time periods
    N = length(price);

    % Basic check
    if N ~= 48
        uialert(app.UIFigure, ...
            sprintf('Expected 48 price values but found %d.',N), ...
            'Price Data Error');
        return
    end

    %% 3. Load EirGrid demand data
    filenameDemand = 'System-Data-Qtr-Hourly-2026-V7.xlsx';
    eirgrid = readtable(filenameDemand);

    % Convert DateTime column
    eirgrid.DateTime = datetime(eirgrid.DateTime);

    % Select a date
    selectedDate = datetime(2026,7,31);
    dayStart = selectedDate;
    dayEnd = selectedDate + days(1);

    selectedRows = eirgrid.DateTime >= dayStart & ...
                   eirgrid.DateTime < dayEnd;
    selectedData = eirgrid(selectedRows,:);

    % Extract Irish demand
    demand = selectedData.IEDemand;

    % Scale demand to kW for the model
    demandScale = 0.00063;
    demand = demand * demandScale;

    % Convert 15-minute data to 30-minute
    demand = (demand(1:2:end) + demand(2:2:end)) / 2;

    % Make column vector
    demand = demand(:);

    % Basic check
    if length(demand) ~= 48
        uialert(app.UIFigure, ...
            sprintf('Expected 48 price values but found %d.',length(demand)), ...
            'Demand Data Error');
        return
    end

    %% 4. Run the optimisation using the separate function
   
    app.StatusLabel.Text = 'Optimising ...';
    drawnow;
    try
    results = runBatteryOptimiser( ...
        price, ...
        demand, ...
        capacity, ...
        maxChargeRate, ...
        maxDischargeRate, ...
        chargeEfficiency, ...
        dischargeEfficiency, ...
        initialEnergy, ...
        targetEnergy, ...
        minimumEnergy, ...
        degradationCost);
   catch

      app.StatusLabel.Text = 'Optimisation failed';

      uialert(app.UIFigure, ...
          ['These battery settings cannot meet the required energy target.' ...
          'Try adjusting the initial and target energy, or else increase the charge/discharge rates'],'Optimisation Failed')
   return
   end
   %% 5. Extract results
   app.StatusLabel.Text = 'Optimisation complete';
    
   baselineCost = results.baselineCost;   
   totalCost = results.totalCost;      
   savings = results.savings;
   if baselineCost > 0
        percentageSavings = results.percentageSavings;
   else
        percentageSavings = 0;
   end

   %% 6. Display optimisation results

   if savings >= 0
   app.OptimisationSummaryTextArea.Value = {
        sprintf('Baseline Cost: €%.2f', baselineCost)
        sprintf('Optimised Cost: €%.2f', totalCost)
        sprintf('Money Saved: €%.2f', savings)
        sprintf('Cost Reduction: %.2f%%', percentageSavings)
                ''
        'Optimisation Summary:'
        'Battery charged during lower-price periods'
        'and discharged during higher-price periods.'
        };
   else
   app.OptimisationSummaryTextArea.Value = {
        sprintf('Baseline Cost: €%.2f', baselineCost)
        sprintf('Optimised Cost: €%.2f', totalCost)
        sprintf('Additional Cost: €%.2f', abs(savings))
        sprintf('Cost Increase: %.2f%%', abs(percentageSavings))
        sprintf('Final Battery Energy: %.2f kWh', ...
            results.batteryEnergy(end))
                    ''
        'Optimisation Summary:'
        'The battery increased electricity costs'
        'under the selected operating conditions.'
        };
   end

   % Battery performance information
   app.BatteryPerformanceTextArea.Value = {
   sprintf('Energy Charged: %.2f kWh',results.totalEnergyCharged)
   sprintf('Energy Discharged: %.2f kWh',results.totalEnergyDischarged)
   sprintf('Battery Throughput: %.2f kWh',results.totalBatteryThroughput)
   sprintf('Equivalent Full Cycles: %.2f',results.equivalentFullCycles)
   sprintf('Energy Losses: %.2f kWh', results.totalEnergyLoss)
   sprintf('Final Battery Energy: %.2f kWh',results.batteryEnergy(end))
   sprintf('Degradation Cost: €%.2f/kWh',results.degradationCost)
   };
   % Store data in the app for plotting
   app.PriceData = price;
   app.DemandData = demand;
   app.Results = results;

   %% 7. Graphs

   % Figure 1: Price, Demand, Charging/Discharging
   cla(app.OptimisationAxes,'reset');  % clear previous content

   % Left y-axis: price
   yyaxis(app.OptimisationAxes, 'left')
   plot(app.OptimisationAxes, time, price, '-o')
   ylabel(app.OptimisationAxes, 'Electricity Price (€/kWh)')

   % Right y-axis: demand, grid consumption, charge/discharge
   yyaxis(app.OptimisationAxes, 'right')
   plot(app.OptimisationAxes, time, demand, '-o')
   hold(app.OptimisationAxes, 'on')
   plot(app.OptimisationAxes, time, results.gridEnergy, '-s')
   bar(app.OptimisationAxes, time, results.optimalCharge)
   bar(app.OptimisationAxes, time, -results.optimalDischarge)
   ylabel(app.OptimisationAxes, 'Power (kW)')

   xlabel(app.OptimisationAxes, 'Time')
   title(app.OptimisationAxes, 'Electricity Price, Demand and Battery Schedule')
   legend(app.OptimisationAxes, ...
        'Price','Demand','Grid Consumption','Charging','Discharging')
   xtickformat(app.OptimisationAxes, 'HH:mm')
   app.OptimisationAxes.FontSize = 10;
   grid(app.OptimisationAxes, 'on')

   % Figure 2: Cost comparison
   cla(app.CostAxes,'reset');
   costs = [results.baselineCost, results.totalCost];
   bar(app.CostAxes, costs);
   app.CostAxes.XTick = 1:2;
   app.CostAxes.XTickLabel = {'Without Battery','With Battery'};
   app.CostAxes.FontSize = 10;
   ylabel(app.CostAxes, 'Electricity Cost (€)');
   title(app.CostAxes, 'Daily Electricity Cost');
   grid(app.CostAxes, 'on');

   % Display the actual cost above each bar
   text(app.CostAxes, 1, costs(1), sprintf('€%.2f', costs(1)), ...
   'HorizontalAlignment','center', ...
   'VerticalAlignment','bottom');

   text(app.CostAxes, 2, costs(2), sprintf('€%.2f', costs(2)), ...
   'HorizontalAlignment','center', ...
   'VerticalAlignment','bottom');

   % Figure 3: Battery energy over time 

   cla(app.EnergyAxes,'reset');
   socTime = [time(1); time(:)];
   plot(app.EnergyAxes, socTime, results.batteryEnergy, '-o');
   hold(app.EnergyAxes, 'on');
   yline(app.EnergyAxes, capacity, '--', 'Max Capacity');
   yline(app.EnergyAxes, minimumEnergy, '--', 'Min Energy');
   hold(app.EnergyAxes, 'off');
   app.EnergyAxes.FontSize = 10;
   ylabel(app.EnergyAxes, 'Battery Energy (kWh)');
   title(app.EnergyAxes, 'Battery State of Charge');
   xtickformat(app.EnergyAxes, 'HH:mm');
   grid(app.EnergyAxes, 'on');
        end

        % Button pushed function: ResetButton
        function ResetButtonPushed(app, event)
% Reset battery inputs

app.CapacityEditField.Value = 10;
app.MaxChargeRateEditField.Value = 5;
app.MaxDischargeRateEditField.Value = 5;
app.InitialEnergyEditField.Value = 5;
app.TargetEnergyEditField.Value = 5;
app.MinimumEnergyEditField.Value = 1;
app.DegradationCostEditField.Value = 0.01;

% Reset Optimisation Display
app.StatusLabel.Text = 'Ready to optimise';

app.OptimisationSummaryTextArea.Value = {
    'Baseline Cost: €0.00'
    'Optimised Cost: €0.00'
    'Money Saved: €0.00'
    'Cost Reduction: 0.00%'
        ''
    'Optimisation Summary:'
    'Run the optimisation to see the result.'
};

% Reset battery performance display

app.BatteryPerformanceTextArea.Value = {
    'Energy Charged: 0.00 kWh'
    'Energy Discharged: 0.00 kWh'
    'Battery Throughput: 0.00 kWh'
    'Equivalent Full Cycles: 0.00'
    'Energy Losses: 0.00 kWh'
    'Final Battery Energy: 0.00kWh'
    'Degradation Cost: €0.00 kWh'
};

% Clear graphs

cla(app.OptimisationAxes,'reset');
cla(app.CostAxes,'reset');
cla(app.EnergyAxes,'reset');
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 632 595];
            app.UIFigure.Name = 'MATLAB App';

            % Create OptimisationAxes
            app.OptimisationAxes = uiaxes(app.UIFigure);
            title(app.OptimisationAxes, 'Title')
            xlabel(app.OptimisationAxes, 'X')
            ylabel(app.OptimisationAxes, 'Y')
            zlabel(app.OptimisationAxes, 'Z')
            app.OptimisationAxes.Position = [71 19 492 199];

            % Create EnergyAxes
            app.EnergyAxes = uiaxes(app.UIFigure);
            title(app.EnergyAxes, 'Title')
            xlabel(app.EnergyAxes, 'X')
            ylabel(app.EnergyAxes, 'Y')
            zlabel(app.EnergyAxes, 'Z')
            app.EnergyAxes.Position = [26 216 287 138];

            % Create CostAxes
            app.CostAxes = uiaxes(app.UIFigure);
            title(app.CostAxes, 'Title')
            xlabel(app.CostAxes, 'X')
            ylabel(app.CostAxes, 'Y')
            zlabel(app.CostAxes, 'Z')
            app.CostAxes.Position = [324 215 270 139];

            % Create BatteryCapacitykWhEditFieldLabel
            app.BatteryCapacitykWhEditFieldLabel = uilabel(app.UIFigure);
            app.BatteryCapacitykWhEditFieldLabel.HorizontalAlignment = 'right';
            app.BatteryCapacitykWhEditFieldLabel.Position = [80 522 128 22];
            app.BatteryCapacitykWhEditFieldLabel.Text = 'Battery Capacity (kWh)';

            % Create CapacityEditField
            app.CapacityEditField = uieditfield(app.UIFigure, 'numeric');
            app.CapacityEditField.Tooltip = {'Maximum amount of energy the battery can store (kWh)'};
            app.CapacityEditField.Position = [223 522 36 22];
            app.CapacityEditField.Value = 10;

            % Create MaxChargeRatekWEditFieldLabel
            app.MaxChargeRatekWEditFieldLabel = uilabel(app.UIFigure);
            app.MaxChargeRatekWEditFieldLabel.HorizontalAlignment = 'right';
            app.MaxChargeRatekWEditFieldLabel.Position = [80 501 128 22];
            app.MaxChargeRatekWEditFieldLabel.Text = 'Max Charge Rate (kW)';

            % Create MaxChargeRateEditField
            app.MaxChargeRateEditField = uieditfield(app.UIFigure, 'numeric');
            app.MaxChargeRateEditField.Tooltip = {'Maximum power at which the battery can charge (kW)'};
            app.MaxChargeRateEditField.Position = [223 501 36 22];
            app.MaxChargeRateEditField.Value = 5;

            % Create MaxDischargeRatekWEditFieldLabel
            app.MaxDischargeRatekWEditFieldLabel = uilabel(app.UIFigure);
            app.MaxDischargeRatekWEditFieldLabel.HorizontalAlignment = 'right';
            app.MaxDischargeRatekWEditFieldLabel.Position = [66 480 142 22];
            app.MaxDischargeRatekWEditFieldLabel.Text = 'Max Discharge Rate (kW)';

            % Create MaxDischargeRateEditField
            app.MaxDischargeRateEditField = uieditfield(app.UIFigure, 'numeric');
            app.MaxDischargeRateEditField.Tooltip = {'Maximum power at which the battery can discharge (kW)'};
            app.MaxDischargeRateEditField.Position = [223 480 36 22];
            app.MaxDischargeRateEditField.Value = 5;

            % Create InitialEnergykWhEditFieldLabel
            app.InitialEnergykWhEditFieldLabel = uilabel(app.UIFigure);
            app.InitialEnergykWhEditFieldLabel.HorizontalAlignment = 'right';
            app.InitialEnergykWhEditFieldLabel.Position = [98 459 110 22];
            app.InitialEnergykWhEditFieldLabel.Text = 'Initial Energy (kWh)';

            % Create InitialEnergyEditField
            app.InitialEnergyEditField = uieditfield(app.UIFigure, 'numeric');
            app.InitialEnergyEditField.Tooltip = {'Energy stored in the battery at the start of the optimisation (kWh)'};
            app.InitialEnergyEditField.Position = [223 459 36 22];
            app.InitialEnergyEditField.Value = 5;

            % Create TargetEnergykWhEditFieldLabel
            app.TargetEnergykWhEditFieldLabel = uilabel(app.UIFigure);
            app.TargetEnergykWhEditFieldLabel.HorizontalAlignment = 'right';
            app.TargetEnergykWhEditFieldLabel.Position = [93 438 115 22];
            app.TargetEnergykWhEditFieldLabel.Text = 'Target Energy (kWh)';

            % Create TargetEnergyEditField
            app.TargetEnergyEditField = uieditfield(app.UIFigure, 'numeric');
            app.TargetEnergyEditField.Tooltip = {'Required battery energy at the end of the optimisation (kWh)'};
            app.TargetEnergyEditField.Position = [223 438 36 22];
            app.TargetEnergyEditField.Value = 5;

            % Create BatteryChargingOptimiserLabel
            app.BatteryChargingOptimiserLabel = uilabel(app.UIFigure);
            app.BatteryChargingOptimiserLabel.FontSize = 20;
            app.BatteryChargingOptimiserLabel.FontWeight = 'bold';
            app.BatteryChargingOptimiserLabel.Position = [43 559 269 26];
            app.BatteryChargingOptimiserLabel.Text = 'Battery Charging Optimiser';

            % Create MinimumEnergykWhEditFieldLabel
            app.MinimumEnergykWhEditFieldLabel = uilabel(app.UIFigure);
            app.MinimumEnergykWhEditFieldLabel.HorizontalAlignment = 'right';
            app.MinimumEnergykWhEditFieldLabel.Position = [78 416 130 22];
            app.MinimumEnergykWhEditFieldLabel.Text = 'Minimum Energy (kWh)';

            % Create MinimumEnergyEditField
            app.MinimumEnergyEditField = uieditfield(app.UIFigure, 'numeric');
            app.MinimumEnergyEditField.Tooltip = {'Minimum Energy level the battery is allowed to reach (kWh)'};
            app.MinimumEnergyEditField.Position = [223 416 36 22];
            app.MinimumEnergyEditField.Value = 1;

            % Create RunOptimisationButton
            app.RunOptimisationButton = uibutton(app.UIFigure, 'push');
            app.RunOptimisationButton.ButtonPushedFcn = createCallbackFcn(app, @RunOptimisationButtonPushed, true);
            app.RunOptimisationButton.FontSize = 18;
            app.RunOptimisationButton.FontWeight = 'bold';
            app.RunOptimisationButton.Position = [344 543 190 31];
            app.RunOptimisationButton.Text = 'Run Optimisation';

            % Create ChargeEfficiencyDecimalLabel
            app.ChargeEfficiencyDecimalLabel = uilabel(app.UIFigure);
            app.ChargeEfficiencyDecimalLabel.HorizontalAlignment = 'right';
            app.ChargeEfficiencyDecimalLabel.Position = [83 396 125 22];
            app.ChargeEfficiencyDecimalLabel.Text = 'Charge Efficiency (%))';

            % Create ChargeEfficiciencyEditField
            app.ChargeEfficiciencyEditField = uieditfield(app.UIFigure, 'numeric');
            app.ChargeEfficiciencyEditField.Tooltip = {'Percentage of electricity supplied to the battery that is actually stored'};
            app.ChargeEfficiciencyEditField.Position = [223 396 36 22];
            app.ChargeEfficiciencyEditField.Value = 95;

            % Create DischargeEfficiencyLabel
            app.DischargeEfficiencyLabel = uilabel(app.UIFigure);
            app.DischargeEfficiencyLabel.HorizontalAlignment = 'right';
            app.DischargeEfficiencyLabel.Position = [76 376 132 22];
            app.DischargeEfficiencyLabel.Text = 'Discharge Efficiency(%)';

            % Create DischargeEfficiencyEditField
            app.DischargeEfficiencyEditField = uieditfield(app.UIFigure, 'numeric');
            app.DischargeEfficiencyEditField.Tooltip = {'Percentage of stored battery that is delivered to the load'};
            app.DischargeEfficiencyEditField.Position = [223 376 36 22];
            app.DischargeEfficiencyEditField.Value = 95;

            % Create BatteryPerformanceTextAreaLabel
            app.BatteryPerformanceTextAreaLabel = uilabel(app.UIFigure);
            app.BatteryPerformanceTextAreaLabel.HorizontalAlignment = 'right';
            app.BatteryPerformanceTextAreaLabel.FontWeight = 'bold';
            app.BatteryPerformanceTextAreaLabel.Position = [284 483 123 22];
            app.BatteryPerformanceTextAreaLabel.Text = 'Battery Performance';

            % Create BatteryPerformanceTextArea
            app.BatteryPerformanceTextArea = uitextarea(app.UIFigure);
            app.BatteryPerformanceTextArea.Editable = 'off';
            app.BatteryPerformanceTextArea.FontColor = [0 0.4471 0.7412];
            app.BatteryPerformanceTextArea.Position = [423 466 178 41];

            % Create ResetButton
            app.ResetButton = uibutton(app.UIFigure, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonPushed, true);
            app.ResetButton.FontWeight = 'bold';
            app.ResetButton.Position = [570 561 54 22];
            app.ResetButton.Text = 'Reset';

            % Create StatusLabel
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.FontWeight = 'bold';
            app.StatusLabel.Position = [387 522 144 22];
            app.StatusLabel.Text = 'Ready to Optimise';

            % Create OptimisationSummaryTextAreaLabel
            app.OptimisationSummaryTextAreaLabel = uilabel(app.UIFigure);
            app.OptimisationSummaryTextAreaLabel.HorizontalAlignment = 'right';
            app.OptimisationSummaryTextAreaLabel.FontWeight = 'bold';
            app.OptimisationSummaryTextAreaLabel.Position = [276 438 136 22];
            app.OptimisationSummaryTextAreaLabel.Text = 'Optimisation Summary';

            % Create OptimisationSummaryTextArea
            app.OptimisationSummaryTextArea = uitextarea(app.UIFigure);
            app.OptimisationSummaryTextArea.Position = [422 360 179 100];

            % Create BatteryDegradationCostLabel
            app.BatteryDegradationCostLabel = uilabel(app.UIFigure);
            app.BatteryDegradationCostLabel.HorizontalAlignment = 'right';
            app.BatteryDegradationCostLabel.Position = [23 356 185 22];
            app.BatteryDegradationCostLabel.Text = 'Battery Degradation Cost (€/kWh)';

            % Create DegradationCostEditField
            app.DegradationCostEditField = uieditfield(app.UIFigure, 'numeric');
            app.DegradationCostEditField.Tooltip = {'The estimated cost of battery wear for each kWh charged or discharged.  A higher value reduces battery cycling but may reduce electricity cost savings'};
            app.DegradationCostEditField.Position = [223 356 36 22];
            app.DegradationCostEditField.Value = 0.01;

            % Create PressRuntogetdetailsofapplicationLabel
            app.PressRuntogetdetailsofapplicationLabel = uilabel(app.UIFigure);
            app.PressRuntogetdetailsofapplicationLabel.FontSize = 8;
            app.PressRuntogetdetailsofapplicationLabel.Position = [369 573 139 22];
            app.PressRuntogetdetailsofapplicationLabel.Text = 'Press Run to get details of application';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = BatteryChargingOptimiser

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end