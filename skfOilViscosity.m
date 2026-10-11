function [nu,status,info] = skfOilViscosity(oil,T)
%SKFOILVISCOSITY PCHIP of log10(kinematic viscosity) versus Celsius temperature.
% Explicit NaN extrapolation prevents invented values outside the TXT database.
nu=nan(size(T));status=strings(size(T));
info=struct('source_file',oil.source_file,'grade',oil.grade, ...
    'method','PCHIP: T_C to log10(nu)','temperature_bounds',oil.T_bounds, ...
    'bracket_temperature_C',[NaN NaN],'bracket_viscosity',[NaN NaN]);
valid=isfinite(T) & T>=oil.T_bounds(1)-1e-10 & T<=oil.T_bounds(2)+1e-10;
nu(valid)=10.^interp1(oil.T_C,log10(oil.nu_mm2_s), ...
    min(max(T(valid),oil.T_bounds(1)),oil.T_bounds(2)),'pchip',NaN);
status(valid)="Kinematic oil viscosity from the supplied TXT database.";
status(~valid)=sprintf('Temperature must be in [%g, %g] C; no extrapolation.',oil.T_bounds);
if isscalar(T) && valid
    lo=find(oil.T_C<=T+1e-10,1,'last');hi=find(oil.T_C>=T-1e-10,1,'first');
    info.bracket_temperature_C=oil.T_C([lo hi])';
    info.bracket_viscosity=oil.nu_mm2_s([lo hi])';
end
end
