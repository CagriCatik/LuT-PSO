function save_plot(figHandle, basePath)
% Save a figure as PNG and FIG. basePath without extension.

pngPath = [basePath '.png'];
figPath = [basePath '.fig'];

try
    exportgraphics(figHandle, pngPath, 'Resolution', 200);
catch
    try
        set(figHandle,'PaperPositionMode','auto');
        print(figHandle, pngPath, '-dpng','-r200');
    catch
    end
end

try
    savefig(figHandle, figPath);
catch
end
end
