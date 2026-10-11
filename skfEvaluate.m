function [a, status, info] = skfEvaluate(S, kappa, q, method)
%SKFEVALUATE Interpolate the extracted chart, with explicit domain handling.
% All three variables q, kappa and aSKF are interpolated in log10 space.
% q is eta_c*Pu/P. Pu and P must have the same units.
% Unlabelled curves are assigned kappa=1.5 and 3 (an assumption).
% No toolbox is required. Vector mode evaluates the original PDF Bezier path.
arguments
    S (1,1) struct
    kappa (1,1) double
    q double
    method (1,1) string = "pchip"
end
a = nan(size(q)); status = strings(size(q));
info=struct('kappa_input',kappa,'kappa_used',min(kappa,4), ...
    'kappa_bracket',[],'kappa_weight',NaN,'a_bracket',[],'method',char(method));
if ~S.available
    status(:) = "Explorer data for Diagram 11 are absent from the source PDF.";
    return
end
if ~isfinite(kappa) || kappa < 0.1
    status(:) = "kappa must be at least 0.1; lower values are outside the life model.";
    return
end
if ~ismember(method,["pchip","linear","makima","vector"])
    error('SKF:Method','Unknown interpolation method.');
end
clamped = kappa > 4;
kappa = min(kappa,4);
K = [S.curves.kappa];
exact = find(abs(K-kappa)<1e-12,1);
if isempty(exact)
    i = find(K<kappa,1,'last'); j = i+1;
    w = log(kappa/K(i))/log(K(j)/K(i));
else
    i = exact; j = exact; w = 0;
end
info.kappa_bracket=K([i j]);info.kappa_weight=w;
valid=isfinite(q) & q>=S.bounds(1)*(1-1e-12) & q<=S.bounds(2)*(1+1e-12);
status(~valid)=sprintf('q must be within [%g, %g]. No extrapolation.',S.bounds);
if ~any(valid,'all'),return,end
z=min(max(q(valid),S.bounds(1)),S.bounds(2));
[v1,c1]=oneCurve(S,S.curves(i),z,method);
[v2,c2]=oneCurve(S,S.curves(j),z,method);
info.a_bracket=[v1(:) v2(:)];
v=10.^((1-w)*log10(v1)+w*log10(v2));
st=repmat("Interpolated chart estimate.",size(z));
both=c1 & c2; mixed=(c1~=c2) & i~=j;
v(both)=50;st(both)="Chart ceiling: aSKF >= 50; returned value is capped at 50.";
v(mixed)=NaN;st(mixed)="A bracketing curve exceeds 50; an intermediate value cannot be resolved from this chart.";
if clamped,st=st+" kappa > 4 uses kappa = 4 (source limit).";end
if i~=j,st=st+" Linear interpolation in log(kappa).";end
if any(ismember(K([i j]),[1.5 3]))
    st=st+" Uses an assumed label (kappa = 1.5 or 3).";
end
a(valid)=v;status(valid)=st;
end

function [v,capped] = oneCurve(S,C,q,method)
capped = q>C.q_end*(1+1e-12) & C.ceiling;
q=min(q,C.q_end);
if method=="vector" && ~isempty(C.bezier)
    pixel=interp1(log10(S.x_values),S.x_pixel,log10(q),'linear');
    p=C.bezier; lo=zeros(size(q)); hi=ones(size(q));
    for it=1:54
        t=(lo+hi)/2;
        x=(1-t).^3*p(1,1)+3*(1-t).^2.*t*p(2,1)+3*(1-t).*t.^2*p(3,1)+t.^3*p(4,1);
        hit=x<pixel;lo(hit)=t(hit);hi(~hit)=t(~hit);
    end
    y=(1-t).^3*p(1,2)+3*(1-t).^2.*t*p(2,2)+3*(1-t).*t.^2*p(3,2)+t.^3*p(4,2);
    v=10.^interp1(-S.y_pixel,log10(S.y_values),-y,'linear');
    if C.ceiling,v(abs(q-C.q_end)<C.q_end*1e-12)=50;end
elseif method=="vector"
    v=ones(size(q))*.1;
else
    v=10.^interp1(log10(C.q),log10(C.a),log10(q),char(method));
end
v(capped)=50;
end
