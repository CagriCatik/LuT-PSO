function s = sanitize_filename(nameStr)
% Replace non-filename characters with underscores and collapse repeats.
s = regexprep(nameStr,'[^a-zA-Z0-9_-]','_');
s = regexprep(s,'_+','_');
end
