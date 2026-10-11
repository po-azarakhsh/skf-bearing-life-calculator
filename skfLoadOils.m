function oils = skfLoadOils(folder)
%SKFLOADOILS Read the four supplied DyRoBeS TXT files without changing them.
% Column 4 is KINEMATIC viscosity (cSt = mm2/s); column 3 is not used.
% Fahrenheit is converted exactly, avoiding the rounded final Celsius column.
arguments
    folder (1,1) string = string(fileparts(mfilename('fullpath')))
end
grades=[32 46 68 100];
oils=struct('grade',{},'name',{},'source_file',{},'T_C',{},'nu_mm2_s',{}, ...
    'raw',{},'T_bounds',{},'row_count',{});
for grade=grades
    file=sprintf('VG%d.txt',grade);
    candidates=[fullfile(folder,'Lubs','Lubs',file),fullfile(folder,'Lubs',file),fullfile(folder,file)];
    found=find(isfile(candidates),1);
    if isempty(found),error('SKF:OilMissing','Missing oil database file: %s',file);end
    path=candidates(found);raw=fileread(path);lines=splitlines(string(raw));A=[];
    for i=1:numel(lines)
        if isempty(regexp(lines(i),'^\s*[+-]?\d+(\.\d+)?\s+[+-]?\d+(\.\d+)?[Ee][+-]?\d+','once')),continue,end
        v=sscanf(lines(i),'%f');
        if numel(v)~=8,error('SKF:OilRow','Malformed numeric row %d in %s.',i,file);end
        A(end+1,:)=v'; %#ok<AGROW>
    end
    T=(A(:,1)-32)*5/9;nu=A(:,4);
    if numel(T)<3 || any(diff(T)<=0) || any(~isfinite(A),'all') || any(nu<=0) || any(diff(nu)>=0)
        error('SKF:OilData','Oil table must contain increasing temperature and positive decreasing viscosity: %s',file);
    end
    oils(end+1)=struct('grade',grade,'name',sprintf('Amokon ISO VG %d',grade), ...
        'source_file',char(path),'T_C',T,'nu_mm2_s',nu,'raw',A, ...
        'T_bounds',[T(1) T(end)],'row_count',numel(T)); %#ok<AGROW>
end
end
