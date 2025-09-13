function save_new_figures(figs_before, out_dir, prefix)
% Save figures created since the checkpoint in figs_before.

figs_after = findall(0,'Type','figure');
new_figs = setdiff(figs_after, figs_before);

if isempty(new_figs), return; end

[~, idx] = sort(arrayfun(@(h) h.Number, new_figs));
new_figs = new_figs(idx);

for i = 1:numel(new_figs)
    name = get(new_figs(i), 'Name');
    if isempty(name)
        name = sprintf('%s_%02d', prefix, i);
    else
        name = sprintf('%s_%s_%02d', prefix, sanitize_filename(name), i);
    end
    base = fullfile(out_dir, name);
    save_plot(new_figs(i), base);
end
end
