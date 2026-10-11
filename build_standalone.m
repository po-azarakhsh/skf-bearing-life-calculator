function results = build_standalone
% Run from this project folder in MATLAB R2025b with MATLAB Compiler.
if ~license('test','Compiler')
    error('SKF:CompilerRequired','MATLAB Compiler license is required.');
end
projectFolder = fileparts(mfilename('fullpath'));
originalFolder = pwd;
cleanup = onCleanup(@()cd(originalFolder));
% MATLAB search paths use semicolons as separators. Stage the build in a
% simple temporary path so projects in folders containing ';' also compile.
stageFolder = tempname;
mkdir(stageFolder);
copyfile(fullfile(projectFolder,'*.m'),stageFolder);
copyfile(fullfile(projectFolder,'skf_data.json'),stageFolder);
copyfile(fullfile(projectFolder,'diagram14_data.json'),stageFolder);
copyfile(fullfile(projectFolder,'Lubs'),fullfile(stageFolder,'Lubs'));
cd(stageFolder);
results = compiler.build.standaloneWindowsApplication('SKF_Life_Standalone.m', ...
    'ExecutableName','SKF_Bearing_Life', ...
    'OutputDir',fullfile(stageFolder,'compiled'), ...
    'AdditionalFiles',{'skf_data.json','diagram14_data.json','Lubs'}, ...
    'Verbose','on');
destination = fullfile(projectFolder,'dist','windows');
if ~isfolder(destination),mkdir(destination);end
copyfile(fullfile(stageFolder,'compiled','*'),destination);
fprintf('Standalone files copied to: %s\n',destination);
end
