function BP = prepare_model_and_workspace(mdl)
% Ensure required base vars and recommended model params.
% Returns BP for convenience.

mdl = char(mdl);

% Required vars
if ~evalin('base','exist(''STOP_T'',''var'')'), assignin('base','STOP_T',10); end
if ~evalin('base','exist(''BP'',''var'')'),     assignin('base','BP',linspace(-1,1,11)); end
BP = evalin('base','BP');
if ~evalin('base','exist(''TBL'',''var'')'),    assignin('base','TBL',zeros(size(BP))); end

% Preferred model settings
try set_param(mdl,'FastRestart','on'); catch, end
try set_param(mdl,'ReturnWorkspaceOutputs','on'); catch, end
try set_param([mdl '/J_to_ws'],'VariableName','J','SaveFormat','Array'); catch, end
end
