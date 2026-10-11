function validate_lubrication
% MATLAB R2025b end-to-end regression checks for the lubrication upgrade.
folder=string(fileparts(mfilename('fullpath')));
D=jsondecode(fileread(fullfile(folder,'skf_data.json')));
B=jsondecode(fileread(fullfile(folder,'diagram14_data.json')));O=skfLoadOils(folder);
report=strings(0,1);
nu40=[32.6 47.9 68.2 99.7];nu100=[5.61 7.16 8.92 11.8];
for j=1:4
    C=O(j);assert(C.row_count==141);
    assert(max(abs(skfOilViscosity(C,C.T_C)./C.nu_mm2_s-1))<1e-12);
    assert(abs(skfOilViscosity(C,40)-nu40(j))<1e-9);
    assert(abs(skfOilViscosity(C,100)-nu100(j))<1e-9);
    xx=linspace(C.T_C(1),C.T_C(end),2001);v=skfOilViscosity(C,xx);
    assert(all(isfinite(v)) && all(v>0) && all(diff(v)<0));
    assert(isnan(skfOilViscosity(C,C.T_bounds(1)-.01)));
    assert(isnan(skfOilViscosity(C,C.T_bounds(2)+.01)));
    err=0;
    for k=2:140
        keep=true(141,1);keep(k)=false;
        pred=10^interp1(C.T_C(keep),log10(C.nu_mm2_s(keep)),C.T_C(k),'pchip');
        err=max(err,100*abs(pred/C.nu_mm2_s(k)-1));
    end
    report(end+1)=sprintf('VG%d: 141 rows; exact 40/100 C anchors; max interior leave-one-out error %.8g%%.',C.grade,err);
end
assert(numel(B.curves)==17);quality=[];
for j=1:17
    C=B.curves(j);assert(numel(C.dm)==30 && all(diff(C.dm)>0) && all(diff(C.nu1)<=1e-10));
    xx=logspace(log10(C.dm(1)),log10(C.dm(end)),5001);
    v=skfRatedViscosity(B,xx,C.speed_rpm,'pchip');ref=skfRatedViscosity(B,xx,C.speed_rpm,'vector');
    assert(all(isfinite(v)) && all(isfinite(ref)) && all(diff(v)<=1e-10));
    err=max(abs(v./ref-1))*100;assert(err<.025);
    assert(max(abs(skfRatedViscosity(B,C.dm,C.speed_rpm,'pchip')./C.nu1-1))<1e-10);
    quality(end+1,:)=[C.speed_rpm,numel(C.dm),err,C.dm_bounds(:)']; %#ok<AGROW>
end
for j=1:16
    a=B.curves(j);b=B.curves(j+1);
    dm=sqrt(max(a.dm_bounds(1),b.dm_bounds(1))*min(a.dm_bounds(2),b.dm_bounds(2)));
    n=sqrt(a.speed_rpm*b.speed_rpm);
    v=skfRatedViscosity(B,dm,n);ref=sqrt(skfRatedViscosity(B,dm,a.speed_rpm)*skfRatedViscosity(B,dm,b.speed_rpm));
    assert(isfinite(v) && abs(v/ref-1)<1e-12);
end
assert(isnan(skfRatedViscosity(B,100,1)));
assert(isnan(skfRatedViscosity(B,100,100001)));
assert(isnan(skfRatedViscosity(B,9.99,1000)));
assert(isnan(skfRatedViscosity(B,2000,5000)));
assert(isfinite(skfRatedViscosity(B,10,500)));
T=array2table(quality,'VariableNames',{'Speed_rpm','Samples','MaxRelativeError_percent','dm_min_mm','dm_max_mm'});
writetable(T,fullfile(folder,'diagram14_validation.csv'));
report(end+1)=sprintf('Diagram 14: 17 speeds, 510 samples; max PCHIP/vector error %.8g%%.',max(quality(:,3)));
I=struct('bearing',9,'design','Basic','speed',750,'oil_grade',46,'temperature',60, ...
    'D_mm',120,'d_mm',80,'eta_c',.5,'Pu',1,'P',5,'method','pchip');
R=skfCalculate(D,B,O,I);assert(isfinite(R.aSKF));
assert(R.dm==100 && R.q==.1 && abs(R.kappa-R.nu_oil/R.nu1)<1e-12);
assert(contains(join(R.log),'Pu = 1 kN; P = 5 kN'));
assert(contains(join(R.log),'FINAL aSKF'));
writeText(fullfile(folder,'example_calculation_log.txt'),R.log);
bad=I;bad.d_mm=bad.D_mm+1;assert(isnan(skfCalculate(D,B,O,bad).aSKF));
bad=I;bad.temperature=149;Rbad=skfCalculate(D,B,O,bad);assert(isnan(Rbad.aSKF)&&isnan(Rbad.nu_oil)&&isfinite(Rbad.nu1));
bad=I;bad.design='Explorer';bad.bearing=11;Rbad=skfCalculate(D,B,O,bad);assert(isnan(Rbad.aSKF)&&isfinite(Rbad.kappa));

f=SKF_Life_App('off');cleanup=onCleanup(@()close(f));h=f.UserData;
for d=9:12
    for design={'Basic','Explorer'}
        h.bearing.Value=d;h.design.Value=design{1};h.refresh();drawnow;
        assert(isfinite(h.get_result().nu1));
        if d==11 && strcmp(design{1},'Explorer')
            assert(contains(h.answer.Text,'unavailable'));
        else
            assert(isfinite(h.get_result().aSKF));
            assert(numel(findall(h.axes,'Type','line'))==27);
        end
    end
end
h.bearing.Value=9;h.design.Value='Basic';h.refresh();drawnow;
assert(strcmp(h.kappa.Editable,'off'));
assert(numel(findall(h.rated_axes,'Type','line'))==36);
assert(numel(findall(h.oil_axes,'Type','line'))==9);
for choice={'Selected life table','Selected life samples','Diagram 14 samples','Selected oil database'}
    h.data_choice.Value=choice{1};h.update_data();
    counts=[30 390 510 141];idx=find(strcmp(choice{1},{'Selected life table','Selected life samples','Diagram 14 samples','Selected oil database'}));
    assert(size(h.table.Data,1)==counts(idx));
end
before=h.get_result();h.temperature.Value=75.5;h.speed.Value=1250;h.calculate();after=h.get_result();
assert(before.kappa~=after.kappa && all(after.rated_info.speed_bracket==[1000 1500]));
assert(numel(findall(h.axes,'Type','line'))==27);
h.oil.Value=100;h.calculate();assert(h.get_result().inputs.oil_grade==100);
h.outer.Value=70;h.calculate();assert(contains(h.answer.Text,'unavailable'));
assert(~any(arrayfun(@(x)strcmp(x.Marker,'p'),findall(h.axes,'Type','line'))));
h.outer.Value=120;h.temperature.Value=60;h.speed.Value=750;h.oil.Value=46;h.calculate();
h.show.Value=false;h.refresh();assert(numel(findall(h.axes,'Type','line'))==14);
h.show.Value=true;h.refresh();
h.tabs.SelectedTab=h.selected_tab;drawnow;exportapp(f,fullfile(folder,'GUI_preview.png'));
h.tabs.SelectedTab=h.overview_tab;drawnow;exportapp(f,fullfile(folder,'GUI_diagrams9_12.png'));
h.tabs.SelectedTab=h.rated_tab;drawnow;exportapp(f,fullfile(folder,'GUI_diagram14.png'));
h.tabs.SelectedTab=h.oil_tab;drawnow;exportapp(f,fullfile(folder,'GUI_oils.png'));
h.tabs.SelectedTab=h.log_tab;drawnow;exportapp(f,fullfile(folder,'GUI_log.png'));
f.Position=[50 40 1100 820];h.tabs.SelectedTab=h.rated_tab;
% Hidden uifigures defer SizeChangedFcn; exercise the installed callback explicitly.
f.SizeChangedFcn(f,[]);drawnow;
leg=findall(f,'Type','legend');assert(any(strcmp({leg.Location},'northoutside')));
exportapp(f,fullfile(folder,'GUI_preview_compact.png'));
h.tabs.SelectedTab=h.data_tab;h.data_choice.Value='Diagram 14 samples';h.update_data();drawnow;
exportapp(f,fullfile(folder,'GUI_source_data.png'));
report(end+1)="PASS: calculation chain, all 8 life selections, all four oil files, speed interpolation, domain rejection, log and GUI updates.";
writeText(fullfile(folder,'lubrication_validation.txt'),report);disp(report);
end
function writeText(path,lines)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);clean=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',join(lines,newline));
end
