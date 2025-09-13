function find_and_load_model(mdl)
% Load a Simulink model by name from path or recursively under current root.
% mdl: char or string model name without extension.

mdl = char(mdl);
if bdIsLoaded(mdl), return; end

f = which([mdl '.slx']);
if isempty(f), f = which([mdl '.mdl']); end

if isempty(f)
    root = pwd;
    d = dir(fullfile(root,'**',[mdl '.slx']));
    if isempty(d), d = dir(fullfile(root,'**',[mdl '.mdl'])); end
    if ~isempty(d)
        f = fullfile(d(1).folder, d(1).name);
    end
end

if isempty(f)
    error('find_and_load_model:NotFound','Model %s not found.', mdl);
end

load_system(f);
end
