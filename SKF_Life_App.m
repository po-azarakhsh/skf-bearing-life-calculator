function fig = SKF_Life_App(visible)
%SKF_LIFE_APP MATLAB R2025b lubrication and aSKF calculator, light theme.
% Read VG32/46/68/100 TXT files; compute dm, nu1, nu, kappa, q, aSKF.
% All four life diagrams, Diagram 14, oil curves, source data and full log.
arguments
    visible (1,1) string = "on"
end
folder=string(fileparts(mfilename('fullpath')));
D=jsondecode(fileread(fullfile(folder,'skf_data.json')));
B=jsondecode(fileread(fullfile(folder,'diagram14_data.json')));
O=skfLoadOils(folder);
fig=uifigure('Name','SKF lubrication and bearing life','Theme','light','AutoResizeChildren','off', ...
    'Position',[30 20 1380 820],'Visible',visible,'Color',[.96 .97 .99]);
root=uigridlayout(fig,[1 2]);root.ColumnWidth={370,'1x'};
root.Padding=[14 14 14 14];root.ColumnSpacing=14;
left=uipanel(root,'Title','Inputs and calculated values','FontWeight','bold');
g=uigridlayout(left,[23 2]);g.ColumnWidth={155,'1x'};
g.RowHeight={26,28,28,28,28,28,28,28,28,28,28,28,24,32,22,26,26,26,26,26,40,64,16};
g.Padding=[12 8 12 8];g.RowSpacing=2;g.ColumnSpacing=8;g.Scrollable='on';
label('SKF lubrication calculator',1,[1 2],16,true);
label('Bearing type',2,1,12,false);
bearing=uidropdown(g,'Items',{'Radial ball (D9)','Radial roller (D10)','Thrust ball (D11)','Thrust roller (D12)'}, ...
    'ItemsData',9:12,'Value',9);place(bearing,2,2);
label('Bearing design',3,1,12,false);
design=uidropdown(g,'Items',{'Basic / SKF standard','SKF Explorer'}, ...
    'ItemsData',{'Basic','Explorer'},'Value','Basic');place(design,3,2);
speed=input('Speed n (rpm)',4,750,[2 100000]);
label('Oil',5,1,12,false);
oil=uidropdown(g,'Items',{O.name},'ItemsData',[O.grade],'Value',46);place(oil,5,2);
temperature=input('Oil temperature (C)',6,60,[-273.14 Inf]);
outer=input('Outer diameter D (mm)',7,120,[eps Inf]);
inner=input('Inner diameter d (mm)',8,80,[eps Inf]);
eta=input('Cleanliness eta_c',9,.5,[eps 1]);
Pu=input('Fatigue limit Pu (kN)',10,1,[eps Inf]);
P=input('Equivalent load P (kN)',11,5,[eps Inf]);
label('Chart model',12,1,12,false);
model=uidropdown(g,'Items',{'PCHIP in log space','Original PDF vector','Linear in log space','MAKIMA in log space'}, ...
    'ItemsData',{'pchip','vector','linear','makima'},'Value','pchip');place(model,12,2);
show=uicheckbox(g,'Text','Show original data points','Value',true);place(show,13,[1 2]);
bg=uigridlayout(g,[1 2]);place(bg,14,[1 2]);bg.Padding=[0 0 0 0];bg.ColumnWidth={'1x','1x'};
calc=uibutton(bg,'Text','Calculate','BackgroundColor',[.1 .36 .64],'FontColor','white');
saveLog=uibutton(bg,'Text','Save log');
label('Calculated automatically',15,[1 2],12,true);
dmField=output('Mean diameter dm (mm)',16);
nu1Field=output('Rated nu_1 (mm^2/s)',17);
nuField=output('Oil nu (mm^2/s)',18);
kField=output('Kappa = nu / nu_1',19);
qField=output('q = eta_c Pu / P',20);
answer=uilabel(g,'Text','aSKF = --','FontSize',27,'FontWeight','bold','FontColor',[.08 .28 .5]);place(answer,21,[1 2]);
notes=uitextarea(g,'Editable','off','FontSize',11,'Value',{'Loading...'});place(notes,22,[1 2]);
label('SKF charts and supplied Amokon oil data',23,[1 2],10,false);
speed.Tooltip='Diagram 14: rpm. Intermediate speeds are interpolated in log space.';
temperature.Tooltip='Actual operating oil temperature, Celsius. Database range is checked at calculation.';
eta.Tooltip='Required for q = eta_c Pu/P. 1 = perfectly clean conditions.';
kField.Tooltip='Actual viscosity ratio. The life model caps ratios above 4 internally.';

right=uigridlayout(root,[3 1]);right.RowHeight={34,'1x',24};right.Padding=[0 0 0 0];
heading=uilabel(right,'Text','SKF bearing life','FontSize',19,'FontWeight','bold');
tabs=uitabgroup(right);
selectedTab=uitab(tabs,'Title','Selected aSKF');ax=oneAxes(selectedTab);
overviewTab=uitab(tabs,'Title','Diagrams 9-12');ovg=uigridlayout(overviewTab,[2 2]);ovg.Padding=[8 8 8 8];
overview=gobjects(4,1);for j=1:4,overview(j)=uiaxes(ovg);end
ratedTab=uitab(tabs,'Title','Diagram 14');ratedAx=oneAxes(ratedTab);
oilTab=uitab(tabs,'Title','Oil viscosity');oilAx=oneAxes(oilTab);
logTab=uitab(tabs,'Title','Calculation log');lg=uigridlayout(logTab,[2 1]);lg.RowHeight={24,'1x'};
uilabel(lg,'Text','Current calculation. Save log exports the session history.','FontSize',12);
logArea=uitextarea(lg,'Editable','off','FontName','Consolas','FontSize',12);
dataTab=uitab(tabs,'Title','Source data');dg=uigridlayout(dataTab,[2 1]);dg.RowHeight={34,'1x'};
dataChoice=uidropdown(dg,'Items',{'Selected life table','Selected life samples','Diagram 14 samples','Selected oil database'});
dataTable=uitable(dg,'RowName',{},'ColumnEditable',false,'FontSize',11);
foot=uilabel(right,'Text','Markers: original data. Gold star: your inputs. k=1.5 and 3 have assumed labels.','FontSize',11);
S=[];R=[];history=strings(0,1);runCount=0;markers=gobjects(0);speedLine=gobjects(0);
lifeLegend=gobjects(0);ratedLegend=gobjects(0);
for c={bearing,design,model,show},c{1}.ValueChangedFcn=@(~,~)refresh();end
for c={speed,oil,temperature,outer,inner,eta,Pu,P},c{1}.ValueChangedFcn=@(~,~)calculate();end
calc.ButtonPushedFcn=@(~,~)calculate();saveLog.ButtonPushedFcn=@(~,~)exportLog();
dataChoice.ValueChangedFcn=@(~,~)updateData();
fig.UserData=struct('bearing',bearing,'design',design,'speed',speed,'oil',oil, ...
    'temperature',temperature,'outer',outer,'inner',inner,'eta',eta,'Pu',Pu,'P',P, ...
    'kappa',kField,'dm',dmField,'nu1',nu1Field,'nu_oil',nuField,'q',qField, ...
    'model',model,'show',show,'axes',ax,'overview',overview,'rated_axes',ratedAx, ...
    'oil_axes',oilAx,'table',dataTable,'data_choice',dataChoice,'answer',answer, ...
    'notes',notes,'log',logArea,'root',root,'tabs',tabs,'selected_tab',selectedTab, ...
    'overview_tab',overviewTab,'rated_tab',ratedTab,'oil_tab',oilTab,'log_tab',logTab, ...
    'data_tab',dataTab,'refresh',@refresh,'calculate',@calculate,'update_data',@updateData, ...
    'get_result',@getResult,'get_history',@getHistory);
refresh();
fig.SizeChangedFcn=@(~,~)layoutLegends();

    function result=getResult(),result=R;end
    function lines=getHistory(),lines=history;end
    function h=label(text,row,col,size,bold)
        h=uilabel(g,'Text',text,'FontSize',size);if bold,h.FontWeight='bold';end
        place(h,row,col);
    end
    function place(h,row,col),h.Layout.Row=row;h.Layout.Column=col;end
    function h=input(text,row,value,limits)
        label(text,row,1,12,false);h=uieditfield(g,'numeric','Value',value,'Limits',limits);place(h,row,2);
    end
    function h=output(text,row)
        label(text,row,1,12,false);h=uieditfield(g,'text','Editable','off','Value','--');place(h,row,2);
    end
    function h=oneAxes(parent)
        grid=uigridlayout(parent,[1 1]);grid.Padding=[10 10 10 10];h=uiaxes(grid);
    end
    function style(h,logx)
        legend(h,'off');cla(h,'reset');hold(h,'on');h.Color='white';
        if logx,h.XScale='log';else,h.XScale='linear';end
        h.YScale='log';h.XGrid='on';h.YGrid='on';h.XMinorGrid='on';h.YMinorGrid='on';
        h.GridAlpha=.18;h.MinorGridAlpha=.05;h.Box='on';h.FontSize=11;
    end
    function drawLife(h,set,large)
        style(h,true);h.XLim=set.bounds;h.YLim=[.05 50];
        h.XTick=[.005 .01 .02 .05 .1 .2 .5 1 2 5];h.YTick=[.05 .1 .2 .5 1 2 5 10 20 50];
        xlabel(h,'\eta_c P_u / P');ylabel(h,'a_{SKF}');
        names={'Radial ball','Radial roller','Thrust ball','Thrust roller'};
        title(h,sprintf('D%d %s - %s',set.diagram,names{set.diagram-8},set.design),'FontSize',12);
        if ~set.available
            text(h,.012,1,{'Explorer source data','are absent from Diagram 11.'},'FontSize',11);return
        end
        colors=.78*turbo(13);lines=gobjects(13,1);
        for j=1:13
            C=set.curves(j);xx=logspace(log10(C.q(1)),log10(C.q(end)),300);
            yy=skfEvaluate(set,C.kappa,xx,string(model.Value));
            lines(j)=plot(h,xx,yy,'LineWidth',1.3,'Color',colors(j,:));
            if show.Value
                plot(h,C.q,C.a,'o','MarkerSize',3,'MarkerFaceColor','white', ...
                    'MarkerEdgeColor',colors(j,:),'LineStyle','none','HandleVisibility','off');
            end
        end
        if large
            names=arrayfun(@(v)sprintf('k=%g',v),D.kappa,'UniformOutput',false);names{10}='k=1.5 *';names{12}='k=3 *';
            lifeLegend=legend(h,lines,names,'Location','eastoutside','FontSize',10);
        else,h.FontSize=9;end
    end
    function drawRated()
        style(ratedAx,true);ratedAx.XLim=[10 2000];ratedAx.YLim=[3.98 1000];
        ratedAx.XTick=[10 20 50 100 200 500 1000 2000];ratedAx.YTick=[4 5 10 20 50 100 200 500 1000];
        xlabel(ratedAx,'Mean bearing diameter d_m [mm]');ylabel(ratedAx,'Rated viscosity \nu_1 [mm^2/s]');
        title(ratedAx,'Diagram 14 - speed curves n [rpm]');
        colors=.8*turbo(17);lines=gobjects(17,1);
        for j=1:17
            C=B.curves(j);xx=logspace(log10(C.dm(1)),log10(C.dm(end)),300);
            yy=skfRatedViscosity(B,xx,C.speed_rpm,string(model.Value));
            lines(j)=plot(ratedAx,xx,yy,'Color',colors(j,:),'LineWidth',1.2);
            if show.Value
                plot(ratedAx,C.dm,C.nu1,'o','MarkerSize',3,'MarkerFaceColor','white', ...
                    'MarkerEdgeColor',colors(j,:),'LineStyle','none','HandleVisibility','off');
            end
        end
        ratedLegend=legend(ratedAx,lines,arrayfun(@(v)sprintf('n=%g',v),[B.curves.speed_rpm], ...
            'UniformOutput',false),'Location','eastoutside','FontSize',9);
    end
    function drawOil()
        style(oilAx,false);oilAx.XLim=O(1).T_bounds;oilAx.YLim=[1 4000];
        xlabel(oilAx,'Operating oil temperature [C]');ylabel(oilAx,'Kinematic oil viscosity \nu [mm^2/s]');
        title(oilAx,'Supplied Amokon oil database - kinematic viscosity');colors=lines(4);hs=gobjects(4,1);
        for j=1:4
            xx=linspace(O(j).T_bounds(1),O(j).T_bounds(2),500);yy=skfOilViscosity(O(j),xx);
            hs(j)=plot(oilAx,xx,yy,'Color',colors(j,:),'LineWidth',1.8);
            if show.Value
                plot(oilAx,O(j).T_C,O(j).nu_mm2_s,'o','MarkerSize',2.5, ...
                    'Color',colors(j,:),'HandleVisibility','off','LineStyle','none');
            end
        end
        legend(oilAx,hs,{O.name},'Location','northeast','FontSize',10);
    end
    function refresh()
        markers=gobjects(0);speedLine=gobjects(0);
        idx=find([D.sets.diagram]==bearing.Value & strcmp({D.sets.design},design.Value),1);S=D.sets(idx);
        drawLife(ax,S,true);
        for d=9:12
            si=find([D.sets.diagram]==d & strcmp({D.sets.design},design.Value),1);
            drawLife(overview(d-8),D.sets(si),false);
        end
        drawRated();drawOil();layoutLegends();calculate();
    end
    function layoutLegends()
        % Reflow labels on resize instead of shrinking their boxes horizontally.
        small=fig.Position(3)<1220;
        for h={lifeLegend,ratedLegend}
            if isempty(h{1}) || ~isgraphics(h{1}),continue,end
            if small
                h{1}.Location='northoutside';h{1}.NumColumns=4;h{1}.FontSize=9;
            else
                h{1}.Location='eastoutside';h{1}.NumColumns=1;h{1}.FontSize=10;
            end
        end
    end
    function calculate()
        I=struct('bearing',bearing.Value,'design',design.Value,'speed',speed.Value, ...
            'oil_grade',oil.Value,'temperature',temperature.Value,'D_mm',outer.Value,'d_mm',inner.Value, ...
            'eta_c',eta.Value,'Pu',Pu.Value,'P',P.Value,'method',model.Value);
        R=skfCalculate(D,B,O,I);runCount=runCount+1;
        history=[history;"";sprintf('================ RUN %d ================',runCount);R.log];
        logArea.Value=cellstr(R.log);
        dmField.Value=number(R.dm);nu1Field.Value=number(R.nu1);nuField.Value=number(R.nu_oil);
        kField.Value=number(R.kappa);qField.Value=number(R.q);
        if isfinite(R.aSKF),answer.Text=sprintf('aSKF = %.6g',R.aSKF);else,answer.Text='aSKF = unavailable';end
        names={'Radial ball','Radial roller','Thrust ball','Thrust roller'};
        heading.Text=sprintf('%s - %s - VG %d',names{bearing.Value-8},design.Value,oil.Value);
        notes.Value=cellstr([R.status;"Open Calculation log for all intermediate values."]);
        if ~isempty(markers),delete(markers(isgraphics(markers)));end
        if ~isempty(speedLine),delete(speedLine(isgraphics(speedLine)));end
        markers=gobjects(0);speedLine=gobjects(0);
        if isfinite(R.aSKF)
            markers(end+1)=star(ax,R.q,R.aSKF);markers(end+1)=star(overview(bearing.Value-8),R.q,R.aSKF);
        end
        if isfinite(R.nu1)
            markers(end+1)=star(ratedAx,R.dm,R.nu1);
            range=R.rated_info.diameter_overlap;xx=logspace(log10(range(1)),log10(range(2)),250);
            yy=skfRatedViscosity(B,xx,speed.Value,string(model.Value));
            speedLine=plot(ratedAx,xx,yy,'k--','LineWidth',2,'HandleVisibility','off');
            title(ratedAx,sprintf('Diagram 14 - selected n = %.7g rpm',speed.Value));
        else,title(ratedAx,'Diagram 14 - requested point outside available curves');end
        if isfinite(R.nu_oil),markers(end+1)=star(oilAx,temperature.Value,R.nu_oil);end
        updateData();
    end
    function h=star(axis,x,y)
        h=plot(axis,x,y,'p','MarkerSize',14,'MarkerFaceColor',[1 .72 .18], ...
            'MarkerEdgeColor',[.15 .15 .15],'LineWidth',1.3,'HandleVisibility','off');
    end
    function t=number(v)
        if isfinite(v),t=sprintf('%.8g',v);else,t='unavailable';end
    end
    function updateData()
        switch dataChoice.Value
            case 'Selected life table'
                dataTable.Data=S.table;dataTable.ColumnName=[{'q'},arrayfun(@(v)sprintf('k=%g',v),D.kappa','UniformOutput',false)];
                dataTable.ColumnWidth=[{110},repmat({85},1,13)];
            case 'Selected life samples'
                M=[];for j=1:numel(S.curves),C=S.curves(j);M=[M;[repmat(C.kappa,30,1),(1:30)',C.q(:),C.a(:)]];end %#ok<AGROW>
                dataTable.Data=M;dataTable.ColumnName={'kappa','Point','q','aSKF'};dataTable.ColumnWidth={80 70 130 130};
            case 'Diagram 14 samples'
                M=[];for j=1:17,C=B.curves(j);M=[M;[repmat(C.speed_rpm,30,1),(1:30)',C.dm(:),C.nu1(:)]];end %#ok<AGROW>
                dataTable.Data=M;dataTable.ColumnName={'n [rpm]','Point','dm [mm]','nu1 [cSt]'};dataTable.ColumnWidth={100 70 140 150};
            case 'Selected oil database'
                C=O([O.grade]==oil.Value);dataTable.Data=[C.T_C C.nu_mm2_s C.raw(:,1) C.raw(:,8)];
                dataTable.ColumnName={'Exact T [C]','nu [cSt]','T [F]','Rounded C'};
                dataTable.ColumnWidth={180 130 120 180};
        end
    end
    function exportLog()
        [name,path]=uiputfile('*.txt','Save calculation history','SKF_calculation_log.txt');
        if isequal(name,0),return,end
        fid=fopen(fullfile(path,name),'w','n','UTF-8');
        if fid<0,uialert(fig,'The chosen file could not be opened for writing.','Save log');return,end
        clean=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',join(history,newline)); %#ok<NASGU>
    end
end
