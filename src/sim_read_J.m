function J_final = sim_read_J(simOut)
% Extract scalar J from a SimulationOutput or base workspace.

J_final = NaN;

% First, try SimulationOutput container
if isa(simOut,'Simulink.SimulationOutput')
    % SimulationOutput may store a variable named 'J'
    try
        if any(strcmp(who(simOut),'J'))
            Jv = simOut.get('J');
        else
            Jv = [];
        end
    catch
        Jv = [];
    end
else
    Jv = [];
end

% Fallback to base workspace if needed
if isempty(Jv)
    try
        if evalin('base','exist(''J'',''var'')')
            Jv = evalin('base','J');
        end
    catch
        Jv = [];
    end
end

% Interpret various J representations
if isnumeric(Jv) && ~isempty(Jv)
    J_final = Jv(end);
elseif isa(Jv,'timeseries') && ~isempty(Jv.Data)
    J_final = Jv.Data(end);
elseif isstruct(Jv) && isfield(Jv,'signals') && isfield(Jv.signals,'values') ...
       && ~isempty(Jv.signals.values)
    J_final = Jv.signals.values(end);
elseif isa(Jv,'Simulink.SimulationData.Dataset')
    try
        el = Jv.get(1);
        J_final = el.Data(end);
    catch
        J_final = NaN;
    end
else
    J_final = NaN;
end
end
