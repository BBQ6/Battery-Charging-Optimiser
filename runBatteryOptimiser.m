function results = runBatteryOptimiser( ...
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
    degradationCost)

N= length(price);
dt=0.5;

% Objective function:
% Minimise grid electricity cost + battery degradation cost
f = [degradationCost*dt*ones(1,N), ...
     degradationCost*dt*ones(1,N), ...
     price(:)'*dt]';

% Battery energy constraint
A_battery = zeros(N,3*N);
for t = 1:N
    %Effect of charging
    A_battery(t,1:t) = chargeEfficiency*dt;
    %Effect of discharging
    A_battery(t,N+1:N+t) = -dt/dischargeEfficiency;
end

Aineq = [A_battery;-A_battery];
b_upper= (capacity - initialEnergy)*ones(N,1);
b_lower= (initialEnergy - minimumEnergy)*ones(N,1);
bineq=[b_upper;b_lower];

Aeq = zeros(N,3*N);
for t=1:N
    Aeq(t,t)=-1;
    Aeq(t,N+t)=1;
    Aeq(t,2*N+t)=1;
end

Aeq_target = zeros(1,3*N);
Aeq_target(1:N) = chargeEfficiency*dt;
Aeq_target(N+1:2*N)= -dt/dischargeEfficiency;

Aeq = [Aeq;Aeq_target];

beq = [demand;targetEnergy - initialEnergy];

%Stop it from being negative
lb = zeros(3*N,1);
%Max charging and discharging rate
ub = [maxChargeRate * ones(N,1);
      maxDischargeRate * ones(N,1);
      inf(N,1)];

%% 3.5. Run optimisation
fprintf('\nRunning battery optimisation...\n');
[x,fval,exitflag]= linprog(f,Aineq,bineq,Aeq,beq,lb,ub);

if exitflag ~= 1
   error('Optimisation did not converge - check constraints (exitflag =%d)',exitflag);
end

optimalCharge= x(1:N);
optimalDischarge= x(N+1:2*N);
gridEnergy = x(2*N+1:3*N);

batteryEnergy = zeros(1,N+1);
batteryEnergy(1) = initialEnergy;
for t=1:N
    batteryEnergy(t+1)=batteryEnergy(t) ...
    + optimalCharge(t)*chargeEfficiency*dt ...
    - optimalDischarge(t)*dt/dischargeEfficiency;
end
%% Cost calculations

totalCost = sum(price(:) .* gridEnergy(:) * dt);

baselineCost = sum(price(:) .* demand(:) * dt);

savings = baselineCost - totalCost;

percentageSavings = (savings / baselineCost) * 100;

%% Battery performance

totalEnergyCharged = sum(optimalCharge) * dt;

totalEnergyDischarged = sum(optimalDischarge) * dt;

totalBatteryThroughput = ...
    totalEnergyCharged + totalEnergyDischarged;

equivalentFullCycles = ...
    totalBatteryThroughput / (2 * capacity);

chargingLoss = ...
    totalEnergyCharged * (1 - chargeEfficiency);

dischargingLoss = ...
    totalEnergyDischarged * ...
    (1 / dischargeEfficiency - 1);

totalEnergyLoss = chargingLoss + dischargingLoss;

%% Return results

results.totalCost = totalCost;

results.baselineCost = baselineCost;

results.savings = savings;

results.percentageSavings = percentageSavings;

results.optimalCharge = optimalCharge;

results.optimalDischarge = optimalDischarge;

results.gridEnergy = gridEnergy;

results.batteryEnergy = batteryEnergy;

results.totalEnergyCharged = totalEnergyCharged;

results.totalEnergyDischarged = totalEnergyDischarged;

results.totalBatteryThroughput = totalBatteryThroughput;

results.equivalentFullCycles = equivalentFullCycles;

results.chargingLoss = chargingLoss;

results.dischargingLoss = dischargingLoss;

results.totalEnergyLoss = totalEnergyLoss;

results.finalEnergyError = ...
    abs(batteryEnergy(end) - targetEnergy);

results.minimumBatteryEnergy = min(batteryEnergy);

results.maximumBatteryEnergy = max(batteryEnergy);

results.maximumChargeRateUsed = max(optimalCharge);

results.maximumDischargeRateUsed = max(optimalDischarge);

results.degradationCost = degradationCost;

%Finish Function
end
