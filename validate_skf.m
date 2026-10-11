function validate_skf
% Numerical and GUI regression checks against the source PDF vector paths.
folder=fileparts(mfilename('fullpath'));
D=jsondecode(fileread(fullfile(folder,'skf_data.json')));
methods=["linear","pchip","makima","spline"];
rows={};
for s=1:numel(D.sets)
    S=D.sets(s);
    if ~S.available
        [a,~]=skfEvaluate(S,1,.1);assert(isnan(a));continue
    end
    assert(numel(S.curves)==13);
    for j=1:13
        C=S.curves(j);
        assert(numel(C.q)==30 && all(diff(C.q)>0));
        sourceMonotone=all(diff(C.a)>=-1e-10);
        xx=logspace(log10(C.q(1)),log10(C.q(end)),5001);
        ref=skfEvaluate(S,C.kappa,xx,"vector");
        for m=methods
            lx=min(max(log10(xx),log10(C.q(1))),log10(C.q(end)));
            y=10.^interp1(log10(C.q),log10(C.a),lx,char(m));
            err=max(abs(y./ref-1))*100;
            monotone=all(diff(y)>=-1e-10);
            bounded=all(y>=min(C.a)-1e-10 & y<=max(C.a)+1e-8);
            rows(end+1,:)={S.diagram,S.design,C.kappa,char(m),err,monotone,bounded,sourceMonotone}; %#ok<AGROW>
            if m=="pchip"
                assert(err<.17 && (~sourceMonotone || monotone) && bounded);
                knot=skfEvaluate(S,C.kappa,C.q,"pchip");
                assert(max(abs(knot./C.a-1))<1e-10);
            end
        end
    end
    % No x/k extrapolation; cap at k=4 and aSKF=50, explicit status.
    assert(isnan(skfEvaluate(S,.099,.1)));
    assert(isnan(skfEvaluate(S,1,.0049)));
    assert(isnan(skfEvaluate(S,1,S.bounds(2)*1.01)));
    assert(abs(skfEvaluate(S,5,.1)-skfEvaluate(S,4,.1))<1e-12);
    [v,~]=skfEvaluate(S,.1,S.bounds(2));assert(abs(v-.1)<1e-12);
    low=S.curves(12);high=S.curves(13);
    if low.ceiling && high.ceiling
        qMixed=sqrt(low.q_end*high.q_end);
        assert(isnan(skfEvaluate(S,3.5,qMixed)));
        assert(skfEvaluate(S,3.5,S.bounds(2))==50);
        assert(skfEvaluate(S,4,S.bounds(2))==50);
    end
    T=S.table;if iscell(T),T=cellfun(@nullToNaN,T);end
    for j=1:13
        valid=isfinite(T(:,j+1));
        ref=skfEvaluate(S,S.curves(j).kappa,T(valid,1),"vector");
        assert(max(abs(ref./T(valid,j+1)-1))<1e-9);
    end
end
T=cell2table(rows,'VariableNames',{'Diagram','Design','Kappa','Method','MaxRelativeError_percent','Monotone','Bounded','SourceMonotone'});
writetable(T,fullfile(folder,'interpolation_validation.csv'));
for m=methods
    R=T(strcmp(T.Method,m),:);
    fprintf('%s: max error %.6f%%; non-monotone on monotone source %d; out of bounds %d\n',m,max(R.MaxRelativeError_percent),sum(~R.Monotone & R.SourceMonotone),sum(~R.Bounded));
end
validate_lubrication;
end
function x=nullToNaN(x)
if isempty(x),x=NaN;end
end
