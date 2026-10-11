function [nu1,status,info] = skfRatedViscosity(B,dm,speed,method)
%SKFRATEDVISCOSITY Diagram 14: log diameter / log viscosity interpolation.
% Speed interpolation is linear between log10(n) and log10(nu1).
% Only visible parts of BOTH bracketing speed curves are used; no extrapolation.
arguments
    B (1,1) struct
    dm double
    speed (1,1) double
    method (1,1) string = "pchip"
end
nu1=nan(size(dm));status=strings(size(dm));
info=struct('speed_bracket',[NaN NaN],'speed_weight',NaN,'nu1_bracket',[], ...
    'diameter_overlap',[NaN NaN],'method',char(method));
if ~ismember(method,["pchip","vector","linear","makima"]),error('SKF:Method','Unknown model.');end
if ~isfinite(speed) || speed<B.speed_bounds(1) || speed>B.speed_bounds(2)
    status(:)=sprintf('Diagram 14 speed range: %g to %g rpm. No extrapolation.',B.speed_bounds);return
end
N=[B.curves.speed_rpm];exact=find(abs(N-speed)<1e-10,1);
if isempty(exact)
    i=find(N<speed,1,'last');j=i+1;w=log(speed/N(i))/log(N(j)/N(i));
else
    i=exact;j=exact;w=0;
end
low=max(B.curves(i).dm_bounds(1),B.curves(j).dm_bounds(1));
high=min(B.curves(i).dm_bounds(2),B.curves(j).dm_bounds(2));
info.speed_bracket=N([i j]);info.speed_weight=w;info.diameter_overlap=[low high];
valid=isfinite(dm) & dm>=low*(1-1e-12) & dm<=high*(1+1e-12);
status(~valid)=sprintf('Visible diameter overlap for %g/%g rpm: [%g, %g] mm. No extrapolation.',N(i),N(j),low,high);
if ~any(valid,'all'),return,end
q=min(max(dm(valid),low),high);
v1=oneCurve(B,B.curves(i),q,method);v2=oneCurve(B,B.curves(j),q,method);
nu1(valid)=10.^((1-w)*log10(v1)+w*log10(v2));
info.nu1_bracket=[v1(:) v2(:)];
if i==j,status(valid)="Rated viscosity on a printed Diagram 14 speed curve.";
else,status(valid)=sprintf('Diagram 14: interpolation between %g and %g rpm; log-speed weight = %.8g.',N(i),N(j),w);end
end

function v=oneCurve(B,C,dm,method)
if method~="vector"
    v=10.^interp1(log10(C.dm),log10(C.nu1),log10(dm),char(method),NaN);return
end
px=interp1(log10(B.x_values),B.x_pixel,log10(dm),'linear');
% Printed line endpoints can be within half a stroke width of the left border.
px=min(max(px,C.segments(1).points(1,1)),C.segments(end).points(end,1));
py=nan(size(px));
for s=1:numel(C.segments)
    seg=C.segments(s);p=seg.points;
    mask=px>=p(1,1)-1e-9 & px<=p(end,1)+1e-9;x=px(mask);
    if strcmp(seg.kind,'line')
        py(mask)=p(1,2)+(x-p(1,1))*(p(2,2)-p(1,2))/(p(2,1)-p(1,1));
    else
        lo=zeros(size(x));hi=ones(size(x));
        for it=1:54
            t=(lo+hi)/2;
            xx=(1-t).^3*p(1,1)+3*(1-t).^2.*t*p(2,1)+3*(1-t).*t.^2*p(3,1)+t.^3*p(4,1);
            hit=xx<x;lo(hit)=t(hit);hi(~hit)=t(~hit);
        end
        py(mask)=(1-t).^3*p(1,2)+3*(1-t).^2.*t*p(2,2)+3*(1-t).*t.^2*p(3,2)+t.^3*p(4,2);
    end
end
% The labelled 5 tick is above the frame's ~4 lower boundary.
% Its last grid interval defines the log scale down to the visible frame only.
v=10.^interp1(-B.y_pixel,log10(B.y_values),-py,'linear','extrap');
end
